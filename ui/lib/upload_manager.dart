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
}

class UploadManager {
  final Api api;

  final SyncStatus _syncStatus = SyncStatus();

  UploadManager({required this.api});

  bool get isUploading => _syncStatus.isUploading();
  int? get remainingFiles => _syncStatus.remainingFiles;
  int? get totalFiles => _syncStatus.totalFiles;
  int? get remainingBytes => _syncStatus.remainingBytes;
  int? get totalBytes => _syncStatus.totalBytes;
  void registerListener(Function listener) =>
      _syncStatus.registerListener(listener);
  void unregisterListener(Function listener) =>
      _syncStatus.unregisterListener(listener);

  Future<void> _uploadPlatformFiles(
    final FilePickerResult? result,
    final PortablePath dest,
  ) async {
    if (result == null || result.files.isEmpty) {
      logger.d('No files selected for upload');
      return;
    }

    final List<PlatformFile> files = result.files;

    for (var file in files) {
      if (file.bytes == null) {
        logger.w('File ${file.name} has no data, skipping upload');
        continue;
      }
      _syncStatus.addFile(file.size);
    }

    for (var file in files) {
      late Uint8List bytes;
      if (kIsWeb && file.bytes == null) {
        logger.w('File ${file.name} has no data, skipping upload');
        continue;
      } else if (file.bytes == null) {
        bytes = await io.File(file.path!).readAsBytes();
      } else {
        bytes = file.bytes!;
      }
      logger.d('Uploading file: ${file.name} to $dest');
      await api.uploadFile(file, dest, bytes);
      _syncStatus.removeFile(file.size);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> uploadFile(final PortablePath dest) async {
    await _uploadPlatformFiles(await FilePicker.platform.pickFiles(), dest);
  }

  Future<void> pickAndUploadFiles(final PortablePath dest) async {
    await _uploadPlatformFiles(
      await FilePicker.platform.pickFiles(allowMultiple: true),
      dest,
    );
  }

  Future<List<io.FileSystemEntity>> getFilesInDirectoryRecursively(
    String directoryPath,
  ) async {
    final directory = io.Directory(directoryPath);
    final elements = await directory
        .list(recursive: true)
        .where((f) => f is io.File)
        .toList();
    return elements;
  }

  Future<UploadResults> _lookupAndUpload(
    final PortablePath dest,
    String directory,
  ) async {
    UploadResults results = UploadResults();
    logger.d('Selected directory: $directory');
    final files = await getFilesInDirectoryRecursively(directory);
    logger.d('Found ${files.length} files in directory $directory');
    for (var file in files) {
      logger.d('Found file: ${file.path} to upload to $dest');
      var bytes = (await file.stat()).size;
      _syncStatus.addFile(bytes);
    }

    for (var file in files) {
      if (file is! io.File) {
        continue; // Skip if not a file
      }
      PortablePath destDir = buildDestDir(dest, directory, file);

      logger.d('Found file: ${file.path} to upload to $destDir');
      final bytes = await io.File(file.path).readAsBytes();
      PlatformFile platformFile = PlatformFile(
        name: file.path.split('/').last,
        size: bytes.length,
        bytes: bytes,
      );
      api.uploadFile(platformFile, destDir, bytes);

      results.successCount += 1;
      _syncStatus.removeFile(bytes.length);
      await Future.delayed(const Duration(seconds: 1));
    }
    logger.d('Uploading directory: $directory to $dest');
    return results;
  }

  PortablePath buildDestDir(
    PortablePath dest,
    String directory,
    io.FileSystemEntity file,
  ) {
    PortablePath destDir = PortablePath(components: []);
    for (var c in dest.components) {
      if (c.isNotEmpty) {
        destDir.add(c);
      }
    }
    destDir.add(pp.basename(directory));
    for (var c in pp.split(
      pp.dirname(pp.relative(file.path, from: directory)),
    )) {
      if (c.isNotEmpty) {
        destDir.add(c);
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
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      logger.d('No directory selected for upload');
      return Future.value((null, Future.value(UploadResults())));
    }
    return Future.value((
      selectedDirectory,
      _lookupAndUpload(dest, selectedDirectory),
    ));
  }

  Future<UploadResults> uploadDirectory(final PortablePath dest) async {
    final (selectedDirectory, resultsFuture) = await _uploadDirectory(dest);
    return resultsFuture;
  }

  Future<(SyncPath?, Future<UploadResults>)> syncDirectory(
    final PortablePath dest,
  ) async {
    final (selectedDirectory, resultsFuture) = await _uploadDirectory(dest);
    if (selectedDirectory == null) {
      return Future.value((null, Future.value(UploadResults())));
    }
    final syncPath = SyncPath(
      local: selectedDirectory.startsWith('/')
          ? PortablePath(components: pp.split(selectedDirectory))
          : PortablePath(components: ['/', ...pp.split(selectedDirectory)]),
      remote: dest,
    );
    return Future.value((syncPath, resultsFuture));
  }
}
