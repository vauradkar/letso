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
import 'package:letso/app_state.dart';
import 'package:letso/main.dart';
import 'package:mocktail/mocktail.dart';

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
        await tester.pumpWidget(MaterialApp(home: MyApp(loader: mockLoader.call)));

        // initState() has already run — loader must have been called once.
        verify(() => mockLoader()).called(1);
      },
    );

    testWidgets(
      '2. loader is NOT called again when the widget rebuilds via setState',
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: MyApp(loader: mockLoader.call)));

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
        await tester.pumpWidget(MaterialApp(home: MyApp(loader: mockLoader.call)));

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
