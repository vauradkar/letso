import 'dart:convert';

import 'package:dart_either/dart_either.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:letso/logger_manager.dart';
import 'package:letso/data.dart';
import 'package:letso/platform.dart';
import 'package:letso/preferences.dart';

class Api {
  final Preferences _preferences;

  factory Api.create(Preferences preferences) {
    return Api(preferences);
  }

  Api(this._preferences);

  Future<Either<String, Null>> uploadFile(
    PlatformFile file,
    PortablePath destDirectory,
  ) async {
    final url = Platform.getUri(_preferences, "/api/upload/file");
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
      logger.d('File uploaded successfully!');
      var responseBody = await response.stream.bytesToString();
      logger.d('Response: $responseBody');
      return Either.right(null);
    } else {
      final code = response.statusCode;
      final msg = await response.stream.bytesToString();
      logger.d('File upload failed with status: $code error: $msg');
      return Either.left(
        'File (${file.name}) upload failed : $code error: $msg',
      );
    }
  }

  Future<Either<String, Directory>> browsePath(
    PortablePath currentDirectory,
  ) async {
    // await Future.delayed(const Duration(seconds: 1));

    final uri = Platform.getUri(_preferences, '/api/browse/path');

    // final response = await http.get(uri);
    logger.i(
      'posting data to $uri with body: ${json.encode(currentDirectory)}',
    );
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE, HEAD",
      },
      body: json.encode(currentDirectory),
    );
    logger.d('Posted data to $uri with body: $currentDirectory');

    if (response.statusCode == 200) {
      // If the server returns a 200 OK response, parse the JSON.
      final Map<String, dynamic> jsonList = json.decode(response.body);
      logger.d('Response JSON: $jsonList');
      return Either.right(Directory.fromJson(jsonList));
    } else {
      // If the server did not return a 200 OK response, handle the error.
      return Either.left(
        'Browse $currentDirectory failed with code:${response.statusCode}',
      );
    }
  }
}
