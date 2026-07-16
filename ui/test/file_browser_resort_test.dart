// Regression test for bug #16 in docs/bugs_and_performance_report.md.
//
// The bug: didUpdateWidget() decided whether to re-sort by comparing
// `oldWidget.directory.items != widget.directory.items` — a reference
// identity check. `Directory` is freshly deserialized from JSON on every
// `browsePath` call, so `items` is always a new `List` of new
// `DirectoryEntry` instances even when the contents are unchanged, making
// the check effectively always true and triggering a full re-sort on every
// rebuild.
//
// The fix: compare directory contents by value (name + stats) rather than
// list identity, and only re-sort when the contents actually differ.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letso/api.dart';
import 'package:letso/app_state.dart';
import 'package:letso/browser_container.dart';
import 'package:letso/data.dart';
import 'package:letso/file_browser.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/settings.dart';
import 'package:letso/upload_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MockApi extends Mock implements Api {}

Directory _directoryWith(List<DirectoryEntry> items) =>
    Directory(currentPath: const PortablePath(["/"]), items: items);

DirectoryEntry _entry(String name) => DirectoryEntry(
  name: name,
  stats: const FileStat(
    size: 1,
    mtime: '2026-01-01T00:00:00Z',
    isDirectory: false,
    sha256: null,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState appState;

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

    final mockApi = MockApi();
    appState = AppState(
      settings: Settings(),
      api: mockApi,
      uploadManager: UploadManager(api: mockApi),
      apiVersion: '1',
      serverVersion: '1',
      packageInfo: await PackageInfo.fromPlatform(),
    );
  });

  Widget buildFileBrowser(Directory directory) => MaterialApp(
    home: Scaffold(
      body: FileBrowser(
        directory: directory,
        appState: appState,
        eventHandlers: EventHandlers(
          onItemTap: (_) {},
          onItemDoubleTap: (_) {},
          onAncestorTap: (_) {},
        ),
      ),
    ),
  );

  testWidgets(
    'does not re-sort when a freshly-deserialized Directory has identical '
    'contents',
    (tester) async {
      await tester.pumpWidget(
        buildFileBrowser(_directoryWith([_entry('b'), _entry('a')])),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(FileBrowser)) as dynamic;
      expect(state.sortCallCountForTesting, 1);

      // New Directory/List/DirectoryEntry instances (as a fresh JSON
      // deserialization would produce), but identical contents.
      await tester.pumpWidget(
        buildFileBrowser(_directoryWith([_entry('b'), _entry('a')])),
      );
      await tester.pumpAndSettle();

      expect(state.sortCallCountForTesting, 1);
    },
  );

  testWidgets('re-sorts when directory contents actually change', (
    tester,
  ) async {
    await tester.pumpWidget(buildFileBrowser(_directoryWith([_entry('a')])));
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(FileBrowser)) as dynamic;
    expect(state.sortCallCountForTesting, 1);

    await tester.pumpWidget(
      buildFileBrowser(_directoryWith([_entry('a'), _entry('c')])),
    );
    await tester.pumpAndSettle();

    expect(state.sortCallCountForTesting, 2);
  });
}
