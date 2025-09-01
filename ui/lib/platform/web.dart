import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/preferences.dart';
import 'package:logger/logger.dart';
import 'package:web/web.dart' as web;

Uri getUri(Preferences preferences, String path) {
  String currentUrl = web.window.location.href;
  Uri uri = Uri.parse(currentUrl);
  String origin = uri.authority;
  // int port = uri.port;
  logger.d('Current URL: $origin');

  return Uri.http(origin, path);
}

class FixedSizeStringBuffer {
  final int capacity;
  int currentCapacity = 0;
  final Queue<String> _buffer;

  FixedSizeStringBuffer(this.capacity) : _buffer = Queue<String>();

  void add(String item) {
    while ((currentCapacity + item.length) > capacity && _buffer.isNotEmpty) {
      String removed = _buffer.removeFirst();
      currentCapacity -= removed.length;
    }
    _buffer.addLast(item);
    currentCapacity += item.length;
  }

  @override
  String toString() {
    return _buffer.join("\n");
  }

  void clear() {
    _buffer.clear();
    currentCapacity = 0;
  }

  int get length => currentCapacity;
}

class TeeOutput extends LogOutput implements AbstractLogOutput {
  final LogOutput _consoleOutput = ConsoleOutput();
  final FixedSizeStringBuffer _buffer;

  TeeOutput(int logSize) : _buffer = FixedSizeStringBuffer(logSize);

  @override
  void output(OutputEvent event) {
    debugPrint('Tee Log event: ${event.lines.join('\n')}');
    _consoleOutput.output(event);
    for (var line in event.lines) {
      _buffer.add(line);
    }
  }

  @override
  Future<void> init() async {
    return _consoleOutput.init();
  }

  @override
  Future<void> clear() async {
    _buffer.clear();
  }

  @override
  Future<String> getLogs() async {
    return _buffer.toString();
  }
}
