import 'package:letso/api.dart';
import 'package:letso/settings.dart';
import 'package:letso/upload_manager.dart';

/// Status information model for the StatusBar widget
class StatusInfo {
  int totalItems;

  StatusInfo({required this.totalItems});
}

class AppState {
  final Settings settings;
  final Api api;
  final UploadManager uploadManager;
  final StatusInfo statusInfo = StatusInfo(totalItems: 0);
  final List<Function> _browserListeners = [];

  AppState({
    required this.settings,
    required this.api,
    required this.uploadManager,
  });

  bool get isUploading => uploadManager.isUploading;
  int? get remainingFiles => uploadManager.remainingFiles;
  int? get totalFiles => uploadManager.totalFiles;
  int? get remainingBytes => uploadManager.remainingBytes;
  int? get totalBytes => uploadManager.totalBytes;
  void registerSyncListener(Function listener) =>
      uploadManager.registerListener(listener);
  void unregisterSyncListener(Function listener) =>
      uploadManager.unregisterListener(listener);

  void unregisterListener(Function listener) =>
      _browserListeners.remove(listener);

  /// Calculate bytes progress percentage (0.0 to 1.0)
  double get bytesProgress {
    if (!isUploading || totalBytes == null || remainingBytes == null) {
      return 0.0;
    }
    if (totalBytes == 0) return 1.0;
    return (totalBytes! - remainingBytes!) / totalBytes!;
  }

  void registerListener(Function listener) {
    registerSyncListener(listener);
    if (!_browserListeners.contains(listener)) {
      _browserListeners.add(listener);
    }
  }

  void notifyListeners() {
    for (var listener in _browserListeners) {
      listener();
    }
  }

  void updateItemsCount(int count) {
    final oldCount = statusInfo.totalItems;
    statusInfo.totalItems = count;
    if (oldCount != count) {
      notifyListeners();
    }
  }
}
