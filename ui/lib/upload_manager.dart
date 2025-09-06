import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:letso/api.dart';
import 'package:letso/data.dart';
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

  UploadManager({required this.api});

  Future<void> uploadFile(final PortablePath dest) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );
    if (result != null) {
      api.uploadFile(result.files.first, dest);
    } else {
      logger.d('upload cancelled to $dest');
    }
  }

  Future<void> uploadFiles(final PortablePath dest) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result == null) {
      logger.d('No files selected for upload');
      return;
    }
    for (var file in result.files) {
      await api.uploadFile(file, dest);
    }
  }

  Future<List<io.FileSystemEntity>> getFilesInDirectoryRecursively(
    String directoryPath,
  ) async {
    final directory = io.Directory(directoryPath);
    final elements = await directory.list(recursive: true).toList();
    return elements;
  }

  Future<UploadResults> _lookupAndUpload(
    final PortablePath dest,
    String directory,
  ) async {
    UploadResults results = UploadResults();
    logger.d('Selected directory: $directory');
    final files = await getFilesInDirectoryRecursively(directory);
    for (var file in files) {
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

      logger.d('Found file: ${file.path} to upload to $destDir');
      if (file is! io.File) {
        continue; // Skip if not a file
      }
      final bytes = await io.File(file.path).readAsBytes();
      PlatformFile platformFile = PlatformFile(
        name: file.path.split('/').last,
        size: bytes.length,
        bytes: bytes,
      );
      api.uploadFile(platformFile, destDir);

      results.successCount += 1;
    }
    // Implement the logic to upload all files in the directory.
    logger.d('Uploading directory: $directory to $dest');
    // You might want to list all files in the directory and call uploadFile for each.
    return results;
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
