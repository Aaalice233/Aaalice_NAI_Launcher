import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/traditional_chinese_converter.dart';

void main() {
  test(
    'normalizes Traditional Chinese queries for the Simplified dictionary',
    () async {
      final converter = TraditionalChineseConverter(
        loadString: (_) =>
            File('assets/data/opencc/TSCharacters.txt').readAsString(),
      );

      expect(await converter.toSimplified('標籤與頭髮'), '标签与头发');
      expect(await converter.toSimplified('标签与头发'), '标签与头发');
    },
  );

  test('keeps non-Chinese tag syntax unchanged', () async {
    final converter = TraditionalChineseConverter(
      loadString: (_) async => '標\t标\n籤\t签\n',
    );

    expect(
      await converter.toSimplified('1girl, <lora:test>'),
      '1girl, <lora:test>',
    );
  });
}
