import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/watermark/watermark_font_catalog.dart';

void main() {
  test('curated fonts and their redistributable licenses are bundled', () {
    expect(
      WatermarkFontCatalog.options.where((font) => font.supportsCjk).length,
      greaterThanOrEqualTo(3),
    );
    expect(
      WatermarkFontCatalog.options.where((font) => !font.supportsCjk).length,
      greaterThanOrEqualTo(3),
    );

    for (final fileName in const [
      'Allura-Regular.ttf',
      'Caveat-VariableFont_wght.ttf',
      'GreatVibes-Regular.ttf',
      'LongCang-Regular.ttf',
      'MaShanZheng-Regular.ttf',
      'ZhiMangXing-Regular.ttf',
    ]) {
      final bytes = File('fonts/watermark/$fileName').readAsBytesSync();
      expect(bytes.length, greaterThan(10000), reason: fileName);
      expect(
        String.fromCharCodes(bytes.take(4)),
        anyOf('\u0000\u0001\u0000\u0000', 'OTTO'),
        reason: fileName,
      );
    }

    for (final directory in const [
      'allura',
      'caveat',
      'great-vibes',
      'long-cang',
      'lxgw-zhenkai',
      'ma-shan-zheng',
      'zhi-mang-xing',
    ]) {
      final license = File('licenses/fonts/$directory/OFL.txt');
      final source = File('licenses/fonts/$directory/upstream_info.md');
      expect(license.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
      expect(source.readAsStringSync(), contains('https://'));
    }
  });
}
