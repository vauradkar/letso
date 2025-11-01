import 'dart:io' as io;

import 'package:letso/data.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

bool isSupportedFileType(io.FileStat stat) {
  return stat.type == io.FileSystemEntityType.directory ||
      stat.type == io.FileSystemEntityType.file;
}

Future<FileStat?> getFileStats(io.FileSystemEntity e) async {
  if (!await e.exists()) {
    return null;
  }
  var stats = await e.stat();
  if (!isSupportedFileType(stats)) {
    return null;
  }
  return FileStat.fromIoFileStat(stats);
}
