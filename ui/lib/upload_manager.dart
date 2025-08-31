import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:letso/api.dart';
import 'package:letso/data.dart';

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
      debugPrint('upload cancelled to $destDirectory');
    }
  }

  Future<void> uploadFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result == null) {
      debugPrint('No files selected for upload');
      return;
    }
    for (var file in result.files) {
      await api.uploadFile(file, destDirectory);
    }
  }

  Future<void> uploadDirectory() async {
    if (kIsWeb) {
      debugPrint('Directory upload is not supported on web');
      return;
    }
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      debugPrint('No directory selected for upload');
      return;
    }
    // Implement the logic to upload all files in the directory.
    debugPrint('Uploading directory: $selectedDirectory to $destDirectory');
    // You might want to list all files in the directory and call uploadFile for each.
  }
}
