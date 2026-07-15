// Regression test for bug #2 in docs/bugs_and_performance_report.md.
//
// The bug: _BrowserContainerState.initState() registered an anonymous
// listener closure with AppState via registerListener(), but there was no
// dispose() override to unregister it, and being anonymous, there was no
// reference to unregister anyway. If AppState.notifyListeners() fired after
// the widget was unmounted (e.g. a pending browsePath response or a
// sync-status update), the stale closure called setState() on a disposed
// State, throwing "setState() called after dispose()".
//
// The fix: store the listener in a field and unregister it in an overridden
// dispose().

import 'package:dart_either/dart_either.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letso/api.dart';
import 'package:letso/app_state.dart';
import 'package:letso/browser_container.dart';
import 'package:letso/data.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/settings.dart';
import 'package:letso/upload_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MockApi extends Mock implements Api {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApi mockApi;
  late AppState appState;

  setUpAll(() {
    registerFallbackValue(const PortablePath(["/"]));
  });

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      },
    );
    await logger.initLogger(logSize: 100);
    PackageInfo.setMockInitialValues(
      appName: 'test',
      packageName: 'com.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );

    mockApi = MockApi();
    when(() => mockApi.browsePath(any())).thenAnswer(
      (_) async => Either.right(
        Directory(currentPath: const PortablePath(["/"]), items: const []),
      ),
    );

    appState = AppState(
      settings: Settings(),
      api: mockApi,
      uploadManager: UploadManager(api: mockApi),
      apiVersion: '1',
      serverVersion: '1',
      packageInfo: await PackageInfo.fromPlatform(),
    );
  });

  testWidgets(
    'BrowserContainer unregisters its AppState listener on dispose, '
    'so a later notifyListeners() does not throw',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BrowserContainer(appState: appState))),
      );
      await tester.pumpAndSettle();

      // Unmount BrowserContainer — this must run dispose().
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // Before the fix, this would call setState() on the disposed
      // _BrowserContainerState via the still-registered anonymous listener,
      // throwing a FlutterError ("setState() called after dispose()").
      expect(() => appState.notifyListeners(), returnsNormally);
    },
  );
}
