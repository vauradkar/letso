import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_either/dart_either.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:letso/logger_manager.dart';
import 'package:letso/data.dart';
import 'package:letso/settings.dart';

Uri getUri(Settings settings, String path) {
  if (settings.serverAddress.isEmpty) {
    throw Exception('Server address or port is not configured.');
  }
  final Uri baseUrl = Uri.parse(settings.serverAddress);
  final Uri uriPath = Uri.parse(path);
  return baseUrl.resolveUri(uriPath);
}

class Api {
  final Settings _settings;

  factory Api.create(Settings settings) {
    return Api(settings);
  }

  Api(this._settings);

  Future<String> getApiVersion() async {
    final url = getUri(_settings, "/api/api_version");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load API version');
    }
  }

  Future<String> getServerVersion() async {
    final url = getUri(_settings, "/api/server_version");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load server version');
    }
  }

  Future<Either<String, Null>> uploadFile(
    PlatformFile file,
    PortablePath destDirectory,
    Uint8List bytes,
    FileStat stats,
  ) async {
    final url = getUri(_settings, "/api/upload/file");
    var request = MultipartRequest('POST', url);
    request.headers.addAll({
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE, HEAD",
    });
    request.files.add(
      MultipartFile.fromBytes('file', bytes, filename: file.name),
    );
    request.fields['path'] = json.encode(destDirectory).toString();
    request.fields['overwrite'] = json.encode(true).toString();
    request.fields['stats'] = json.encode(stats).toString();
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

    final uri = getUri(_settings, '/api/browse/path');

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
      final ret = Directory.fromJson(jsonList);
      logger.d('Received ${ret.items.length} files from server');
      return Either.right(ret);
    } else {
      // If the server did not return a 200 OK response, handle the error.
      return Either.left(
        'Browse $currentDirectory failed with code:${response.statusCode}',
      );
    }
  }

  Future<http.StreamedResponse> exhcnageDeltas(DeltaRequest deltas) async {
    var client = http.Client();
    final uri = getUri(_settings, '/api/browse/exchange_deltas');
    var request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE, HEAD",
      })
      ..body = json.encode(deltas);

    return await client.send(request);
  }
}
