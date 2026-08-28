import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_settings.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/completion_overlay.dart';

void main() {
  testWidgets(
    'keeps query shortcuts and source health visible around results',
    (tester) async {
      final scrollController = ScrollController();
      var closeCount = 0;
      var settingsCount = 0;
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 760,
                child: CompletionOverlay(
                  state: const CompletionState(
                    query: CompletionQuery(
                      fullText: 'blue_',
                      cursorPosition: 5,
                      token: 'blue_',
                      replacementRange: TextReplacementRange(start: 0, end: 5),
                      existingTags: {},
                      limit: 20,
                      locale: 'zh-CN',
                    ),
                    candidates: [
                      CompletionCandidate(
                        canonicalTag: 'blue_eyes',
                        category: TagCategory.general,
                        postCount: 125000,
                        translation: '蓝色眼睛',
                        matchKind: CompletionMatchKind.englishPrefix,
                        sources: {
                          CompletionSourceKind.base,
                          CompletionSourceKind.zhDictionary,
                        },
                      ),
                      CompletionCandidate(
                        canonicalTag: 'blue_hair',
                        category: TagCategory.character,
                        postCount: 50000,
                        translation: '蓝色头发',
                        matchKind: CompletionMatchKind.englishPrefix,
                        sources: {CompletionSourceKind.danbooruApi},
                      ),
                    ],
                  ),
                  selectedIndex: 0,
                  maxHeight: 360,
                  scrollController: scrollController,
                  settings: const AutocompleteSettings(),
                  dictionaryState: const ZhDictionaryState(
                    isInstalled: true,
                    tagCount: 200000,
                  ),
                  showAliases: true,
                  showTranslations: true,
                  showCategory: true,
                  showCount: true,
                  onSelected: (_) {},
                  onClose: () => closeCount++,
                  onOpenSettings: () => settingsCount++,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('autocomplete-popup-header')), findsOne);
      expect(find.text('标签补全'), findsOne);
      expect(find.text('blue_'), findsOne);
      expect(find.text('2 个结果'), findsOne);
      expect(find.text('Enter/Tab'), findsOne);
      expect(find.text('Esc'), findsOne);

      final surface = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('autocomplete-popup-surface')),
      );
      final surfaceDecoration = surface.decoration as BoxDecoration;
      expect(surfaceDecoration.border, isNull);
      expect(surfaceDecoration.boxShadow!.length, greaterThanOrEqualTo(3));
      final background = tester.widget<Material>(
        find.byKey(const ValueKey('autocomplete-popup-background')),
      );
      expect(
        background.color!.computeLuminance(),
        greaterThan(ThemeData.dark().colorScheme.surface.computeLuminance()),
      );
      expect(
        tester.getTopLeft(find.text('蓝色眼睛')).dx,
        tester.getTopLeft(find.text('蓝色头发')).dx,
      );
      expect(find.text('BASE'), findsOne);
      expect(find.text('ZH'), findsOne);
      expect(find.text('API'), findsOne);
      expect(
        find.byTooltip('随应用提供的基础词库 · ffdkj 中文汉化库'),
        findsNothing,
      );
      expect(find.textContaining('2/2', findRichText: true), findsOneWidget);
      expect(
        find.byKey(const ValueKey('autocomplete-category-general')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('autocomplete-category-character')),
        findsOne,
      );
      expect(find.byIcon(Icons.sell_rounded), findsOne);
      expect(find.byIcon(Icons.person_rounded), findsOne);

      expect(find.byKey(const ValueKey('autocomplete-popup-footer')), findsOne);
      expect(find.byKey(const ValueKey('autocomplete-status-base')), findsOne);
      expect(
        find.byKey(const ValueKey('autocomplete-status-dictionary')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('autocomplete-status-online')),
        findsOne,
      );
      expect(find.byKey(const ValueKey('autocomplete-status-ai')), findsOne);

      await tester.tap(
        find.byKey(const ValueKey('autocomplete-popup-close')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(const ValueKey('autocomplete-popup-settings')),
        warnIfMissed: false,
      );
      expect(closeCount, 1);
      expect(settingsCount, 1);
    },
  );

  testWidgets('phone layout keeps tag details readable in two rows', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: CompletionOverlay(
                state: const CompletionState(
                  query: CompletionQuery(
                    fullText: 'character_',
                    cursorPosition: 10,
                    token: 'character_',
                    replacementRange: TextReplacementRange(start: 0, end: 10),
                    existingTags: {},
                    limit: 20,
                    locale: 'zh-CN',
                  ),
                  candidates: [
                    CompletionCandidate(
                      canonicalTag: 'extremely_long_character_name',
                      category: TagCategory.character,
                      postCount: 125000,
                      translation: '很长的角色中文翻译',
                      matchKind: CompletionMatchKind.englishPrefix,
                      sources: {
                        CompletionSourceKind.base,
                        CompletionSourceKind.zhDictionary,
                        CompletionSourceKind.danbooruApi,
                      },
                    ),
                  ],
                ),
                selectedIndex: 0,
                maxHeight: 320,
                scrollController: scrollController,
                settings: const AutocompleteSettings(),
                dictionaryState: const ZhDictionaryState(
                  isInstalled: true,
                  tagCount: 200000,
                ),
                showAliases: true,
                showTranslations: true,
                showCategory: true,
                showCount: true,
                onSelected: (_) {},
                onClose: () {},
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final tag = find.text('extremely_long_character_name');
    final translation = find.text('很长的角色中文翻译');
    expect(tag, findsOneWidget);
    expect(translation, findsOneWidget);
    expect(
      tester.getTopLeft(tag).dy,
      lessThan(tester.getTopLeft(translation).dy),
    );
    expect(find.text('BASE'), findsOneWidget);
    expect(find.text('ZH'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_alt_outlined), findsNothing);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey(
                'autocomplete-candidate-extremely_long_character_name',
              ),
            ),
          )
          .height,
      48,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('autocomplete-popup-close'))),
      const Size(48, 48),
    );
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('autocomplete-popup-surface')),
    );
    expect((surface.decoration as BoxDecoration).border, isNotNull);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'presents related mode, Jaccard strength, and local source status',
    (tester) async {
      final scrollController = ScrollController();
      var pinCount = 0;
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 700,
              child: CompletionOverlay(
                state: const CompletionState(
                  query: CompletionQuery(
                    fullText: 'blue_archive, ',
                    cursorPosition: 14,
                    token: '',
                    replacementRange: TextReplacementRange(start: 14, end: 14),
                    existingTags: {'blue_archive'},
                    limit: 100,
                    locale: 'en',
                    relatedTag: 'blue_archive',
                  ),
                  candidates: [
                    CompletionCandidate(
                      canonicalTag: 'halo',
                      category: TagCategory.general,
                      postCount: 265497,
                      matchKind: CompletionMatchKind.related,
                      sources: {
                        CompletionSourceKind.cooccurrence,
                        CompletionSourceKind.danbooruApi,
                      },
                      relatedScore: 0.769,
                      cooccurrenceCount: 221957,
                    ),
                  ],
                ),
                selectedIndex: 0,
                maxHeight: 360,
                scrollController: scrollController,
                settings: const AutocompleteSettings(),
                dictionaryState: const ZhDictionaryState(),
                showAliases: true,
                showTranslations: true,
                showCategory: true,
                showCount: true,
                onSelected: (_) {},
                onClose: () {},
                onOpenSettings: () {},
                isRelatedPinned: true,
                onToggleRelatedPin: () => pinCount++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Related tags'), findsOneWidget);
      expect(find.text('blue_archive'), findsOneWidget);
      expect(find.text('77%'), findsOneWidget);
      expect(find.text('REL'), findsOneWidget);
      expect(find.text('API'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('autocomplete-status-related')),
        findsOne,
      );
      final pin = find.byKey(const ValueKey('autocomplete-popup-related-pin'));
      expect(pin, findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
      await tester.tap(pin);
      expect(pinCount, 1);
    },
  );

  testWidgets('virtualizes exhaustive result sets while scrolling', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    final candidates = List.generate(
      1000,
      (index) => CompletionCandidate(
        canonicalTag: 'blue_archive_${index.toString().padLeft(4, '0')}',
        category: TagCategory.general,
        postCount: 1000 - index,
        matchKind: CompletionMatchKind.fullText,
        sources: const {CompletionSourceKind.base},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: CompletionOverlay(
              state: CompletionState(candidates: candidates),
              selectedIndex: 0,
              maxHeight: 360,
              scrollController: scrollController,
              settings: const AutocompleteSettings(),
              dictionaryState: const ZhDictionaryState(),
              showAliases: true,
              showTranslations: true,
              showCategory: true,
              showCount: true,
              onSelected: (_) {},
              onClose: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('blue_archive_0000'), findsOneWidget);
    expect(find.text('blue_archive_0999'), findsNothing);
    expect(find.text('Not translated'), findsWidgets);
    expect(
      find.byKey(const ValueKey('autocomplete-popup-result-count')),
      findsOneWidget,
    );

    scrollController.jumpTo(1);
    await tester.pump();
    scrollController.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 200));
    final scrollbar = find.byKey(
      const ValueKey('autocomplete-popup-scrollbar'),
    );
    final rawScrollbar = find.descendant(
      of: scrollbar,
      matching: find.byWidgetPredicate((widget) => widget is RawScrollbar),
    );
    expect(rawScrollbar, findsOneWidget);
    final listRect = tester.getRect(
      find.byKey(const ValueKey('autocomplete-popup-list')),
    );
    final firstBadgeRect = tester.getRect(find.text('BASE').first);
    expect(listRect.right - firstBadgeRect.right, greaterThanOrEqualTo(20));

    final scrollbarState = tester.state(rawScrollbar);
    final dynamic painter = (scrollbarState as dynamic).scrollbarPainter;
    final scrollbarSize = tester.getSize(rawScrollbar);
    Offset? localThumbPoint;
    for (var y = 1.0; y < scrollbarSize.height; y++) {
      for (var x = scrollbarSize.width - 1; x >= 0; x--) {
        final point = Offset(x, y);
        if (painter.hitTestOnlyThumbInteractive(point, PointerDeviceKind.mouse)
            as bool) {
          localThumbPoint = point;
          break;
        }
      }
      if (localThumbPoint != null) break;
    }
    expect(localThumbPoint, isNotNull);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    final thumbStart = tester.getTopLeft(rawScrollbar) + localThumbPoint!;
    await mouse.moveTo(thumbStart);
    await mouse.down(thumbStart);
    await tester.pump();
    await mouse.moveTo(thumbStart + const Offset(0, 120));
    await tester.pump();
    await mouse.up();
    await tester.pump();

    expect(scrollController.offset, greaterThan(0));

    final beforeTrackTap = scrollController.offset;
    final trackPoint =
        tester.getTopLeft(rawScrollbar) +
        Offset(localThumbPoint.dx, scrollbarSize.height - 8);
    await mouse.moveTo(trackPoint);
    await mouse.down(trackPoint);
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(beforeTrackTap));

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();

    expect(find.text('blue_archive_0000'), findsNothing);
    expect(find.text('blue_archive_0999'), findsOneWidget);
  });

  testWidgets('shows live loading and failure states without hiding results', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 620,
            child: CompletionOverlay(
              state: const CompletionState(
                candidates: [
                  CompletionCandidate(
                    canonicalTag: 'solo',
                    category: TagCategory.general,
                    postCount: 100,
                    matchKind: CompletionMatchKind.englishExact,
                    sources: {CompletionSourceKind.base},
                    isTranslating: true,
                  ),
                ],
                isRemoteLoading: true,
              ),
              selectedIndex: 0,
              maxHeight: 360,
              scrollController: scrollController,
              settings: const AutocompleteSettings(llmTranslationEnabled: true),
              dictionaryState: const ZhDictionaryState(
                isBusy: true,
                progress: 0.42,
              ),
              showAliases: true,
              showTranslations: true,
              showCategory: true,
              showCount: true,
              onSelected: (_) {},
              onClose: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.textContaining('Downloading 42%', findRichText: true),
      findsOne,
    );
    expect(find.textContaining('Searching', findRichText: true), findsOne);
    expect(
      find.textContaining('Translating', findRichText: true),
      findsWidgets,
    );
    expect(find.text('solo'), findsOne);
  });
}
