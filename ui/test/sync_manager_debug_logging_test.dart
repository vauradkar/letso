// Regression test/benchmark for finding #15 in
// docs/bugs_and_performance_report.md ("Unconditional per-file
// debug-logging pass over the entire sync set").
//
// The bug: SyncManager.sync() ran two full loops over every local and
// received SyncItem purely to build and emit logger.d(...) strings, with
// no guard — the iteration and string interpolation happened on every
// sync run, even in release builds where debug-level output is never
// surfaced. For directories with many files this wasted work runs and is
// then discarded.
//
// The fix: extract the dump into SyncManager._logSyncDebugInfo(), gated by
// a `debugEnabled` flag (wired to kDebugMode in production), so the loops
// are skipped entirely when disabled.
//
// kDebugMode is a compile-time constant that's always true under
// `flutter test`, so it can't be flipped to prove the guard from a test
// that goes through SyncManager.sync() itself. Instead, this test drives
// the extracted logic directly via the @visibleForTesting
// logSyncDebugInfoForTesting() wrapper, passing `debugEnabled` explicitly.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letso/api.dart';
import 'package:letso/data.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/platform/native/sync_manager.dart';
import 'package:letso/upload_manager.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements Api {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncManager syncManager;

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

    final mockApi = MockApi();
    syncManager = SyncManager(
      api: mockApi,
      uploadManager: UploadManager(api: mockApi),
    );
  });

  // A SyncItem with `stats: null` makes `entry.value.stats!` (the debug
  // dump's first line) throw a null-check error if the loop body ever
  // runs. This lets the test prove "no work happened" or "work happened"
  // without needing to mock or spy on the logger itself.
  Map<String, SyncItem> statslessItems(int count) => {
    for (var i = 0; i < count; i++)
      'item_$i': SyncItem(path: PortablePath.fromString('/item_$i')),
  };

  test(
    'debug dump is skipped entirely when debugEnabled is false',
    () {
      final localStats = statslessItems(5);
      const recvd = <String, SyncItem>{};

      expect(
        () => syncManager.logSyncDebugInfoForTesting(
          localStats,
          recvd,
          debugEnabled: false,
        ),
        returnsNormally,
      );
    },
  );

  test(
    'debug dump does iterate and format every item when debugEnabled is '
    'true (proving the guard actually gates real work, not a no-op)',
    () {
      final localStats = statslessItems(5);
      const recvd = <String, SyncItem>{};

      expect(
        () => syncManager.logSyncDebugInfoForTesting(
          localStats,
          recvd,
          debugEnabled: true,
        ),
        throwsA(isA<TypeError>()),
      );
    },
  );

  test(
    'benchmark: disabling the debug dump avoids the per-item formatting '
    'cost over a large sync set',
    () {
      const itemCount = 500;
      final localStats = <String, SyncItem>{
        for (var i = 0; i < itemCount; i++)
          'item_$i': SyncItem(
            path: PortablePath.fromString('/item_$i'),
            stats: const FileStat(
              size: 123,
              mtime: '2026-01-01T00:00:00Z',
              isDirectory: false,
              sha256: 'deadbeef',
            ),
          ),
      };
      final recvd = <String, SyncItem>{};

      final disabledStopwatch = Stopwatch()..start();
      syncManager.logSyncDebugInfoForTesting(
        localStats,
        recvd,
        debugEnabled: false,
      );
      disabledStopwatch.stop();

      final enabledStopwatch = Stopwatch()..start();
      syncManager.logSyncDebugInfoForTesting(
        localStats,
        recvd,
        debugEnabled: true,
      );
      enabledStopwatch.stop();

      // ignore: avoid_print
      print(
        'sync debug-dump benchmark: $itemCount items -> '
        'debugEnabled=false took ${disabledStopwatch.elapsedMicroseconds}us, '
        'debugEnabled=true took ${enabledStopwatch.elapsedMicroseconds}us',
      );

      // The disabled path does one boolean check and returns; the enabled
      // path formats and logs $itemCount strings. Assert the disabled path
      // is at least an order of magnitude faster, which comfortably holds
      // given the enabled path's work is proportional to itemCount while
      // the disabled path's is O(1).
      expect(
        disabledStopwatch.elapsedMicroseconds * 10,
        lessThan(enabledStopwatch.elapsedMicroseconds),
        reason:
            'skipping the debug dump should be far cheaper than running it; '
            'got disabled=${disabledStopwatch.elapsedMicroseconds}us '
            'enabled=${enabledStopwatch.elapsedMicroseconds}us',
      );
    },
  );
}
