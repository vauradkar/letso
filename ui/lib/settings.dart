import 'dart:convert';
import 'package:letso/data.dart';
import 'package:letso/platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  String serverAddress = '';
  List<SyncPath> syncPaths = [];

  Settings();

  Future<void> load() async {
    serverAddress = await Platform.loadServerAddress();
    syncPaths =
        (json.decode(
                  await SharedPreferencesAsync().getString('syncPaths') ?? '[]',
                )
                as List)
            .map((e) => SyncPath.fromJson(e))
            .toList();
  }

  static Future<Settings> loadSettings() async {
    final settings = Settings();
    await settings.load();
    return settings;
  }

  bool isConfigured() {
    return serverAddress.isNotEmpty;
  }

  Future<void> save() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('serverAddress', serverAddress);
    await prefs.setString(
      'syncPaths',
      json.encode(syncPaths.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addSyncPath(SyncPath path) async {
    syncPaths.add(path);
    await save();
  }

  Future<void> removeSyncPath(SyncPath path) async {
    syncPaths.remove(path);
    await save();
  }
}
