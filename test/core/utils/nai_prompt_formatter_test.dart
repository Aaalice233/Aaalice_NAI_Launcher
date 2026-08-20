import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/nai_prompt_formatter.dart';

void main() {
  group('NaiPromptFormatter.format', () {
    test('格式化标签时保留换行、空行和行首缩进', () {
      const prompt = 'quality   tags， best quality,\n\n  blue hair, red eyes';

      expect(
        NaiPromptFormatter.format(prompt),
        'quality_tags, best_quality,\n\n  blue_hair, red_eyes',
      );
    });

    test('保留 CRLF 与各分组行末逗号', () {
      const prompt = 'subject tag,\r\nclothing tag,\r\nbackground tag';

      expect(
        NaiPromptFormatter.format(prompt),
        'subject_tag,\r\nclothing_tag,\r\nbackground_tag',
      );
    });

    test('纯空白分隔行保持原样', () {
      const prompt = 'first tag\n  \nsecond tag';

      expect(NaiPromptFormatter.format(prompt), 'first_tag\n  \nsecond_tag');
    });
  });
}
