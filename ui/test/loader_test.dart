import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letso/api.dart';
import 'package:letso/app_state.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/main.dart';
import 'package:letso/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Api stand-in whose version endpoints always fail, simulating an
/// unreachable server without making a real network call.
class UnreachableApi extends Mock implements Api {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Default AppState Loader — server unreachable on startup', () {
    setUp(() async {
      // SharedPreferencesAsyncPlatform is a `base` class, so it can only be
      // faked with the package's own in-memory implementation rather than a
      // Mocktail mock.
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
        'serverAddress': 'http://unreachable:8080',
        'syncPaths': '[]',
      });

      // Mock path_provider for native logging.
      const MethodChannel('plugins.flutter.io/path_provider')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      });
      await logger.initLogger(logSize: 100);

      // Mock package_info_plus.
      PackageInfo.setMockInitialValues(
        appName: 'test',
        packageName: 'com.test',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
        installerStore: null,
      );
    });

    test(
      'resolves AppState gracefully with "unknown" values instead of crashing',
      () async {
        final unreachableApi = UnreachableApi();
        when(() => unreachableApi.getServerVersion())
            .thenThrow(Exception('Connection refused'));
        when(() => unreachableApi.getApiVersion())
            .thenThrow(Exception('Connection refused'));

        final AppState appState = await defaultLoadAppState(
          createApi: (Settings settings) => unreachableApi,
        );

        expect(appState.serverVersion, 'unknown');
        expect(appState.apiVersion, 'unknown');
        expect(appState.settings.serverAddress, 'http://unreachable:8080');
      },
    );
  });
}
