import 'dart:convert';
import 'package:letso/data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  String serverAddress = '';
  String serverPort = '';
  List<SyncPath> syncPaths = [];

  Settings();

  Future<void> load() async {
    final prefs = SharedPreferencesAsync();
    serverAddress = await prefs.getString('serverAddress') ?? '';
    serverPort = await prefs.getString('serverPort') ?? '';
    syncPaths =
        (json.decode(await prefs.getString('syncPaths') ?? '[]') as List)
            .map((e) => SyncPath.fromJson(e))
            .toList();
  }

  Future<void> save() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('serverAddress', serverAddress);
    await prefs.setString('serverPort', serverPort);
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
