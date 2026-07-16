import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:letso/api.dart';
import 'package:letso/data.dart';
import 'package:letso/sync_status.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as pp;

import 'package:letso/logger_manager.dart';

class UploadResults {
  int successCount = 0;
  int failureCount = 0;
  List<String> errors = [];

  UploadResults();

  void addAll(UploadResults other) {
    successCount += other.successCount;
    failureCount += other.failureCount;
    errors.addAll(other.errors);
  }

  void logAll() {
    for (var e in errors) {
      logger.e(e);
    }
  }
}

class UploadManager {
  final Api api;

  final SyncStatus _syncStatus = SyncStatus();

  UploadManager({required this.api});

  /// Default number of uploads allowed to run concurrently. Chosen to give
  /// a meaningful speedup for directories with many small files without
  /// opening an unbounded number of connections/file handles at once.
  static const int defaultUploadConcurrency = 4;

  bool get isUploading => _syncStatus.isUploading();
  int? get remainingFiles => _syncStatus.remainingFiles;
  int? get totalFiles => _syncStatus.totalFiles;
  int? get remainingBytes => _syncStatus.remainingBytes;
  int? get totalBytes => _syncStatus.totalBytes;
  void registerListener(Function listener) =>
      _syncStatus.registerListener(listener);
  void unregisterListener(Function listener) =>
      _syncStatus.unregisterListener(listener);

  /// Runs [task] over [items], allowing up to [concurrency] tasks to be in
  /// flight at once instead of awaiting them one at a time. Workers pull
  /// from a shared index so a slow item never stalls the others' progress
  /// the way fixed-size batching would.
  Future<void> _runConcurrently<T>(
    List<T> items,
    int concurrency,
    Future<void> Function(T item) task,
  ) async {
    if (items.isEmpty) return;
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < items.length) {
        final item = items[nextIndex++];
        await task(item);
      }
    }

    final workerCount = concurrency < items.length
        ? concurrency
        : items.length;
    await Future.wait(List.generate(workerCount, (_) => worker()));
  }

  Future<void> _uploadPlatformFiles(
    final FilePickerResult? result,
    final PortablePath dest, {
    int concurrency = defaultUploadConcurrency,
  }) async {
    if (result == null || result.files.isEmpty) {
      logger.d('No files selected for upload');
      return;
    }

    final List<PlatformFile> files = result.files;
    for (var file in files) {
      _syncStatus.addFile(file.size);
    }

    await _runConcurrently(files, concurrency, (file) async {
      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        logger.w('File ${file.name} has no data, skipping upload: $e');
        _syncStatus.removeFile(file.size);
        return;
      }
      logger.d('Uploading file: ${file.name} to $dest');
      await api.uploadFile(
        file,
        dest,
        bytes,
        await FileStat.fromPickerFile(file),
      );
      _syncStatus.removeFile(file.size);
    });
  }

  Future<void> uploadFile(
    final PortablePath dest, {
    int concurrency = defaultUploadConcurrency,
  }) async {
    await _uploadPlatformFiles(
      await FilePicker.pickFiles(),
      dest,
      concurrency: concurrency,
    );
  }

  Future<void> pickAndUploadFiles(
    final PortablePath dest, {
    int concurrency = defaultUploadConcurrency,
  }) async {
    await _uploadPlatformFiles(
      await FilePicker.pickFiles(),
      dest,
      concurrency: concurrency,
    );
  }

  Future<(List<SyncItem>, List<String>)> getFilesInDirectoryRecursively(
    String directoryPath,
  ) async {
    final directory = io.Directory(directoryPath);
    List<SyncItem> items = [];
    List<String> errors = [];

    await for (var event
        in directory.list(recursive: true).where((f) => f is io.File)) {
      var item = await SyncItem.fromFileSystemEntity(event);
      if (item == null) {
        errors.add("failed to get SyncItem for ${event.path}");
      } else {
        items.add(item);
      }
    }
    return (items, errors);
  }

  Future<UploadResults> _lookupAndUpload(
    final PortablePath dest,
    PortablePath src,
  ) async {
    UploadResults results = UploadResults();
    String srcPath = src.toString();
    logger.d('Selected directory: $srcPath');
    final (syncItems, errors) = await getFilesInDirectoryRecursively(srcPath);
    logger.d('Found ${syncItems.length} files in directory $srcPath');

    logger.d('Uploading directory: $src to $dest');
    results.addAll(await uploadFiles(syncItems, dest, src));
    return results;
  }

  Future<UploadResults> uploadFiles(
    List<SyncItem> files,
    PortablePath dest,
    PortablePath src, {
    int concurrency = defaultUploadConcurrency,
  }) async {
    for (var file in files) {
      _syncStatus.addFile(file.stats!.size);
    }

    UploadResults results = UploadResults();
    await _runConcurrently(files, concurrency, (file) async {
      if (!await io.FileSystemEntity.isFile(file.path.toString())) {
        _syncStatus.removeFile(file.stats!.size); // Not a file, undo addFile above
        return;
      }
      PortablePath destDir = buildDestDir(dest, src, file.path);

      logger.d('Found file: ${file.path} to upload to $destDir');
      final bytes = await io.File(file.path.toString()).readAsBytes();
      PlatformFile platformFile = PlatformFile(
        name: file.path.getAncestor(file.path.length - 1)!,
        size: bytes.length,
        bytes: bytes,
      );
      var res = await api.uploadFile(platformFile, destDir, bytes, file.stats!);
      res.fold(
        ifLeft: (e) {
          logger.e(e);
          results.failureCount += 1;
          results.errors.add(e);
        },
        ifRight: (s) {
          results.successCount += 1;
        },
      );

      _syncStatus.removeFile(bytes.length);
    });
    return results;
  }

  PortablePath buildDestDir(
    PortablePath dest,
    PortablePath baseSrc,
    PortablePath file,
  ) {
    String baseDir = baseSrc.toString();
    PortablePath destDir = PortablePath.clone(dest);
    destDir = destDir.add(pp.basename(baseDir));
    for (var c in pp.split(
      pp.dirname(pp.relative(file.toString(), from: baseDir)),
    )) {
      assert(c != "..", "relative path returned for $file");
      if (c.isNotEmpty && c != ".") {
        destDir = destDir.add(c);
      }
    }
    return destDir;
  }

  Future<(String?, Future<UploadResults>)> _uploadDirectory(
    final PortablePath dest,
  ) async {
    if (kIsWeb) {
      logger.d('Directory upload is not supported on web');
      return Future.value((null, Future.value(UploadResults())));
    }
    String? selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory == null) {
      logger.d('No directory selected for upload');
      return Future.value((null, Future.value(UploadResults())));
    }
    PortablePath path = PortablePath.fromString(selectedDirectory);
    return Future.value((selectedDirectory, _lookupAndUpload(dest, path)));
  }

  Future<UploadResults> uploadDirectory(final PortablePath dest) async {
    final (selectedDirectory, resultsFuture) = await _uploadDirectory(dest);
    return resultsFuture;
  }

  Future<(SyncPath?, Future<UploadResults>)> selectAndSyncDirectory(
    final PortablePath dest,
  ) async {
    final (selectedDirectory, resultsFuture) = await _uploadDirectory(dest);
    if (selectedDirectory == null) {
      return Future.value((null, Future.value(UploadResults())));
    }
    final src = PortablePath.fromString(selectedDirectory);
    final syncPath = SyncPath(src: src, dest: dest);
    return Future.value((syncPath, resultsFuture));
  }
}
