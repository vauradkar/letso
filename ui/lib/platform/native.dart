import 'package:flutter/widgets.dart';
import 'package:letso/logger_manager.dart';
import 'package:logger/logger.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlatformLogOutput implements AbstractLogOutput {
  late File file;
  late FileOutput fileOutput;
  int logSize;
  PlatformLogOutput(this.logSize);

  @override
  Future<void> clear() async {
    debugPrint('Clearing log file: ${file.path}');
    file.writeAsStringSync('');
  }

  @override
  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    debugPrint('Log directory: ${directory.path}');
    file = File('${directory.path}/app.log');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    fileOutput = FileOutput(file: file);
    return fileOutput.init();
  }

  @override
  void output(OutputEvent event) {
    debugPrint('Log event: ${event.lines.join('\n')}');
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
