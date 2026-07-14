import 'package:flutter_test/flutter_test.dart';
import 'package:letso/data.dart';

void main() {
  group('PortablePath Immutability & Equatable tests', () {
    test('Constructing from string parses components correctly', () {
      final absolute = PortablePath.fromString('/foo/bar');
      expect(absolute.toString(), '/foo/bar');
      expect(absolute.length, 3);
      expect(absolute.getAncestor(0), '/');
      expect(absolute.getAncestor(1), 'foo');
      expect(absolute.getAncestor(2), 'bar');

      final relative = PortablePath.fromString('foo/bar');
      expect(relative.toString(), 'foo/bar');
      expect(relative.length, 2);
      expect(relative.getAncestor(0), 'foo');
      expect(relative.getAncestor(1), 'bar');
    });

    test('add() returns a new instance and does not mutate the original', () {
      const original = PortablePath(['/']);
      final added = original.add('foo');

      expect(original.toString(), '/');
      expect(added.toString(), '/foo');
      expect(original, isNot(added));
    });

    test('Equality holds for identically constructed paths', () {
      final path1 = PortablePath.fromString('/foo/bar');
      final path2 = PortablePath.fromString('/foo/bar');

      expect(path1, path2);
      expect(path1.hashCode, path2.hashCode);
    });

    test('subPath() returns a new instance and does not mutate the original', () {
      final original = PortablePath.fromString('/foo/bar/baz');
      final sub = original.subPath(2); // '/foo/bar'

      expect(original.toString(), '/foo/bar/baz');
      expect(sub.toString(), '/foo/bar');
      expect(original, isNot(sub));
    });
  });
}
