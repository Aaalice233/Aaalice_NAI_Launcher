import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_cache_database.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_providers.dart';
import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/danbooru_completion_source.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_wrapper.dart';

void main() {
  late String hivePath;

  setUp(() async {
    hivePath =
        '${Directory.systemTemp.path}/autocomplete_widget_${DateTime.now().microsecondsSinceEpoch}';
    Hive.init(hivePath);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  testWidgets('shows local BASE results and inserts by keyboard', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'blu');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    final baseSource = _BaseSource();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [baseSource],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.text('blue_eyes'), findsOneWidget);
    expect(find.text('BASE'), findsOneWidget);
    expect(baseSource.lastLimit, CompletionResultLimits.all);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'blue_eyes, ');
    expect(controller.selection.extentOffset, controller.text.length);
  });

  testWidgets('keyboard navigation scrolls only at the viewport edge', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'tag');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    addTearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_ManyBaseSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              child: TextField(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    final listView = tester.widget<ListView>(find.byType(ListView));
    final scrollController = listView.controller!;
    expect(scrollController.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scrollController.offset, 0);

    for (var i = 0; i < 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(0));
    expect(
      scrollController.offset,
      lessThan(12 * 35),
      reason: 'the selected row must not be aligned to the top edge',
    );
  });

  testWidgets(
    'opens, pins, and continuously inserts related tags by keyboard',
    (tester) async {
      final controller = TextEditingController(text: 'blue_archive');
      controller.selection = const TextSelection.collapsed(offset: 5);
      final focusNode = FocusNode();
      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autocompleteServicesProvider.overrideWithValue(
              AutocompleteServices(
                localSources: [_RelatedSource()],
                dictionaryTranslations: const _NoTranslations(),
                llmTranslations: const _NoTranslations(),
                danbooru: _NoDanbooru(),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AutocompleteWrapper(
                controller: controller,
                focusNode: focusNode,
                child: TextField(controller: controller, focusNode: focusNode),
              ),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.text('Related tags'), findsOneWidget);
      expect(find.text('halo'), findsOneWidget);
      expect(find.text('smile'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('autocomplete-popup-related-pin')),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(controller.text, 'blue_archive, halo, ');
      expect(find.text('smile'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(controller.text, 'blue_archive, halo, smile, ');
      expect(find.text('No related tags are available'), findsOneWidget);
    },
  );

  testWidgets('settings button receives hover and opens data settings', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'blu');
    controller.selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: 480,
                child: AutocompleteWrapper(
                  controller: controller,
                  focusNode: focusNode,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => Scaffold(
            body: Text("settings:${state.uri.queryParameters['section']}"),
          ),
        ),
      ],
    );
    addTearDown(() {
      router.dispose();
      controller.dispose();
      focusNode.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autocompleteServicesProvider.overrideWithValue(
            AutocompleteServices(
              localSources: [_BaseSource()],
              dictionaryTranslations: const _NoTranslations(),
              llmTranslations: const _NoTranslations(),
              danbooru: _NoDanbooru(),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    final settingsButton = find.byKey(
      const ValueKey('autocomplete-popup-settings'),
    );
    expect(settingsButton, findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(settingsButton));
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text('Open autocomplete and data source settings'),
      findsOneWidget,
    );

    await mouse.down(tester.getCenter(settingsButton));
    await tester.pump();
    expect(settingsButton, findsOneWidget);
    await mouse.up();
    await tester.pumpAndSettle();

    expect(find.text('settings:storage'), findsOneWidget);
  });
}

class _BaseSource implements CompletionSource {
  int? lastLimit;

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    lastLimit = query.limit;
    return [
      const CompletionCandidate(
        canonicalTag: 'blue_eyes',
        category: TagCategory.general,
        postCount: 1000,
        matchKind: CompletionMatchKind.englishPrefix,
        sources: {CompletionSourceKind.base},
      ),
    ];
  }
}

class _ManyBaseSource implements CompletionSource {
  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    return List.generate(
      30,
      (index) => CompletionCandidate(
        canonicalTag: 'tag_${index.toString().padLeft(2, '0')}',
        category: TagCategory.general,
        postCount: 1000,
        matchKind: CompletionMatchKind.englishPrefix,
        sources: const {CompletionSourceKind.base},
      ),
    );
  }
}

class _RelatedSource implements CompletionSource {
  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    if (query.relatedTag == null) return const [];
    return const [
          CompletionCandidate(
            canonicalTag: 'halo',
            category: TagCategory.general,
            postCount: 250000,
            matchKind: CompletionMatchKind.related,
            sources: {CompletionSourceKind.cooccurrence},
            relatedScore: 0.77,
            cooccurrenceCount: 220000,
          ),
          CompletionCandidate(
            canonicalTag: 'smile',
            category: TagCategory.general,
            postCount: 200000,
            matchKind: CompletionMatchKind.related,
            sources: {CompletionSourceKind.cooccurrence},
            relatedScore: 0.6,
            cooccurrenceCount: 180000,
          ),
        ]
        .where(
          (candidate) => !query.existingTags.contains(candidate.canonicalTag),
        )
        .toList();
  }
}

class _NoTranslations implements TranslationResolver {
  const _NoTranslations();

  @override
  Future<Map<String, String>> resolve(
    List<String> canonicalTags, {
    required String locale,
  }) async => const {};
}

class _NoDanbooru extends DanbooruCompletionSource {
  _NoDanbooru() : super(cache: _MemoryCache());

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async =>
      const [];

  @override
  Future<List<CompletionCandidate>> relatedTags(
    String tag, {
    int limit = 20,
  }) async => const [];
}

class _MemoryCache extends AutocompleteCacheDatabase {
  @override
  Future<CachedAutocompletePayload?> getRemote(String key) async => null;

  @override
  Future<void> putRemote(
    String key,
    List<Map<String, dynamic>> payload,
  ) async {}
}
