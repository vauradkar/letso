import 'package:flutter/foundation.dart';
import 'package:letso/platform.dart';
import 'package:logger/logger.dart';

abstract class AbstractLogOutput extends LogOutput {
  Future<void> clear();
  Future<String> getLogs();
}

AppLogger logger = AppLogger();

class NoFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

class AppLogger {
  late AbstractLogOutput _logOutput;
  late Logger _logger;
  //  = Logger(
  //   printer: SimplePrinter(),
  //   filter: NoFilter(),
  //   level: kDebugMode ? Level.debug : Level.info,
  // );

  AppLogger();

  Future<void> initLogger({required int logSize}) async {
    _logOutput = AppLogOutput(logSize);
    await _logOutput.init();

    _logger = Logger(
      printer: SimplePrinter(printTime: true, colors: true),
      output: _logOutput,
      filter: NoFilter(),
      level: kDebugMode ? Level.debug : Level.info,
    );
  }

  Future<String> getLogs() async => _logOutput.getLogs();

  void t(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.t(message, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.debug].
  void d(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.d(message, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.info].
  void i(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.i(message, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.warning].
  void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.w(message, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.error].
  void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.e(message, time: time, error: error, stackTrace: stackTrace);
  }

  /// Log a message at level [Level.fatal].
  void f(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.f(message, time: time, error: error, stackTrace: stackTrace);
  }

  void clear() {
    _logOutput.clear();
  }
}
