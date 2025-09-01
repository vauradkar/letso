// ignore: unused_import
import 'package:flutter/foundation.dart';
import 'package:letso/platform/native.dart'
    if (kIsWeb) 'package:letso/platform/web.dart'
    as x;
import 'package:letso/preferences.dart';

typedef AppLogOutput = x.PlatformLogOutput;

class Platform {
  static Uri getUri(Preferences preferences, String path) =>
      x.getUri(preferences, path);
}
