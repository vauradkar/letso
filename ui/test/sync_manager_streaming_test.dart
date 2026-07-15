// Regression test for finding #13 in docs/bugs_and_performance_report.md
// ("Delta-exchange SSE response is buffered in full before any parsing").
//
// The bug: SyncManager._startStreaming() accumulated every byte of the
// exchange_deltas SSE response into a single `List<int>` before decoding
// and splitting it into events, despite a comment claiming chunks were
// processed as they arrived. For a large synced tree this meant elevated
// peak memory (raw bytes + decoded string + split array all held at once)
// and no incremental progress until the entire response had arrived.
//
// This project has no dedicated performance-benchmark harness (no
// benchmark_harness / integration_test perf tooling is set up), and a
// wall-clock timing assertion would be flaky and wouldn't actually
// distinguish the buffered implementation from the streaming one — both
// are O(n) in the number of bytes, the difference is peak memory and
// responsiveness, not CPU time. So, following this repo's existing
// convention for perf-flavored regressions (see the "does not blow up
// processing deeply nested directories" test in sync_manager_test.dart,
// which uses a bounded Timeout rather than a benchmark), the most direct
// and non-flaky way to prove the fix is a deterministic behavioral test:
// parsed events must become observable *before* the underlying stream
// finishes, proving events are handled as their chunk arrives rather than
// only after the whole response has been buffered.
//
// The fix: parse SSE events incrementally, buffering only up to the next
// "\n\n" boundary as chunks arrive.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:letso/api.dart';
import 'package:letso/data.dart';
import 'package:letso/platform/native/sync_manager.dart';
import 'package:letso/upload_manager.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements Api {}

void main() {
  late MockApi mockApi;
  late SyncManager syncManager;

  setUpAll(() {
    registerFallbackValue(
      DeltaRequest(dest: const PortablePath(["/"]), deltas: const []),
    );
  });

  setUp(() {
    mockApi = MockApi();
    syncManager = SyncManager(
      api: mockApi,
      uploadManager: UploadManager(api: mockApi),
    );
  });

  test(
    'SSE events are parsed as their chunk arrives, before the response '
    'stream completes',
    () async {
      final controller = StreamController<List<int>>();
      when(
        () => mockApi.exchangeDeltas(any()),
      ).thenAnswer((_) async => http.StreamedResponse(controller.stream, 200));

      final firstItem = SyncItem(
        path: PortablePath.fromString('/home/user/docs/first.txt'),
        stats: const FileStat(
          size: 1,
          mtime: '2026-01-01T00:00:00Z',
          isDirectory: false,
          sha256: 'a',
        ),
      );
      final secondItem = SyncItem(
        path: PortablePath.fromString('/home/user/docs/second.txt'),
        stats: const FileStat(
          size: 2,
          mtime: '2026-01-01T00:00:00Z',
          isDirectory: false,
          sha256: 'b',
        ),
      );

      final receivedBatches = <Map<String, SyncItem>>[];
      final resultFuture = syncManager.startStreamingForTesting(
        SyncPath(
          src: PortablePath.fromString('/home/user/docs'),
          dest: PortablePath.fromString('/remote'),
        ),
        onEvent: receivedBatches.add,
      );

      // Deliver only the first event, terminated by the SSE boundary, and
      // deliberately leave the stream open — simulating more data still in
      // flight from the server.
      controller.add(
        utf8.encode('data: ${jsonEncode(firstItem.toJson())}\n\n'),
      );
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      // Before the stream finishes, the first event must already have been
      // parsed and delivered. With the original buffering implementation
      // this list would still be empty here, since nothing is parsed until
      // the entire response has been accumulated.
      expect(receivedBatches, hasLength(1));
      expect(receivedBatches.single.keys, contains(firstItem.path.toString()));

      // Now deliver the second event and close the stream.
      controller.add(
        utf8.encode('data: ${jsonEncode(secondItem.toJson())}\n\n'),
      );
      await controller.close();

      final result = await resultFuture;
      expect(receivedBatches, hasLength(2));
      expect(
        result.keys,
        containsAll([firstItem.path.toString(), secondItem.path.toString()]),
      );
    },
  );
}
