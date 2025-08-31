import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  String? serverAddress;
  String? serverPort;

  bool isConfigured() {
    return serverAddress != null &&
        serverPort != null &&
        serverAddress!.isNotEmpty &&
        serverPort!.isNotEmpty;
  }

  static Future<Preferences> loadPreferences() async {
    // await Future.delayed(const Duration(seconds: 2));
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    String? serverAddress = await prefs.getString('serverAddress');
    String? serverPort = await prefs.getString('serverPort');

    return Preferences()
      ..serverAddress = serverAddress
      ..serverPort = serverPort;
  }
}
