// Tests for the MyApp loader lifecycle fix (bug #1 in bug_report).
//
// The bug: _loadAppState() was called on every build(), causing repeated
// network requests. The fix: compute the Future once in initState() and
// cache it in _appStateFuture.
//
// These tests verify:
//  1. The loader is invoked exactly once on initial build.
//  2. The loader is NOT invoked again when the widget rebuilds (setState).
//  3. The loader IS invoked again when _reloadAppState() is explicitly called.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letso/api.dart';
import 'package:letso/app_state.dart';
import 'package:letso/main.dart';
import 'package:letso/settings.dart';
import 'package:letso/upload_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ---------------------------------------------------------------------------
// Mock / Fake declarations
// ---------------------------------------------------------------------------

/// Mocktail mock for the [AppStateLoader] typedef.
///
/// Mocktail needs a class with a matching [call()] method to intercept
/// invocations of the callable object.
class MockAppStateLoader extends Mock {
  Future<AppState> call();
}

/// Fake [Api] — satisfies the interface without making network calls.
class FakeApi extends Fake implements Api {}

/// Fake [UploadManager] — implements only the members touched by [AppState]
/// and the widgets rendered while the app is in its loading state.
class FakeUploadManager extends Fake implements UploadManager {
  @override
  bool get isUploading => false;
  @override
  int? get remainingFiles => null;
  @override
  int? get totalFiles => null;
  @override
  int? get remainingBytes => null;
  @override
  int? get totalBytes => null;
  @override
  void registerListener(Function listener) {}
  @override
  void unregisterListener(Function listener) {}
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Builds a minimal [AppState] with an empty server address (unconfigured).
///
/// The widget tree that renders in this state is just the loading indicator
/// (if the Future is still pending) or the SettingsPage (once resolved).
/// Using a [Completer]-controlled future keeps the widget in the loading
/// state, avoiding any platform-plugin calls (SharedPreferences, etc.).
AppState _makeAppState() {
  final settings = Settings()..serverAddress = '';
  return AppState(
    settings: settings,
    api: FakeApi(),
    uploadManager: FakeUploadManager(),
    serverVersion: '0.0.0',
    apiVersion: '1',
    packageInfo: PackageInfo(
      appName: 'test',
      packageName: 'com.test',
      version: '1.0.0',
      buildNumber: '1',
      installerStore: null,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAppStateLoader mockLoader;
  late Completer<AppState> completer;

  setUp(() {
    mockLoader = MockAppStateLoader();
    completer = Completer<AppState>();
    // Return a never-completing future so the widget stays in loading state.
    // This avoids any downstream platform calls (SharedPreferences, etc.)
    // while still letting us verify loader call counts.
    when(() => mockLoader()).thenAnswer((_) => completer.future);
  });

  group('MyApp — AppStateLoader lifecycle', () {
    testWidgets(
      '1. loader is called exactly once on initial build',
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: MyApp(loader: mockLoader)));

        // initState() has already run — loader must have been called once.
        verify(() => mockLoader()).called(1);
      },
    );

    testWidgets(
      '2. loader is NOT called again when the widget rebuilds via setState',
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: MyApp(loader: mockLoader)));

        // Consume the initial call so the verify below starts from a clean slate.
        verify(() => mockLoader()).called(1);

        // Trigger a rebuild by resizing the test viewport — this calls build()
        // but must NOT create a new Future.
        tester.view.physicalSize = const Size(800, 1200);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pump();

        // No new interactions since the last verify().
        verifyNever(() => mockLoader());
      },
    );

    testWidgets(
      '3. loader IS called again after _reloadAppState() (e.g. settings saved)',
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: MyApp(loader: mockLoader)));

        // Consume the first call.
        verify(() => mockLoader()).called(1);

        // _reloadAppState is private. We use the @visibleForTesting wrapper
        // method which delegates to it — the idiomatic Flutter pattern for
        // driving private state methods from tests without reflection.
        final state = tester.state(find.byType(MyApp));
        // ignore: invalid_use_of_visible_for_testing_member
        (state as dynamic).reloadAppStateForTesting();
        await tester.pump();

        // Exactly one more invocation — the fresh Future was created.
        verify(() => mockLoader()).called(1);
      },
    );
  });
}
