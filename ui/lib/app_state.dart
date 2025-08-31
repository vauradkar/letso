import 'package:letso/api.dart';
import 'package:letso/preferences.dart';

class AppState {
  final Preferences preferences;
  final Api api;
  AppState({required this.preferences, required this.api});
}
