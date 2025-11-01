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

  Future<void> processDirectory(io.Directory dir) async {
    await for (final entity in dir.list(recursive: true)) {
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

        // Recursively process subdirectory
        await processDirectory(entity);
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
  }

  await processDirectory(directory);
  return stats;
}

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
      logger.d('Received SyncItem: $item');
    }
    final files = toSync.values.toList();
    if (files.isEmpty) {
      logger.d('No files to sync for path: ${path.src}');
      return UploadResults();
    }
    return await uploadManager.uploadFiles(files, path.dest, path.src);
  }

  Future<Map<String, SyncItem>> _startStreaming(SyncPath syncPath) async {
    PortablePath dest = PortablePath.clone(syncPath.dest);
    dest.add(syncPath.src.getBasename()!);
    DeltaRequest deltas = DeltaRequest(dest: dest, deltas: []);
    Map<String, SyncItem> result = {};
    try {
      final response = await api.exhcnageDeltas(deltas);

      if (response.statusCode == 200) {
        List<int> bytes = [];
        // Listen to the stream and process chunks as they arrive
        await for (var s in response.stream) {
          bytes.addAll(s);
        }
        var chunk = utf8.decode(bytes);
        // SSE format: "data: {json}\n\n"
        // Split by double newline to get individual events
        final events = chunk.split('\n\n');

        for (var event in events) {
          if (event.trim().isEmpty) continue;

          // Extract JSON from "data: {json}" format
          final lines = event.split('\n');
          var (items, errors) = addLines(lines);
          if (errors.isNotEmpty) {
            logger.d(
              "chunk size: ${chunk.length} events size ${events.length} event size: ${event.length} bytes: ${bytes.length}",
            );
            logger.d(chunk);
            logger.d('Error parsing JSON: ${errors.toString()}');
          }
          result.addAll(items);
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
