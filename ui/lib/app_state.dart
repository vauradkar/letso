import 'package:letso/api.dart';
import 'package:letso/preferences.dart';
import 'package:letso/upload_manager.dart';

class AppState {
  final Preferences preferences;
  final Api api;
  final UploadManager uploadManager;

  AppState({
    required this.preferences,
    required this.api,
    required this.uploadManager,
  });
}
