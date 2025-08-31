import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:letso/data.dart';
import 'package:letso/platform_native.dart' if (kIsWeb) 'platform_web.dart';
import 'package:letso/preferences.dart';

class Api {
  final Preferences _preferences;

  factory Api.create(Preferences preferences) {
    return Api(preferences);
  }

  Api(this._preferences);

  Future<void> uploadFile(PlatformFile file, PortablePath destDirectory) async {
    final url = getUri(_preferences, "/api/upload/file");
    var request = MultipartRequest('POST', url);
    request.headers.addAll({
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE, HEAD",
    });
    request.files.add(
      MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
    );
    request.fields['description'] = "test file upload";

    request.fields['path'] = json.encode(destDirectory).toString();
    request.fields['overwrite'] = json.encode(true).toString();
    var response = await request.send();

    if (response.statusCode == 200) {
      debugPrint('File uploaded successfully!');
      var responseBody = await response.stream.bytesToString();
      debugPrint('Response: $responseBody');
    } else {
      debugPrint(
        'File upload failed with status: ${response.statusCode} error: ${await response.stream.bytesToString()}',
      );
    }

    debugPrint('Uploading file: ${file.path} ${file.name} to $destDirectory');
  }
}
