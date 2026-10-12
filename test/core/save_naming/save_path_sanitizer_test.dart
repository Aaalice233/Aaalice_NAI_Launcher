import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/save_naming/save_path_sanitizer.dart';

void main() {
  group('segment', () {
    test('replaces characters no platform accepts in a file name', () {
      expect(
        SavePathSanitizer.segment('a:b*c?"d<e>f|g/h\\i%j\nk\u0001l\u007f'),
        'a_b_c__d_e_f_g_h_i_j_k_l_',
      );
    });

    test('drops trailing dots and spaces and leaves dot-only names empty', () {
      expect(SavePathSanitizer.segment('  name. . '), 'name');
      expect(SavePathSanitizer.segment('..'), '');
      expect(SavePathSanitizer.segment('.'), '');
    });

    test('prefixes Windows device names', () {
      expect(SavePathSanitizer.segment('CON'), '_CON');
      expect(SavePathSanitizer.segment('nul.tar'), '_nul.tar');
      expect(SavePathSanitizer.segment('com1'), '_com1');
      expect(SavePathSanitizer.segment('LPT¹'), '_LPT¹');
      expect(SavePathSanitizer.segment('console'), 'console');
    });

    test('keeps at most 180 code points', () {
      final result = SavePathSanitizer.segment('a' * 300);
      expect(result.length, 180);
    });

    test('keeps CJK names within the 255-byte file system limit', () {
      final result = SavePathSanitizer.segment('字' * 180);
      expect(utf8.encode(result).length, lessThanOrEqualTo(240));
      expect(result, '字' * 80);
    });

    test('shortens only the part before a protected suffix', () {
      final result = SavePathSanitizer.segment(
        '${'b' * 200}_redacted',
        protectedSuffix: '_redacted',
      );
      expect(result, '${'b' * 171}_redacted');
      expect(
        SavePathSanitizer.segment('_redacted', protectedSuffix: '_redacted'),
        '',
      );
    });

    test('never splits an emoji cluster', () {
      const family = '👨‍👩‍👧‍👦';
      final result = SavePathSanitizer.segment(family * 40);
      expect(result.length % family.length, 0);
      expect(utf8.encode(result).length, lessThanOrEqualTo(240));
    });
  });

  group('fitLength', () {
    test('shortens the base and keeps the protected suffix', () {
      final fitted = SavePathSanitizer.fitLength(
        '${'b' * 100}_redacted',
        30,
        protectedSuffix: '_redacted',
      );
      expect(fitted, '${'b' * 21}_redacted');
    });

    test('leaves names that already fit untouched', () {
      expect(SavePathSanitizer.fitLength('short', 30), 'short');
    });

    test('keeps the original when only the suffix would remain', () {
      expect(
        SavePathSanitizer.fitLength(
          'abc_redacted',
          5,
          protectedSuffix: '_redacted',
        ),
        'abc_redacted',
      );
    });
  });
}
