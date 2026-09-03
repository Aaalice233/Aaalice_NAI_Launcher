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
}
