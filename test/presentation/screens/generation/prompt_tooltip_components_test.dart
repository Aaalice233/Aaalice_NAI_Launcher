import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/services/alias_resolver_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_tooltips.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_tooltip_components.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'prompt tooltip uses one quiet result surface in ${brightness.name}',
      (tester) async {
        final theme = ThemeData(brightness: brightness);
        final isDark = brightness == Brightness.dark;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: Column(
                  children: [
                    TooltipHeader(
                      key: const ValueKey('header'),
                      theme: theme,
                      label: 'Positive',
                      icon: Icons.auto_awesome,
                      color: theme.colorScheme.primary,
                      isDark: isDark,
                    ),
                    TooltipSection(
                      key: const ValueKey('step'),
                      theme: theme,
                      icon: Icons.push_pin,
                      label: 'Fixed tags',
                      color: theme.colorScheme.secondary,
                      content: 'best quality, detailed',
                      isDark: isDark,
                    ),
                    TooltipFinalPromptSection(
                      key: const ValueKey('result'),
                      theme: theme,
                      prompt: 'positive prompt',
                      isDark: isDark,
                      label: 'Final prompt',
                      color: theme.colorScheme.primary,
                      backgroundStartColor: theme.colorScheme.primaryContainer,
                      backgroundEndColor: theme.colorScheme.secondaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('header')),
            matching: find.byType(DecoratedBox),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('step')),
            matching: find.byType(DecoratedBox),
          ),
          findsNothing,
        );
        final resultContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(const ValueKey('result')),
                matching: find.byType(Container),
              )
              .first,
        );
        final resultDecoration = resultContainer.decoration! as BoxDecoration;
        expect(resultDecoration.color, isNotNull);
        expect(resultDecoration.gradient, isNull);
        expect(resultDecoration.border, isNull);
        expect(resultDecoration.borderRadius, BorderRadius.circular(8));
        expect(tester.takeException(), isNull);
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
          tester.getRect(title).right,
          lessThanOrEqualTo(tester.getRect(copy).left),
        );
        final copyTarget = find
            .ancestor(of: copy, matching: find.byType(IconButton))
            .first;
        expect(tester.getSize(copyTarget), const Size(40, 40));
        expect(
          tester.getRect(copyTarget).right,
          tester.getRect(section).right - 8,
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

  testWidgets('fixed-tag composition stays readable at 320 and 3x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TooltipHeader(
                    theme: theme,
                    label: '正向提示词完整组合预览',
                    icon: Icons.auto_awesome,
                    color: theme.colorScheme.primary,
                    isDark: true,
                  ),
                  TooltipSection(
                    theme: theme,
                    icon: Icons.push_pin,
                    label: '固定词前缀与质量词',
                    color: theme.colorScheme.secondary,
                    content: List.filled(12, 'highly detailed').join(', '),
                    isDark: true,
                  ),
                  TooltipFinalPromptSection(
                    theme: theme,
                    prompt: List.filled(16, 'effective tag').join(', '),
                    isDark: true,
                    label: '最终生效的完整正向提示词',
                    color: theme.colorScheme.primary,
                    backgroundStartColor: theme.colorScheme.primaryContainer,
                    backgroundEndColor: theme.colorScheme.secondaryContainer,
                    onCopy: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('固定词前缀与质量词'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(
      tester.getRect(find.byIcon(Icons.copy_rounded)).right,
      lessThanOrEqualTo(320),
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
        expect(iconWidget.size, 14);
        expect(iconWidget.color, theme.colorScheme.onSurfaceVariant);
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
