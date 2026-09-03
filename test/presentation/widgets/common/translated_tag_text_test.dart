import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/presentation/widgets/common/translated_tag_text.dart';

void main() {
  final lookup = TagTranslationLookup.fromResolver((tags) async {
    const translations = {
      'blonde_hair': '金发',
      'blue_eyes': '蓝眼睛',
      'solo': '单人',
    };
    return {
      for (final tag in tags)
        if (translations[tag] != null) tag: translations[tag]!,
    };
  });

  testWidgets('单标签保留原文并追加汉化', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tagTranslationLookupProvider.overrideWithValue(lookup)],
        child: const MaterialApp(
          home: Scaffold(body: TranslatedTagText('blonde_hair')),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('blonde hair'), findsOneWidget);
    expect(find.textContaining('金发'), findsOneWidget);
  });

  testWidgets('提示词批量汉化并保持权重原文', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tagTranslationLookupProvider.overrideWithValue(lookup)],
        child: const MaterialApp(
          home: Scaffold(
            body: TranslatedPromptText('solo, 1.2::blonde hair::, blue eyes'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('solo, 1.2::blonde hair::, blue eyes'), findsOneWidget);
    expect(find.text('单人，金发，蓝眼睛'), findsOneWidget);
  });

  testWidgets('完整翻译模式为词典缺失项保留原标签', (tester) async {
    final partialLookup = TagTranslationLookup.fromResolver((tags) async {
      return {if (tags.contains('solo')) 'solo': '单人'};
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagTranslationLookupProvider.overrideWithValue(partialLookup),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TranslatedPromptText(
              'solo, unknown_artist, very_aesthetic',
              includeUntranslated: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('单人，unknown artist，very aesthetic'), findsOneWidget);
  });

  testWidgets('完整翻译模式不会丢弃加权艺术家与未收录标签', (tester) async {
    final partialLookup = TagTranslationLookup.fromResolver((tags) async {
      return {
        if (tags.contains('best_quality')) 'best_quality': '极高分辨率',
        if (tags.contains('masterpiece')) 'masterpiece': '杰作',
      };
    });
    const prompt =
        '1.60::asahina_yoshitoshi::, yutokamizu, '
        '0.7::artist:hermityy::, year_2025, best_quality, masterpiece';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagTranslationLookupProvider.overrideWithValue(partialLookup),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TranslatedPromptText(prompt, includeUntranslated: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'asahina yoshitoshi，yutokamizu，artist:hermityy，year 2025，'
        '极高分辨率，杰作',
      ),
      findsOneWidget,
    );
  });
}
