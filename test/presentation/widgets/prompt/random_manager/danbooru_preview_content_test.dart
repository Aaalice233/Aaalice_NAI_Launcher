import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/danbooru_preview_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/danbooru_preview_content.dart';

void main() {
  const groupTitle = 'tag_group:hair_color';

  for (final fontSize in [11.0, 15.0]) {
    testWidgets('预览里的标签 chip 字号取自主题 labelSmall=$fontSize', (tester) async {
      final base = ThemeData();
      final theme = base.copyWith(
        textTheme: base.textTheme.copyWith(
          labelSmall: base.textTheme.labelSmall!.copyWith(fontSize: fontSize),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagGroupPreviewProvider(groupTitle).overrideWith(
              (ref) => const TagGroupPreview(
                tagCount: 2,
                topTags: ['blonde_hair', 'red_hair'],
                title: groupTitle,
              ),
            ),
            tagTranslationLookupProvider.overrideWithValue(
              TagTranslationLookup.fromResolver((_) async => const {}),
            ),
          ],
          child: MaterialApp(
            theme: theme,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: TagGroupPreviewContent(groupTitle: groupTitle),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final tag in ['blonde_hair', 'red_hair']) {
        final style = tester
            .widget<Text>(find.byKey(ValueKey('translated-tag-$tag')))
            .style;
        expect(style?.fontSize, fontSize, reason: tag);
        expect(style?.color, theme.colorScheme.onSurface, reason: tag);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
