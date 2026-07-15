// Regression test for bug #3 in docs/bugs_and_performance_report.md.
//
// The bug: the FutureBuilder's `future:` argument in
// _BrowserContainerState.build() called `widget.appState.api.browsePath()`
// inline, so a new network request was fired on *every* rebuild, not just
// when currentDirectory changed. Combined with the listener rebuilds from
// bug #2, this could hammer the server with repeated directory listing
// requests.
//
// The fix: cache the Future in state, created in initState()/on explicit
// navigation, and read the cached future in build().

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
    // Every browsePath call, regardless of the requested directory, returns
    // a listing containing one subdirectory — enough to drive navigation
    // without needing per-path responses.
    when(() => mockApi.browsePath(any())).thenAnswer(
      (_) async => Either.right(
        Directory(
          currentPath: const PortablePath(["/"]),
          items: [
            DirectoryEntry(
              name: 'subdir',
              stats: const FileStat(
                size: 0,
                mtime: '2026-01-01T00:00:00Z',
                isDirectory: true,
                sha256: null,
              ),
            ),
          ],
        ),
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

  testWidgets('browsePath is requested exactly once on initial build', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: BrowserContainer(appState: appState))),
    );
    await tester.pumpAndSettle();

    verify(() => mockApi.browsePath(any())).called(1);
  });

  testWidgets(
    'browsePath is NOT re-requested when AppState notifies listeners for '
    'an unrelated reason (e.g. sync progress) and the widget rebuilds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BrowserContainer(appState: appState))),
      );
      await tester.pumpAndSettle();
      verify(() => mockApi.browsePath(any())).called(1);

      appState.notifyListeners();
      await tester.pump();

      verifyNever(() => mockApi.browsePath(any()));
    },
  );

  testWidgets(
    'browsePath IS requested again when the user navigates into a directory',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BrowserContainer(appState: appState))),
      );
      await tester.pumpAndSettle();
      verify(() => mockApi.browsePath(any())).called(1);

      // Drive navigation the same way tapping the "subdir" row would
      // (see the @visibleForTesting wrapper on _BrowserContainerState),
      // avoiding reliance on hit-testing a specific view's row layout.
      final state = tester.state(find.byType(BrowserContainer));
      // ignore: invalid_use_of_visible_for_testing_member
      (state as dynamic).navigateToForTesting(
        const PortablePath(["/", "subdir"]),
      );
      await tester.pumpAndSettle();

      verify(() => mockApi.browsePath(any())).called(1);
    },
  );
}
