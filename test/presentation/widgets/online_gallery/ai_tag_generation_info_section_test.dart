import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/ai_tag_generation_info.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/ai_tag_generation_info_section.dart';

void main() {
  test('NAI badge includes version without changing the raw model value', () {
    const rawModel = 'NovelAI Diffusion V5 657484A5';
    const info = AiTagGenerationInfo(
      model: rawModel,
      extra: {'Model ID': 'nai-diffusion-5-full'},
      prettyJson: '{}',
      rawJson: '{}',
    );

    expect(info.modelBadgeLabel(fallbackType: 'NAI'), 'NAI V5 Full');
    expect(info.model, rawModel);
  });

  testWidgets('raw JSON expands naturally without an inner scroll view', (
    tester,
  ) async {
    final rawJson = List.generate(
      20,
      (index) => '"line$index": $index',
    ).join('\n');
    final info = AiTagGenerationInfo(prettyJson: rawJson, rawJson: rawJson);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(body: AiTagRawJsonSection(info: info)),
      ),
    );

    final rawText = find.descendant(
      of: find.byType(AiTagRawJsonSection),
      matching: find.byType(SelectableText),
    );
    final collapsedText = tester.widget<SelectableText>(rawText);
    expect(collapsedText.maxLines, 14);
    expect(collapsedText.scrollPhysics, isA<NeverScrollableScrollPhysics>());
    expect(
      find.descendant(
        of: find.byType(AiTagRawJsonSection),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );

    await tester.tap(find.text('展开全文'));
    await tester.pump();

    expect(tester.widget<SelectableText>(rawText).maxLines, isNull);
  });
}
