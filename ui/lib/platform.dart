// ignore: unused_import
import 'package:flutter/foundation.dart';
import 'package:letso/platform/none.dart'
    if (dart.library.io) 'platform/native.dart'
    if (dart.library.html) 'platform/web.dart'
    as x;

typedef AppLogOutput = x.PlatformLogOutput;
typedef SyncManager = x.SyncManager;

class Platform {
  static Future<String> loadServerAddress() => x.loadServerAddress();
}
