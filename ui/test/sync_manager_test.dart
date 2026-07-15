import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:letso/platform/native/sync_manager.dart';

void main() {
  group('getFileStatsForTesting', () {
    late io.Directory tempDir;

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('visits each file and directory exactly once', () async {
      tempDir = await io.Directory.systemTemp.createTemp('sync_manager_test');
      // tempDir/
      //   a.txt
      //   sub/
      //     b.txt
      //     nested/
      //       c.txt
      await io.File('${tempDir.path}/a.txt').writeAsString('a');
      final sub = io.Directory('${tempDir.path}/sub')..createSync();
      await io.File('${sub.path}/b.txt').writeAsString('b');
      final nested = io.Directory('${sub.path}/nested')..createSync();
      await io.File('${nested.path}/c.txt').writeAsString('c');

      final stats = await getFileStatsForTesting(tempDir.path);

      final dirName =
          tempDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      expect(stats.keys.toSet(), {
        '$dirName/a.txt',
        '$dirName/sub',
        '$dirName/sub/b.txt',
        '$dirName/sub/nested',
        '$dirName/sub/nested/c.txt',
      });
    });

    test(
      'does not blow up processing deeply nested directories '
      '(regression: dir.list(recursive: true) was also being manually '
      're-recursed into for every subdirectory, causing exponential '
      're-processing of nested entries)',
      () async {
        tempDir = await io.Directory.systemTemp.createTemp(
          'sync_manager_test',
        );

        // Build a linear chain of nested directories: d0/d1/.../d17, each
        // containing one file. With the double-recursion bug this explodes
        // combinatorially (processDirectory is invoked again for every
        // subdirectory encountered by an already-recursive listing), so the
        // buggy version would take vastly longer than this test's timeout.
        // The fixed version is a single linear traversal and finishes almost
        // instantly regardless of depth.
        const depth = 18;
        var current = tempDir;
        for (var i = 0; i < depth; i++) {
          current = io.Directory('${current.path}/d$i')..createSync();
          await io.File('${current.path}/f$i.txt').writeAsString('$i');
        }

        final stats = await getFileStatsForTesting(tempDir.path);

        // depth directories + depth files.
        expect(stats.length, depth * 2);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });
}
