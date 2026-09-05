import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/quality_preset_provider.dart';
import 'package:nai_launcher/presentation/providers/uc_preset_provider.dart';
import 'package:nai_launcher/presentation/themes/prompt_semantic_colors.dart';
import 'package:nai_launcher/presentation/widgets/common/translated_tag_text.dart';
import 'package:nai_launcher/presentation/widgets/prompt/quality_tags_selector.dart';
import 'package:nai_launcher/presentation/widgets/prompt/uc_preset_selector.dart';

void main() {
  testWidgets('正负质量词悬浮预览使用正文排版并显示快速翻译', (tester) async {
    final lookup = TagTranslationLookup.fromResolver((tags) async {
      const translations = {'very_aesthetic': '非常唯美', 'lowres': '低分辨率'};
      return {
        for (final tag in tags)
          if (translations[tag] != null) tag: translations[tag]!,
      };
    });
    final theme = ThemeData.dark();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagTranslationLookupProvider.overrideWithValue(lookup),
          qualityPresetNotifierProvider.overrideWith(
            _TestQualityPresetNotifier.new,
          ),
          qualityCustomEntriesProvider.overrideWith((ref) => const []),
          ucPresetNotifierProvider.overrideWith(_TestUcPresetNotifier.new),
          ucCustomEntriesProvider.overrideWith((ref) => const []),
          currentUcEntryProvider.overrideWith((ref) => null),
        ],
        child: MaterialApp(
          theme: theme,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                QualityTagsSelector(model: ImageModels.animeDiffusionV45Full),
                UcPresetSelector(model: ImageModels.animeDiffusionV45Full),
              ],
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);

    await mouse.moveTo(tester.getCenter(find.byType(QualityTagsSelector)));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    var preview = tester.widget<TranslatedPromptText>(
      find.byType(TranslatedPromptText),
    );
    final resolvedBodyFontSize = Theme.of(
      tester.element(find.byType(QualityTagsSelector)),
    ).textTheme.bodyMedium?.fontSize;
    expect(preview.style?.fontSize, resolvedBodyFontSize);
    expect(preview.style?.color, theme.promptSemanticColors.positiveQuality);
    expect(find.text('非常唯美'), findsOneWidget);

    await mouse.moveTo(tester.getCenter(find.byType(UcPresetSelector)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    preview = tester.widget<TranslatedPromptText>(
      find.byType(TranslatedPromptText),
    );
    expect(preview.style?.fontSize, resolvedBodyFontSize);
    expect(find.text('低分辨率'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestQualityPresetNotifier extends QualityPresetNotifier {
  @override
  QualityPresetState build() => const QualityPresetState();
}

class _TestUcPresetNotifier extends UcPresetNotifier {
  @override
  UcPresetState build() => const UcPresetState();
}
