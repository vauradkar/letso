import 'package:flutter/rendering.dart';
import 'package:letso/preferences.dart';
import 'package:web/web.dart' as web;

Uri getUri(Preferences preferences, String path) {
  String currentUrl = web.window.location.href;
  Uri uri = Uri.parse(currentUrl);
  String origin = uri.authority;
  // int port = uri.port;
  debugPrint('Current URL: $origin');

  return Uri.http(origin, path);
}
