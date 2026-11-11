import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/private_data_guard.dart';

void main() {
  group('absolutePathStarts', () {
    final cases = <(String, List<int>)>[
      (r'C:\a.png', [0]),
      (r'file=C:\Users\A B\a.png', [5]),
      (r'"C:\a.png"', [1]),
      (r'\\host\share\a.png', [0]),
      (r'file=\\host\share\a.png', [5]),
      (r'\\\host\share\a.png', [1]),
      ('//host/share/a.png', [0]),
      ('file=//host/share/a.png', [5]),
      ('/home/A B/a.png', [0]),
      ('file=/home/A B/a.png', [5]),
      (r'"C:\a.png" to "D:\b.png"', [1, 15]),
      ('"/home/a" to "//host/share/b"', [1, 14]),
    ];
    for (final (line, expected) in cases) {
      test('finds path starts in $line', () {
        expect(PrivateDataGuard.absolutePathStarts(line), expected);
      });
    }

    for (final uri in [
      'file:///C:/Users/A B/a.png',
      'file://localhost/C:/Users/A B/a.png',
      'file://host/share/a.png',
    ]) {
      test('finds the start of $uri and a separate path after it', () {
        const nextPath = '/home/A B/b.png';
        final line = '"$uri" to "$nextPath"';
        expect(
          PrivateDataGuard.absolutePathStarts(line),
          containsAll([1, line.indexOf(nextPath)]),
        );
      });
    }

    for (final line in [
      'http://host/a',
      'https://host/Users/x',
      'GET /users.json 404',
      'package:lib/a.dart',
      'dart:io',
      '12:30',
      'C:',
    ]) {
      test('does not treat $line as an absolute path', () {
        expect(PrivateDataGuard.absolutePathStarts(line), isEmpty);
      });
    }
  });
}
