// Tests for the SettingsPage loader lifecycle fix (same anti-pattern as
// bug #1 in main.dart / MyApp — see widget_test.dart).
//
// The bug: _loadSettings() was called inline as the `future:` argument to
// FutureBuilder inside build(), so it ran again on every rebuild — not just
// the first one. Since _loadSettings() overwrites
// _serverAddressController.text with the persisted value, any unrelated
// rebuild (e.g. a parent MediaQuery change) would clobber whatever the user
// was actively typing. The fix: compute the Future once in initState() and
// cache it in _loadSettingsFuture.
//
// This test verifies that an in-progress edit to the server address field
// survives a rebuild that isn't triggered by the user's own edit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letso/settings_page.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // SharedPreferencesAsyncPlatform is a `base` class, so it can only be
    // faked with the package's own in-memory implementation rather than a
    // Mocktail mock.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      'serverAddress': 'https://initial.example.com',
      'syncPaths': '[]',
    });
  });

  testWidgets(
    'an in-progress edit survives an unrelated rebuild',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(onChange: () {}, appState: null),
        ),
      );
      await tester.pump();
      await tester.pump();

      final textFieldFinder = find.byType(TextField);
      expect(
        tester.widget<TextField>(textFieldFinder).controller!.text,
        'https://initial.example.com',
      );

      // Simulate the user typing an address that hasn't been saved yet.
      await tester.enterText(
        textFieldFinder,
        'https://edited.example.com:9090',
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(textFieldFinder).controller!.text,
        'https://edited.example.com:9090',
      );

      // Trigger a rebuild that has nothing to do with the text field —
      // an empty setState(), same as e.g. a sibling StatusBar tick would
      // cause — to prove the loader isn't re-invoked (and the field isn't
      // clobbered) on every build(). Calling setState() directly is the
      // idiomatic way to force a rebuild of an existing State in a widget
      // test without going through initState() again.
      final state = tester.state(find.byType(SettingsPage));
      // ignore: invalid_use_of_protected_member
      (state as dynamic).setState(() {});
      // Give any (buggy) freshly-created Future a chance to resolve and
      // overwrite the controller before we assert on its final value.
      await tester.pump();
      await tester.pump();

      // The edit must still be there — it must not have been clobbered by
      // a re-run of _loadSettings() reloading the persisted value.
      expect(
        tester.widget<TextField>(textFieldFinder).controller!.text,
        'https://edited.example.com:9090',
      );
    },
  );
}
