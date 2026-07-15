import 'package:flutter_test/flutter_test.dart';
import 'package:letso/file_browser.dart';

void main() {
  group('formatTime', () {
    test('formats dates outside today/yesterday as yyyy-MM-dd, not yyyy-mm-dd', () {
      // Regression test: DateFormat pattern 'mm' means minutes, not months
      // ('MM'), so March 15 at 09:45 used to render as "2025-45-15".
      final result = formatTime('2025-03-15T09:45:00');

      expect(result, '2025-03-15 - 09:45');
    });
  });
}
