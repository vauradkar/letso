import 'package:letso/main.dart';

Uri getUri(Preferences preferences, String path) {
  if (preferences.serverAddress == null || preferences.serverPort == null) {
    throw Exception('Server address or port is not configured.');
  }
  return Uri.http(
    '${preferences.serverAddress}:${preferences.serverPort}',
    path,
  );
}
