import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:letso/api.dart';
import 'package:letso/data.dart';
import 'dart:io' as io;

import 'package:letso/logger_manager.dart';

class UploadResults {
  int successCount = 0;
  int failureCount = 0;
  List<String> errors = [];

  UploadResults();
}

class UploadManager {
  final PortablePath destDirectory;
  final Api api;

  UploadManager(this.destDirectory, {required this.api});

  Future<void> uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );
    if (result != null) {
      api.uploadFile(result.files.first, destDirectory);
    } else {
      logger.d('upload cancelled to $destDirectory');
    }
  }

  Future<void> uploadFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result == null) {
      logger.d('No files selected for upload');
      return;
    }
    for (var file in result.files) {
      await api.uploadFile(file, destDirectory);
    }
  }

  Future<List<io.FileSystemEntity>> getFilesInDirectoryRecursively(
    String directoryPath,
  ) async {
    final directory = io.Directory(directoryPath);
    final elements = await directory.list(recursive: true).toList();
    return elements;
  }

  Future<UploadResults> _lookupAndUpload(String directory) async {
    UploadResults results = UploadResults();
    final files = await getFilesInDirectoryRecursively(directory);
    for (var file in files) {
      logger.d('Found file: ${file.path}');
      final bytes = await io.File(file.path).readAsBytes();
      PlatformFile platformFile = PlatformFile(
        name: file.path.split('/').last,
        size: bytes.length,
        bytes: bytes,
      );
      api.uploadFile(platformFile, destDirectory);

      results.successCount += 1;
    }
    // Implement the logic to upload all files in the directory.
    logger.d('Uploading directory: $directory to $destDirectory');
    // You might want to list all files in the directory and call uploadFile for each.
    return results;
  }

  Future<UploadResults> uploadDirectory() async {
    if (kIsWeb) {
      logger.d('Directory upload is not supported on web');
      return UploadResults();
    }
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      logger.d('No directory selected for upload');
      return UploadResults();
    }
    return _lookupAndUpload(selectedDirectory);
  }
}
