// ignore: unused_import
import 'package:flutter/foundation.dart';
import 'package:letso/platform/none.dart'
    if (dart.library.io) 'platform/native.dart'
    if (dart.library.html) 'platform/web.dart'
    as x;
import 'package:letso/preferences.dart';

typedef AppLogOutput = x.PlatformLogOutput;

class Platform {
  static Uri getUri(Preferences preferences, String path) =>
      x.getUri(preferences, path);
}
