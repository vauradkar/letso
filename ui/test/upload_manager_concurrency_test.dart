// Regression test/benchmark for finding #14 in
// docs/bugs_and_performance_report.md ("File uploads run strictly
// sequentially").
//
// The bug: both bulk-upload paths (UploadManager._uploadPlatformFiles and
// UploadManager.uploadFiles) awaited api.uploadFile() one file at a time in
// a plain `for` loop, so total time scaled linearly with file count
// regardless of available concurrency. The fix batches uploads with a
// bounded worker pool (UploadManager._runConcurrently), configurable via
// the `concurrency` parameter (default UploadManager.defaultUploadConcurrency).
//
// This file has two tests:
//  1. A deterministic, non-flaky correctness test that proves uploads are
//     actually issued concurrently (not one at a time) and that the
//     configured cap is respected, using manually-controlled Completers
//     instead of timers.
//  2. A benchmark that measures real wall-clock time for a simulated-latency
//     upload with concurrency=1 vs. concurrency=N, and asserts a
//     conservative speedup — proving the fix's actual real-world effect.

import 'dart:async';
import 'dart:io' as io;

import 'package:dart_either/dart_either.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letso/api.dart';
import 'package:letso/data.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/upload_manager.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements Api {}

/// Polls [condition] until it's true, rather than assuming a fixed number
/// of event-loop turns — real dart:io calls (file stat, reads) interleave
/// an unpredictable number of microtasks/timers before reaching the mocked
/// network call, so a fixed `await Future.delayed(Duration.zero)` count
/// would be unreliable. Fails loudly on timeout instead of hanging.
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('waitUntil timed out waiting for condition to become true');
    }
    await Future.delayed(const Duration(milliseconds: 1));
  }
}

Future<io.Directory> _makeTempFiles(int count, {String prefix = 'f'}) async {
  final tempDir = await io.Directory.systemTemp.createTemp(
    'upload_concurrency_test',
  );
  for (var i = 0; i < count; i++) {
    await io.File('${tempDir.path}/${prefix}_$i.txt').writeAsString('$i');
  }
  return tempDir;
}

List<SyncItem> _syncItemsFor(io.Directory dir, int count, {String prefix = 'f'}) {
  return [
    for (var i = 0; i < count; i++)
      SyncItem(
        path: PortablePath.fromString('${dir.path}/${prefix}_$i.txt'),
        stats: const FileStat(
          size: 1,
          mtime: '2026-01-01T00:00:00Z',
          isDirectory: false,
          sha256: null,
        ),
      ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(PlatformFile(name: 'dummy', size: 0));
    registerFallbackValue(const PortablePath([]));
    registerFallbackValue(
      const FileStat(size: 0, mtime: '', isDirectory: false, sha256: null),
    );
    registerFallbackValue(Uint8List(0));
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
  });

  test(
    'uploadFiles issues uploads concurrently, up to the configured cap, '
    'instead of one at a time',
    () async {
      const totalFiles = 6;
      const concurrency = 3;

      final tempDir = await _makeTempFiles(totalFiles);
      final items = _syncItemsFor(tempDir, totalFiles);

      final mockApi = MockApi();
      final uploadManager = UploadManager(api: mockApi);

      var inFlight = 0;
      var maxInFlight = 0;
      final pending = <Completer<Either<String, Null>>>[];

      when(() => mockApi.uploadFile(any(), any(), any(), any())).thenAnswer((
        _,
      ) {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        final completer = Completer<Either<String, Null>>();
        pending.add(completer);
        return completer.future.whenComplete(() => inFlight--);
      });

      final resultsFuture = uploadManager.uploadFiles(
        items,
        PortablePath.fromString('/dest'),
        PortablePath.fromString(tempDir.path),
        concurrency: concurrency,
      );

      // Wait for the first wave of workers to reach the (mocked) network
      // call. With the old strictly-sequential implementation, only 1
      // would ever be pending at once.
      await waitUntil(() => pending.length == concurrency);
      expect(
        inFlight,
        concurrency,
        reason:
            'exactly `concurrency` uploads should be in flight at once, '
            'not all $totalFiles and not just 1',
      );

      // Release the first wave; this should let the remaining workers pick
      // up the rest of the files, but the cap must never be exceeded.
      for (final c in List.of(pending)) {
        c.complete(const Either.right(null));
      }
      await waitUntil(() => pending.length == totalFiles);

      expect(
        maxInFlight,
        concurrency,
        reason: 'concurrency cap must never be exceeded',
      );

      for (final c in pending.skip(concurrency)) {
        c.complete(const Either.right(null));
      }

      final results = await resultsFuture;
      await tempDir.delete(recursive: true);

      expect(results.successCount, totalFiles);
      expect(results.failureCount, 0);
      expect(uploadManager.isUploading, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'benchmark: concurrent uploads are meaningfully faster than sequential '
    'ones under simulated per-request latency',
    () async {
      const totalFiles = 10;
      const perUploadLatency = Duration(milliseconds: 30);
      const concurrency = 5;

      Future<Duration> runAndTime(int concurrency) async {
        final tempDir = await _makeTempFiles(totalFiles, prefix: 'c$concurrency');
        final items = _syncItemsFor(tempDir, totalFiles, prefix: 'c$concurrency');

        final mockApi = MockApi();
        final uploadManager = UploadManager(api: mockApi);
        when(
          () => mockApi.uploadFile(any(), any(), any(), any()),
        ).thenAnswer((_) async {
          await Future.delayed(perUploadLatency);
          return const Either.right(null);
        });

        final stopwatch = Stopwatch()..start();
        final results = await uploadManager.uploadFiles(
          items,
          PortablePath.fromString('/dest'),
          PortablePath.fromString(tempDir.path),
          concurrency: concurrency,
        );
        stopwatch.stop();

        await tempDir.delete(recursive: true);
        expect(results.successCount, totalFiles);
        return stopwatch.elapsed;
      }

      final sequentialElapsed = await runAndTime(1);
      final concurrentElapsed = await runAndTime(concurrency);

      // ignore: avoid_print
      print(
        'upload_manager benchmark: $totalFiles files, '
        '${perUploadLatency.inMilliseconds}ms/upload -> '
        'sequential=${sequentialElapsed.inMilliseconds}ms, '
        'concurrency=$concurrency=${concurrentElapsed.inMilliseconds}ms '
        '(${(sequentialElapsed.inMicroseconds / concurrentElapsed.inMicroseconds).toStringAsFixed(2)}x speedup)',
      );

      // Theoretical speedup is ~5x. Assert a conservative 2x to keep this
      // reliable under CI scheduling jitter while still proving real
      // concurrency is happening (the old sequential code would show
      // ~1.0x, well under this bound).
      expect(
        concurrentElapsed.inMicroseconds,
        lessThan(sequentialElapsed.inMicroseconds ~/ 2),
        reason:
            'concurrent uploads should be substantially faster than '
            'sequential ones; got sequential=$sequentialElapsed '
            'concurrent=$concurrentElapsed',
      );
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
