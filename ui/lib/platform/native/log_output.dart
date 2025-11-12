import 'package:flutter/widgets.dart';
import 'package:letso/logger_manager.dart';
import 'package:logger/logger.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlatformLogOutput implements AbstractLogOutput {
  late File file;
  late AdvancedFileOutput fileOutput;
  int logSize;
  PlatformLogOutput(this.logSize);

  @override
  Future<void> clear() async {
    file.writeAsStringSync('');
    await initWithOverride(true);
  }

  Future<void> initWithOverride(bool overrideExisting) async {
    final directory = await getApplicationDocumentsDirectory();
    final logsDir = '${directory.path}/logs';
    final logFileName = 'app_log.txt';
    file = File("$logsDir/$logFileName");
    fileOutput = AdvancedFileOutput(
      path: logsDir,
      latestFileName: logFileName,
      maxFileSizeKB: 1024,
      maxRotatedFilesCount: 2,
    );
    return fileOutput.init();
  }

  @override
  Future<void> init() async {
    await initWithOverride(false);
  }

  @override
  void output(OutputEvent event) {
    debugPrint('Log event: ${event.lines.join('\n')}', wrapWidth: 1024);
    fileOutput.output(event);
  }

  @override
  Future<void> destroy() {
    return fileOutput.destroy();
  }

  @override
  Future<String> getLogs() async {
    if (await file.exists()) {
      return file.readAsString();
    } else {
      return '';
    }
  }
}

Future<String> loadServerAddress() async {
  final SharedPreferencesAsync prefs = SharedPreferencesAsync();
  return await prefs.getString('serverAddress') ?? '';
}
