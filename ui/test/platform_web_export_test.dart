// Regression test for bug #1 in docs/bugs_and_performance_report.md.
//
// The bug: ui/lib/platform/web.dart (selected for web builds via the
// dart.library.html conditional import in platform.dart) exported
// 'native/sync_manager.dart' instead of 'web/sync_manager.dart'. The native
// implementation uses dart:io (io.Directory, io.File) and compute(), neither
// of which is available on web, so this either fails to compile or throws
// UnsupportedError at runtime on web.
//
// This can't be exercised by compiling for web from `flutter test` (which
// runs on the Dart VM, where dart:io is available), so instead this test
// statically verifies the wiring: platform/web.dart must export a
// sync_manager implementation that does not depend on dart:io.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'platform/web.dart exports the web (non-dart:io) sync_manager, not the native one',
    () {
      final platformDir = p.join('lib', 'platform');
      final webDartFile = File(p.join(platformDir, 'web.dart'));
      final source = webDartFile.readAsStringSync();

      final exportPattern = RegExp(
        r'''export\s+['"]([^'"]*sync_manager\.dart)['"]''',
      );
      final match = exportPattern.firstMatch(source);
      expect(
        match,
        isNotNull,
        reason: 'platform/web.dart should export a sync_manager.dart file',
      );

      final exportedPath = match!.group(1)!;
      expect(
        exportedPath,
        isNot(contains('native/')),
        reason:
            'platform/web.dart must not export the native sync_manager, '
            'which relies on dart:io and is unavailable on web',
      );

      // Resolve the exported file relative to platform/ and confirm it is
      // genuinely web-safe (no dart:io dependency), rather than just
      // trusting the path string.
      final resolvedFile = File(p.join(platformDir, exportedPath));
      expect(
        resolvedFile.existsSync(),
        isTrue,
        reason: 'Exported file $exportedPath does not exist',
      );
      final exportedSource = resolvedFile.readAsStringSync();
      expect(
        exportedSource,
        isNot(contains("dart:io")),
        reason:
            'The sync_manager exported for web builds must not import '
            'dart:io',
      );
    },
  );
}
