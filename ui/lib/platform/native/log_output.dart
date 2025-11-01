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
    file.writeAsStringSync('');
  }

  @override
  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    file = File('${directory.path}/app.log');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    if (await file.length() > 1024 * 1024) {
      var raf = await file.open(mode: FileMode.write);
      await raf.truncate(0);
      await raf.close();
    }
    fileOutput = FileOutput(file: file);
    return fileOutput.init();
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
