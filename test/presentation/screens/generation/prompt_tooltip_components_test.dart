import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/services/alias_resolver_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_tooltips.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_tooltip_components.dart';
import 'package:nai_launcher/presentation/themes/prompt_semantic_colors.dart';
import 'package:nai_launcher/presentation/widgets/common/rich_tooltip_surface.dart';
import 'package:nai_launcher/presentation/widgets/common/translated_tag_text.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'prompt tooltip uses quiet cards without borders in ${brightness.name}',
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
        final stepContainer = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(const ValueKey('step')),
                matching: find.byType(Container),
              )
              .first,
        );
        final stepDecoration = stepContainer.decoration! as BoxDecoration;
        expect(stepDecoration.color, isNotNull);
        expect(stepDecoration.border, isNull);
        expect(stepDecoration.borderRadius, BorderRadius.circular(8));
        final stepInkWell = tester.widget<InkWell>(
          find.descendant(
            of: find.byKey(const ValueKey('step')),
            matching: find.byType(InkWell),
          ),
        );
        expect(stepInkWell.borderRadius, BorderRadius.circular(8));
        final stepPrompt = tester.widget<TranslatedPromptText>(
          find.descendant(
            of: find.byKey(const ValueKey('step')),
            matching: find.byType(TranslatedPromptText),
          ),
        );
        expect(stepPrompt.prompt, 'best quality, detailed');
        expect(stepPrompt.maxLines, 3);
        expect(stepPrompt.includeUntranslated, isTrue);
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

  testWidgets(
    'rich tooltip surface separates overlay and scrolls long content',
    (tester) async {
      tester.view.physicalSize = const Size(600, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: RichTooltipSurface(
              maxWidth: 420,
              child: SizedBox(height: 900),
            ),
          ),
        ),
      );

      final surface = find.byKey(const ValueKey('rich-tooltip-surface'));
      final material = tester.widget<Material>(surface);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(material.elevation, 18);
      expect(material.color, isNot(ThemeData.dark().colorScheme.surface));
      expect(shape.side, BorderSide.none);
      expect(tester.getSize(surface).height, 328);
      expect(
        find.descendant(
          of: surface,
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      final scrollView = find.descendant(
        of: surface,
        matching: find.byType(SingleChildScrollView),
      );
      final surfaceRect = tester.getRect(surface);
      final scrollRect = tester.getRect(scrollView);
      expect(scrollRect.top, surfaceRect.top + 14);
      expect(scrollRect.bottom, surfaceRect.bottom - 14);
      final scrollbar = tester.widget<Scrollbar>(
        find.descendant(of: surface, matching: find.byType(Scrollbar)),
      );
      expect(scrollbar.thumbVisibility, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

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
            child: RichTooltipSurface(
              maxWidth: 320,
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
    for (final prompt in tester.widgetList<TranslatedPromptText>(
      find.byType(TranslatedPromptText),
    )) {
      expect(prompt.includeUntranslated, isTrue);
    }
    final promptTooltips = [
      find.byType(PositivePromptTooltip),
      find.byType(NegativePromptTooltip),
    ];
    for (final tooltip in promptTooltips) {
      final finalPrompt = find.descendant(
        of: tooltip,
        matching: find.byType(TooltipFinalPromptSection),
      );
      final composition = find.descendant(
        of: tooltip,
        matching: find.byType(TooltipCompositionHeading),
      );
      expect(finalPrompt, findsOneWidget);
      expect(composition, findsOneWidget);
      expect(
        tester.getRect(finalPrompt).bottom,
        lessThan(tester.getRect(composition).top),
      );
    }
    expect(
      tester
          .widgetList<Container>(find.byType(Container))
          .where((container) => container.constraints?.maxHeight == 1),
      isEmpty,
    );
    final copyButtons = find.byIcon(Icons.copy_rounded);
    expect(copyButtons, findsNWidgets(2));

    await tester.tap(copyButtons.at(0));
    await tester.tap(copyButtons.at(1));
    await tester.pump();

    expect(positiveCopies, 1);
    expect(negativeCopies, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('composition cards and final prompt expand independently', (
    tester,
  ) async {
    final theme = ThemeData.dark();
    final prefix = FixedTagEntry.create(
      name: 'negative prefix',
      content: 'lowres, blurry, bad anatomy',
      promptType: FixedTagPromptType.negative,
    );
    final suffix = FixedTagEntry.create(
      name: 'negative suffix',
      content: 'watermark, signature',
      position: FixedTagPosition.suffix,
      promptType: FixedTagPromptType.negative,
    );
    final longMain = List.generate(24, (index) => 'main_tag_$index').join(', ');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: NegativePromptTooltip(
                    theme: theme,
                    userNegativePrompt: longMain,
                    prefixes: [prefix],
                    suffixes: [suffix],
                    ucPresetContent: 'worst quality, low quality',
                    l10n: AppLocalizations.of(context)!,
                    aliasResolver: ref.read(
                      aliasResolverServiceProvider.notifier,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(NegativePromptTooltip)),
    )!;
    final mainSection = find.byWidgetPredicate(
      (widget) =>
          widget is TooltipSection && widget.label == l10n.prompt_mainNegative,
    );
    expect(
      find.descendant(
        of: mainSection,
        matching: find.byType(TranslatedPromptText),
      ),
      findsNothing,
    );

    await tester.tap(find.text(l10n.prompt_mainNegative));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: mainSection,
        matching: find.byType(TranslatedPromptText),
      ),
      findsOneWidget,
    );

    final finalSection = find.byType(TooltipFinalPromptSection);
    final finalPrompt = find.descendant(
      of: finalSection,
      matching: find.byType(TranslatedPromptText),
    );
    expect(tester.widget<TranslatedPromptText>(finalPrompt).maxLines, 3);

    await tester.tap(find.byKey(const ValueKey('tooltip-final-expand-toggle')));
    await tester.pumpAndSettle();
    expect(tester.widget<TranslatedPromptText>(finalPrompt).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('提示词组成预览按五类业务语义分配颜色', (tester) async {
    final theme = ThemeData.dark();
    final positivePrefix = FixedTagEntry.create(
      name: 'positive prefix',
      content: 'best quality',
    );
    final positiveSuffix = FixedTagEntry.create(
      name: 'positive suffix',
      content: 'detailed',
      position: FixedTagPosition.suffix,
    );
    final negativePrefix = FixedTagEntry.create(
      name: 'negative prefix',
      content: 'lowres',
      promptType: FixedTagPromptType.negative,
    );
    final negativeSuffix = FixedTagEntry.create(
      name: 'negative suffix',
      content: 'watermark',
      position: FixedTagPosition.suffix,
      promptType: FixedTagPromptType.negative,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              final l10n = AppLocalizations.of(context)!;
              final aliasResolver = ref.read(
                aliasResolverServiceProvider.notifier,
              );
              return Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      PositivePromptTooltip(
                        theme: theme,
                        userPrompt: 'main prompt',
                        prefixes: [positivePrefix],
                        suffixes: [positiveSuffix],
                        qualityContent: 'quality tags',
                        characters: const [],
                        globalAiChoice: true,
                        l10n: l10n,
                        aliasResolver: aliasResolver,
                      ),
                      NegativePromptTooltip(
                        theme: theme,
                        userNegativePrompt: 'main negative prompt',
                        prefixes: [negativePrefix],
                        suffixes: [negativeSuffix],
                        ucPresetContent: 'negative quality tags',
                        l10n: l10n,
                        aliasResolver: aliasResolver,
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

    final colors = theme.promptSemanticColors;
    final sections = tester
        .widgetList<TooltipSection>(find.byType(TooltipSection))
        .toList();
    expect(sections.map((section) => section.color), [
      colors.positiveFixedTag,
      colors.mainPrompt,
      colors.positiveQuality,
      theme.colorScheme.secondary,
      colors.negativeQuality,
      colors.negativeFixedTag,
      colors.mainPrompt,
      theme.colorScheme.tertiary,
    ]);
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
