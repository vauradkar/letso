import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UploadManager {
  final List<String> destDirectory;

  UploadManager(this.destDirectory);

  Future<void> _uploadFile(PlatformFile file) async {
    final url = 'http://127.0.0.1:3000/api/upload/file';
    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll({
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE, HEAD",
    });
    request.files.add(
      http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
    );
    request.fields['description'] = "test file upload";
    request.fields['path'] = json.encode(destDirectory).toString();
    var response = await request.send();

    if (response.statusCode == 200) {
      debugPrint('File uploaded successfully!');
      var responseBody = await response.stream.bytesToString();
      debugPrint('Response: $responseBody');
    } else {
      debugPrint('File upload failed with status: ${response.statusCode}');
    }

    debugPrint('Uploading file: ${file.path} ${file.name} to $destDirectory');
  }

  Future<void> uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      _uploadFile(result.files.first);
    } else {
      debugPrint('upload cancelled to $destDirectory');
    }
  }

  Future<void> uploadFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result == null) {
      debugPrint('No files selected for upload');
      return;
    }
    for (var file in result.files) {
      await _uploadFile(file);
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
