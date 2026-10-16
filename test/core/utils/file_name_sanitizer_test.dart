import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/file_name_sanitizer.dart';

void main() {
  group('segment', () {
    test('replaces characters no platform accepts in a file name', () {
      expect(
        FileNameSanitizer.segment('a:b*c?"d<e>f|g/h\\i%j\nk\u0001l\u007f'),
        'a_b_c__d_e_f_g_h_i_j_k_l_',
      );
    });

    test('drops trailing dots and spaces and falls back on dot-only names', () {
      expect(FileNameSanitizer.segment('  name. . '), 'name');
      expect(FileNameSanitizer.segment('..'), '');
      expect(FileNameSanitizer.segment('.', fallback: 'vibe'), 'vibe');
    });

    test('prefixes Windows device names', () {
      expect(FileNameSanitizer.segment('CON'), '_CON');
      expect(FileNameSanitizer.segment('nul.tar'), '_nul.tar');
      expect(FileNameSanitizer.segment('com1'), '_com1');
      expect(FileNameSanitizer.segment('LPT¹'), '_LPT¹');
      expect(FileNameSanitizer.segment('console'), 'console');
    });

    test('keeps at most the requested code points', () {
      expect(FileNameSanitizer.segment('a' * 300).length, 180);
      expect(FileNameSanitizer.segment('abcdef', maxCodePoints: 3), 'abc');
    });

    test('leaves room for an extension within the 255-byte limit', () {
      final result = FileNameSanitizer.segment('字' * 180);
      expect(result, '字' * 74);
      expect(utf8.encode(result).length, lessThanOrEqualTo(223));
    });

    test('shortens only the part before a protected suffix', () {
      expect(
        FileNameSanitizer.segment(
          '${'b' * 200}_redacted',
          protectedSuffix: '_redacted',
        ),
        '${'b' * 171}_redacted',
      );
      expect(
        FileNameSanitizer.segment('_redacted', protectedSuffix: '_redacted'),
        '',
      );
    });

    test('never splits an emoji cluster', () {
      const family = '👨‍👩‍👧‍👦';
      final result = FileNameSanitizer.segment(family * 40);
      expect(result.length % family.length, 0);
      expect(utf8.encode(result).length, lessThanOrEqualTo(223));
    });
  });

  group('fileName', () {
    test('keeps only the leaf and its extension', () {
      expect(
        FileNameSanitizer.fileName('dir/a:b?.png', fallback: 'image'),
        'a_b_.png',
      );
      expect(
        FileNameSanitizer.fileName('x/name. .png', fallback: 'image'),
        'name.png',
      );
      expect(FileNameSanitizer.fileName('.png', fallback: 'image'), '.png');
      expect(
        FileNameSanitizer.fileName('  .png', fallback: 'image'),
        'image.png',
      );
    });

    test('shortens the stem and lowercases the extension', () {
      final result = FileNameSanitizer.fileName(
        '${'猫' * 120}.PNG',
        fallback: 'image',
      );
      expect(result, '${'猫' * 73}.png');
      expect(
        FileNameSanitizer.fileName('a.${'b' * 300}', fallback: 'image').length,
        180,
      );
    });
  });

  group('fitLength', () {
    test('shortens the base and keeps the protected suffix', () {
      final fitted = FileNameSanitizer.fitLength(
        '${'b' * 100}_redacted',
        30,
        protectedSuffix: '_redacted',
      );
      expect(fitted, '${'b' * 21}_redacted');
    });

    test('leaves names that already fit untouched', () {
      expect(FileNameSanitizer.fitLength('short', 30), 'short');
    });

    test('keeps the original when only the suffix would remain', () {
      expect(
        FileNameSanitizer.fitLength(
          'abc_redacted',
          5,
          protectedSuffix: '_redacted',
        ),
        'abc_redacted',
      );
    });
  });
}
