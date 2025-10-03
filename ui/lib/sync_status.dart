class SyncStatus {
  bool _isUploading;
  int _remainingFiles;
  int _totalFiles;
  int _remainingBytes;
  int _totalBytes;
  final List<Function> _syncListeners = [];

  SyncStatus({
    bool isUploading = false,
    int remainingFiles = 0,
    int totalFiles = 0,
    int remainingBytes = 0,
    int totalBytes = 0,
  }) : _totalBytes = totalBytes,
       _remainingBytes = remainingBytes,
       _totalFiles = totalFiles,
       _remainingFiles = remainingFiles,
       _isUploading = isUploading;

  /// Calculate upload progress percentage (0.0 to 1.0)
  double get uploadProgress {
    if (!_isUploading) {
      return 0.0;
    }
    if (_totalFiles == 0) return 1.0;
    return (_totalFiles - _remainingFiles) / _totalFiles;
  }

  /// Calculate bytes progress percentage (0.0 to 1.0)
  double get bytesProgress {
    if (!_isUploading) {
      return 0.0;
    }
    if (_totalBytes == 0) return 1.0;
    return (_totalBytes - _remainingBytes) / _totalBytes;
  }

  /// Format bytes into human readable format
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  bool isUploading() {
    return remainingBytes != 0 || remainingFiles != 0;
  }

  int? get remainingFiles => _remainingFiles;
  int? get totalFiles => _totalFiles;
  int? get remainingBytes => _remainingBytes;
  int? get totalBytes => _totalBytes;

  void update({
    bool? isUploading,
    int? remainingFiles,
    int? totalFiles,
    int? remainingBytes,
    int? totalBytes,
  }) {
    _isUploading = isUploading ?? _isUploading;
    _remainingFiles += remainingFiles ?? 0;
    _totalFiles += totalFiles ?? 0;
    _remainingBytes += remainingBytes ?? 0;
    _totalBytes += totalBytes ?? 0;
    notifyListeners();
  }

  void addFile(int bytes) {
    update(
      remainingFiles: 1,
      totalFiles: 1,
      remainingBytes: bytes,
      totalBytes: bytes,
    );
  }

  void removeFile(int bytes) {
    update(remainingFiles: -1, remainingBytes: -bytes);
  }

  void registerListener(Function listener) {
    if (!_syncListeners.contains(listener)) {
      _syncListeners.add(listener);
    }
  }

  void unregisterListener(Function listener) {
    _syncListeners.remove(listener);
  }

  void notifyListeners() {
    for (var listener in _syncListeners) {
      listener();
    }
  }
}
