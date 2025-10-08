import 'package:letso/logger_manager.dart';
import 'package:logger/logger.dart';

class PlatformLogOutput implements AbstractLogOutput {
  int logSize;
  PlatformLogOutput(this.logSize);

  @override
  Future<void> clear() async {}

  @override
  Future<void> init() async {}

  @override
  void output(OutputEvent event) {}

  @override
  Future<void> destroy() async {}

  @override
  Future<String> getLogs() async {
    return '';
  }
}

Future<String> loadServerAddress() async {
  return "";
}
