import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/services/alias_resolver_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_tooltips.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_tooltip_components.dart';

BoxDecoration _decoration(WidgetTester tester, Key key) {
  final container = tester.widget<Container>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(Container))
        .first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'prompt tooltip gradients match the original ${brightness.name} visuals',
      (tester) async {
        final theme = ThemeData(brightness: brightness);
        final isDark = brightness == Brightness.dark;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  TooltipHeader(
                    key: const ValueKey('header'),
                    theme: theme,
                    label: 'Positive',
                    icon: Icons.auto_awesome,
                    color: theme.colorScheme.primary,
                    isDark: isDark,
                  ),
                  TooltipFinalPromptSection(
                    key: const ValueKey('positive-final'),
                    theme: theme,
                    prompt: 'positive prompt',
                    isDark: isDark,
                    label: 'Final prompt',
                    color: theme.colorScheme.primary,
                    backgroundStartColor: theme.colorScheme.primaryContainer,
                    backgroundEndColor: theme.colorScheme.secondaryContainer,
                  ),
                  TooltipFinalPromptSection(
                    key: const ValueKey('negative-final'),
                    theme: theme,
                    prompt: 'negative prompt',
                    isDark: isDark,
                    label: 'Final negative',
                    color: theme.colorScheme.error,
                    backgroundStartColor: theme.colorScheme.errorContainer,
                    backgroundEndColor:
                        theme.colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
          ),
        );

        final headerDecoration = _decoration(tester, const ValueKey('header'));
        final headerGradient = headerDecoration.gradient! as LinearGradient;
        expect(headerDecoration.color, isNull);
        expect(headerDecoration.border, isNull);
        expect(headerDecoration.borderRadius, BorderRadius.circular(8));
        expect(headerGradient.begin, Alignment.centerLeft);
        expect(headerGradient.end, Alignment.centerRight);
        expect(headerGradient.colors, [
          theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
          theme.colorScheme.primary.withValues(alpha: isDark ? 0.1 : 0.05),
        ]);

        void expectFinalGradient(Key key, Color startColor, Color endColor) {
          final decoration = _decoration(tester, key);
          final gradient = decoration.gradient! as LinearGradient;
          expect(decoration.color, isNull);
          expect(decoration.border, isNull);
          expect(decoration.borderRadius, BorderRadius.circular(10));
          expect(gradient.begin, Alignment.topLeft);
          expect(gradient.end, Alignment.bottomRight);
          expect(gradient.colors, [
            startColor.withValues(alpha: isDark ? 0.3 : 0.4),
            endColor.withValues(alpha: isDark ? 0.2 : 0.3),
          ]);
        }

        expectFinalGradient(
          const ValueKey('positive-final'),
          theme.colorScheme.primaryContainer,
          theme.colorScheme.secondaryContainer,
        );
        expectFinalGradient(
          const ValueKey('negative-final'),
          theme.colorScheme.errorContainer,
          theme.colorScheme.surfaceContainerHighest,
        );
      },
    );
  }

  for (final locale in const [Locale('zh'), Locale('en'), Locale('ja')]) {
    testWidgets(
      'final prompt title and copy stay in one row for ${locale.languageCode}',
      (tester) async {
        var copyCount = 0;
        late String label;

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) {
                label = AppLocalizations.of(context)!.prompt_finalPrompt;
                final theme = Theme.of(context);
                return Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 320,
                      child: TooltipFinalPromptSection(
                        key: const ValueKey('localized-final'),
                        theme: theme,
                        prompt: 'effective prompt',
                        isDark: false,
                        label: label,
                        color: theme.colorScheme.primary,
                        backgroundStartColor:
                            theme.colorScheme.primaryContainer,
                        backgroundEndColor:
                            theme.colorScheme.secondaryContainer,
                        onCopy: () => copyCount++,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final section = find.byKey(const ValueKey('localized-final'));
        final title = find.descendant(of: section, matching: find.text(label));
        final copy = find.descendant(
          of: section,
          matching: find.byIcon(Icons.copy_rounded),
        );
        expect(title, findsOneWidget);
        expect(copy, findsOneWidget);
        expect(
          find.descendant(of: section, matching: find.byType(Stack)),
          findsNothing,
        );
        expect(
          find.descendant(of: section, matching: find.byType(Spacer)),
          findsOneWidget,
        );
        expect(
          tester.getRect(title).right,
          lessThanOrEqualTo(tester.getRect(copy).left),
        );
        final copyTarget = find
            .ancestor(of: copy, matching: find.byType(MouseRegion))
            .first;
        expect(
          tester.getRect(copyTarget).right,
          tester.getRect(section).right - 10,
        );

        final copyTooltip = tester.widget<Tooltip>(
          find.ancestor(of: copy, matching: find.byType(Tooltip)),
        );
        expect(
          copyTooltip.message,
          AppLocalizations.of(tester.element(copy))!.tooltip_copy,
        );

        await tester.tap(copy);
        await tester.pump();
        expect(copyCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('long final prompt title does not overlap copy at text scale', (
    tester,
  ) async {
    final theme = ThemeData.light();
    const longTitle =
        'Final effective prompt title that is deliberately much longer than translations';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: TooltipFinalPromptSection(
              theme: theme,
              prompt: 'effective prompt',
              isDark: false,
              label: longTitle,
              color: theme.colorScheme.primary,
              backgroundStartColor: theme.colorScheme.primaryContainer,
              backgroundEndColor: theme.colorScheme.secondaryContainer,
              onCopy: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final title = find.text(longTitle);
    final copy = find.byIcon(Icons.copy_rounded);
    expect(
      tester.getRect(title).right,
      lessThanOrEqualTo(tester.getRect(copy).left),
    );
  });

  testWidgets('positive and negative tooltips expose copy callbacks', (
    tester,
  ) async {
    var positiveCopies = 0;
    var negativeCopies = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              final theme = Theme.of(context);
              final l10n = AppLocalizations.of(context)!;
              final aliasResolver = ref.read(
                aliasResolverServiceProvider.notifier,
              );
              return Scaffold(
                body: SizedBox(
                  width: 420,
                  child: Column(
                    children: [
                      PositivePromptTooltip(
                        theme: theme,
                        userPrompt: 'positive effective prompt',
                        prefixes: const [],
                        suffixes: const [],
                        qualityContent: null,
                        characters: const [],
                        globalAiChoice: true,
                        l10n: l10n,
                        aliasResolver: aliasResolver,
                        onCopy: () => positiveCopies++,
                      ),
                      NegativePromptTooltip(
                        theme: theme,
                        userNegativePrompt: 'negative effective prompt',
                        prefixes: const [],
                        suffixes: const [],
                        ucPresetContent: '',
                        l10n: l10n,
                        aliasResolver: aliasResolver,
                        onCopy: () => negativeCopies++,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (final section in find.byType(TooltipFinalPromptSection).evaluate()) {
      expect(section.findAncestorWidgetOfExactType<Stack>(), isNull);
    }
    final copyButtons = find.byIcon(Icons.copy_rounded);
    expect(copyButtons, findsNWidgets(2));

    await tester.tap(copyButtons.at(0));
    await tester.tap(copyButtons.at(1));
    await tester.pump();

    expect(positiveCopies, 1);
    expect(negativeCopies, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'character tooltip keeps one styled row and gender icon per role',
    (tester) async {
      final theme = ThemeData.light();
      const characters = [
        CharacterPrompt(
          id: 'female',
          name: 'Alice',
          gender: CharacterGender.female,
          prompt: 'red hair',
        ),
        CharacterPrompt(
          id: 'male',
          name: 'Bob',
          gender: CharacterGender.male,
          prompt: 'black hair',
        ),
        CharacterPrompt(
          id: 'other',
          name: 'Figure',
          gender: CharacterGender.other,
          prompt: 'silhouette',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: TooltipCharacterSection(
              theme: theme,
              label: 'Characters',
              characters: characters,
              globalAiChoice: true,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.people_rounded), findsOneWidget);
      expect(find.byIcon(Icons.female), findsOneWidget);
      expect(find.byIcon(Icons.male), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Alice: [1girl, red hair]'), findsOneWidget);
      expect(find.text('Bob: [1boy, black hair]'), findsOneWidget);
      expect(find.text('Figure: [silhouette]'), findsOneWidget);

      for (final icon in [Icons.female, Icons.male, Icons.person]) {
        final iconWidget = tester.widget<Icon>(find.byIcon(icon));
        expect(iconWidget.size, 11);
        expect(
          iconWidget.color,
          theme.colorScheme.onSurface.withValues(alpha: 0.5),
        );
        final padding = tester.widget<Padding>(
          find
              .ancestor(of: find.byIcon(icon), matching: find.byType(Padding))
              .first,
        );
        expect(padding.padding, const EdgeInsets.only(bottom: 4));
      }
    },
  );
}
