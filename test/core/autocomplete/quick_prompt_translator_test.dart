import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';

void main() {
  final lookup = TagTranslationLookup.fromResolver((tags) async {
    const values = {'best_quality': '极高质量', 'blue_eyes': '蓝眼睛', 'solo': '单人'};
    return {
      for (final tag in tags)
        if (values[tag] != null) tag: values[tag]!,
    };
  });

  test('词库查询只移除成对外层强调，不破坏标签内的括号', () {
    expect(TagTranslationLookup.normalizeTag('{{blue_eyes}}'), 'blue_eyes');
    expect(
      TagTranslationLookup.normalizeTag('blender (medium)'),
      'blender_(medium)',
    );
    expect(
      TagTranslationLookup.normalizeTag('artist:rido*(ridograph)'),
      'artist:rido*(ridograph)',
    );
  });

  test('仅替换词库命中的标签并保留权重、强调与分隔格式', () async {
    const source =
        '1.20::best_quality::, unknown_artist, {{blue_eyes}}，\n  solo';

    final result = await lookup.translateTagText(source);

    expect(result.text, '1.20::极高质量::, unknown_artist, {{蓝眼睛}}，\n  单人');
    expect(result.translatedTagCount, 3);
    expect(result.hasTranslations, isTrue);
  });

  test('没有匹配项时完整保留原始文本', () async {
    const source = 'artist:someone, <library_alias>\nfree form sentence';

    final result = await lookup.translateTagText(source);

    expect(result.text, source);
    expect(result.translatedTagCount, 0);
    expect(result.hasTranslations, isFalse);
  });

  test('翻译跨逗号权重组、强调组和转义标签且完整保留语法', () async {
    const source =
        r'ultra\_complexity, year\_2026, year\_2024, '
        r'year\_2025, 20::best\_quality::, 30::very\_aesthetic::, '
        r'2::amazing\_quality, masterpiece, ultra-detailed, absurdres::, '
        r'1.2::*digital\_illustration::, -2::simple\_illustration::, '
        r'artist:sweetonedollar, artist:modare, artist:mx2j, '
        r'artist:shycocoa, artist:1=2, artist:bacheally, artist:kanzarin, '
        r'artist:wlop, artist:rido*(ridograph), 6::loli::, 1.45::todder::, '
        r'1.40::artist:mx2j::, 1.3::blender (medium), 3d::, '
        r'1.3::realistic, photorealistic, photo (medium)::, '
        r'[[greasy\_skin]], {shiny\_skin, shiny, skindentation, curvy}, '
        r'detailed\_skin, 1.4::handmade, octane\_render, c4d::, '
        r'perfect\_rendering, realistic\_rendering, detailed\_textures, '
        r'steam, heavy\_breath, steaming\_body, fine\_fabric\_emphasis, '
        r'-3::unfinished\_small\_objects, chibi::, ultra\_complexity, '
        r'perfect\_rendering, realistic\_rendering, detailed\_textures, '
        r'intricate\_details, depth\_of\_field, '
        r'-3::oiled\_skin, shiny\_skin::, 3::realistic\_skin::';
    final complexLookup = TagTranslationLookup.fromResolver((tags) async {
      const values = {
        'ultra_complexity': '超高复杂度',
        'best_quality': '最佳质量',
        'very_aesthetic': '极具美感',
        'amazing_quality': '惊人质量',
        'masterpiece': '杰作',
        'absurdres': '超高分辨率',
        'digital_illustration': '数字插画',
        'blender_(medium)': 'Blender（媒介）',
        '3d': '3D',
        'realistic': '写实',
        'photorealistic': '照片级写实',
        'photo_(medium)': '照片（媒介）',
        'greasy_skin': '油腻皮肤',
        'shiny_skin': '光泽皮肤',
        'shiny': '闪亮',
        'skindentation': '皮肤压痕',
        'curvy': '曲线玲珑',
        'unfinished_small_objects': '未完成的小物件',
        'chibi': 'Q版',
        'oiled_skin': '油性皮肤',
        'realistic_skin': '写实皮肤',
      };
      return {
        for (final tag in tags)
          if (values[tag] != null) tag: values[tag]!,
      };
    });

    final result = await complexLookup.translateTagText(source);

    expect(result.text, startsWith('超高复杂度, year\\_2026'));
    expect(result.text, contains('20::最佳质量::'));
    expect(result.text, contains('2::惊人质量, 杰作, ultra-detailed, 超高分辨率::'));
    expect(result.text, contains('1.2::*数字插画::'));
    expect(result.text, contains('1.3::Blender（媒介）, 3D::'));
    expect(result.text, contains('1.3::写实, 照片级写实, 照片（媒介）::'));
    expect(result.text, contains('[[油腻皮肤]]'));
    expect(result.text, contains('{光泽皮肤, 闪亮, 皮肤压痕, 曲线玲珑}'));
    expect(result.text, contains('-3::未完成的小物件, Q版::'));
    expect(result.text, contains('-3::油性皮肤, 光泽皮肤::'));
    expect(result.text, contains('3::写实皮肤::'));
    expect(result.text, contains('artist:rido*(ridograph)'));
    expect(result.text, contains('1.40::artist:mx2j::'));
    expect(result.translatedTagCount, 23);
  });
}
