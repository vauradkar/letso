import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:letso/api.dart';
import 'package:letso/data.dart';
import 'dart:io' as io;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/platform/platform_abstracts.dart';
import 'package:letso/upload_manager.dart';
import 'package:path/path.dart' as p;

/// Computes SHA-256 hash of a large file efficiently (stream-based)
Future<String> computeSha256OfFile(String filePath) async {
  final file = io.File(filePath);
  if (!await file.exists()) {
    throw Exception('File not found: $filePath');
  }

  // Create a chunked converter
  final digestSink = AccumulatorSink<Digest>();
  final byteSink = sha256.startChunkedConversion(digestSink);

  // Stream the file contents in chunks
  await file.openRead().forEach(byteSink.add);

  // Close and get digest
  byteSink.close();
  final digest = digestSink.events.single;

  // Return hex string
  return digest.toString();
}

Future<Map<String, SyncItem>> _getFileStats(String directoryPath) async {
  final stats = <String, SyncItem>{};
  final parent = p.dirname(directoryPath);

  final directory = io.Directory(directoryPath);

  if (!directory.existsSync()) {
    throw io.FileSystemException("Directory does not exist", directoryPath);
  }

  // dir.list(recursive: true) already walks the full subtree, so entities
  // must not be re-listed manually or every subdirectory gets processed once
  // per ancestor that also lists it (duplicate work, exponential in depth).
  await for (final entity in directory.list(recursive: true)) {
    final stat = await entity.stat();
    final path = entity.path;
    FileStat? fileStat;

    if (entity is io.Directory) {
      fileStat = FileStat(
        size: stat.size,
        mtime: stat.modified.toUtc().toIso8601String(),
        isDirectory: true,
        sha256: null,
      );
    } else if (entity is io.File) {
      // Calculate sha256 for files
      final bytes = await entity.readAsBytes();
      final hash = sha256.convert(bytes);
      fileStat = FileStat(
        size: stat.size,
        mtime: stat.modified.toUtc().toIso8601String(),
        isDirectory: false,
        sha256: hash.toString(),
      );
    }

    stats[p.relative(path, from: parent)] = SyncItem(
      path: PortablePath.fromString(path),
      stats: fileStat,
    );
  }

  return stats;
}

/// Exposed for testing only. [_getFileStats] is otherwise only reachable via
/// [compute], which requires a top-level function.
@visibleForTesting
Future<Map<String, SyncItem>> getFileStatsForTesting(String directoryPath) =>
    _getFileStats(directoryPath);

class SyncManager implements AbstractSyncManager {
  final Api api;
  final UploadManager uploadManager;

  SyncManager({required this.api, required this.uploadManager});

  @override
  Future<UploadResults> sync(SyncPath path) async {
    logger.d('Syncing path: ${path.src} to ${path.dest}');
    final statsFuture = compute(_getFileStats, path.src.toString());
    final exchangeFurture = _startStreaming(path);
    final results = await Future.wait([statsFuture, exchangeFurture]);
    final localStats = results[0];
    final recvd = results[1];

    Map<String, SyncItem> toSync = {};
    for (var item in localStats.entries) {
      var val = recvd[item.key];
      if (val == null || item.value.stats != val.stats) {
        final reason = val == null
            ? "not present"
            : "stats differ src${item.value.stats?.toJson()} dst${val.stats?.toJson()}";
        toSync[item.key] = item.value;
        logger.d('to sync SyncItem: ${item.key} reason: $reason');
      }
    }

    for (var entry in localStats.entries) {
      final stat = entry.value.stats!;
      logger.d(
        'File: ${entry.key} Size: ${stat.size} MTime: ${stat.mtime} IsDir: ${stat.isDirectory} SHA256: ${stat.sha256}',
      );
    }

    for (var item in recvd.keys) {
      logger.d('Received SyncItem: $item ${recvd[item]?.stats?.toJson()}');
    }
    final files = toSync.values.toList();
    logger.d(
      '${files.isEmpty ? 'No' : files.length} files to sync for path: ${path.src}',
    );
    if (files.isEmpty) {
      return UploadResults();
    }
    return await uploadManager.uploadFiles(files, path.dest, path.src);
  }

  /// Exposed for testing only. Lets a test observe events as they're
  /// parsed (via [onEvent]) rather than only once the whole map is
  /// returned, to verify events are processed as their chunk arrives
  /// rather than only after the full stream completes.
  @visibleForTesting
  Future<Map<String, SyncItem>> startStreamingForTesting(
    SyncPath syncPath, {
    void Function(Map<String, SyncItem> items)? onEvent,
  }) => _startStreaming(syncPath, onEvent: onEvent);

  Future<Map<String, SyncItem>> _startStreaming(
    SyncPath syncPath, {
    void Function(Map<String, SyncItem> items)? onEvent,
  }) async {
    PortablePath dest = PortablePath.clone(syncPath.dest);
    dest = dest.add(syncPath.src.getBasename()!);
    DeltaRequest deltas = DeltaRequest(dest: dest, deltas: []);
    Map<String, SyncItem> result = {};
    try {
      final response = await api.exchangeDeltas(deltas);

      if (response.statusCode == 200) {
        // SSE format: "data: {json}\n\n". Decode incrementally (utf8.decoder
        // correctly handles multi-byte characters split across chunks) and
        // only buffer up to the next event boundary, rather than
        // accumulating the entire response before parsing anything.
        var buffer = '';
        void processCompleteEvents() {
          int boundary;
          while ((boundary = buffer.indexOf('\n\n')) != -1) {
            final event = buffer.substring(0, boundary);
            buffer = buffer.substring(boundary + 2);
            if (event.trim().isEmpty) continue;

            final lines = event.split('\n');
            var (items, errors) = addLines(lines);
            if (errors.isNotEmpty) {
              logger.d('event: $event');
              logger.d('Error parsing JSON: ${errors.toString()}');
            }
            result.addAll(items);
            if (items.isNotEmpty) {
              onEvent?.call(items);
            }
          }
        }

        await for (var s in response.stream.transform(utf8.decoder)) {
          buffer += s;
          processCompleteEvents();
        }
        // The stream may end without a trailing "\n\n" after the final event.
        if (buffer.trim().isNotEmpty) {
          buffer += '\n\n';
          processCompleteEvents();
        }
      } else {
        logger.e(
          "exchangeDeltas request errored. code: ${response.statusCode}",
        );
      }
    } catch (e) {
      logger.e('Error: $e');
    }
    return result;
  }

  (Map<String, SyncItem>, List<String>) addLines(List<String> lines) {
    Map<String, SyncItem> result = {};
    List<String> errors = [];
    for (var line in lines) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6); // Remove "data: " prefix
        try {
          final json = jsonDecode(jsonStr);
          final List<SyncItem> items = json is List
              ? json.map((item) => SyncItem.fromJson(item)).toList()
              : [SyncItem.fromJson(json)];
          for (var item in items) {
            result[item.path.toString()] = item;
          }
        } catch (e) {
          errors.add('Error parsing JSON: $e');
        }
      } else {
        errors.add("ill formed event $line");
      }
    }
    return (result, errors);
  }
}
