import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/quick_tag_cloud_catalog.dart';
import 'package:nai_launcher/data/models/online_gallery/quick_tag_cloud_codex.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/quick_tag_cloud_gallery_provider.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/quick_tag_cloud_toolbar.dart';

void main() {
  for (final width in [1600.0, 700.0]) {
    testWidgets('keeps codex controls in the gallery toolbar at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
      var refreshCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickTagCloudCatalogProvider.overrideWith(
              (ref) async => _catalog(),
            ),
            quickTagCloudCodexProvider.overrideWith(
              (ref, id) async => _codex(),
            ),
            quickTagCloudFilterProvider.overrideWith(
              _TestQuickTagCloudFilterNotifier.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _toolbar(onFiltersChanged: () async => refreshCount++),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Browse'), findsOneWidget);
      expect(find.text('Latest update'), findsOneWidget);
      expect(find.text('Recently viewed'), findsOneWidget);
      expect(find.text('Artist Codex'), findsOneWidget);
      expect(find.text('All categories'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      final contributors = find.byKey(
        const ValueKey('quick-tag-cloud-contributors'),
      );
      expect(contributors, findsOneWidget);
      expect(
        find.byKey(const ValueKey('quick-tag-cloud-check-updates')),
        findsNothing,
      );
      expect(
        tester.getCenter(contributors).dx,
        greaterThan(tester.getCenter(find.text('Filter')).dx),
      );
      expect(tester.widget<IconButton>(contributors).style?.side, isNull);
      expect(refreshCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wrapped source panel keeps every codex control reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickTagCloudCatalogProvider.overrideWith((ref) async => _catalog()),
          quickTagCloudCodexProvider.overrideWith((ref, id) async => _codex()),
          quickTagCloudFilterProvider.overrideWith(
            _TestQuickTagCloudFilterNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(40),
              child: _toolbar(
                wrapControls: true,
                onFiltersChanged: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final finder in [
      find.text('Browse'),
      find.text('Artist Codex'),
      find.text('All categories'),
      find.text('Filter'),
      find.byKey(const ValueKey('quick-tag-cloud-contributors')),
    ]) {
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(700));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens list dialogs without intrinsic viewport errors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickTagCloudCatalogProvider.overrideWith((ref) async => _catalog()),
          quickTagCloudCodexProvider.overrideWith((ref, id) async => _codex()),
          quickTagCloudFilterProvider.overrideWith(
            _TestQuickTagCloudFilterNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _toolbar(onFiltersChanged: () async {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(4, 4));
    addTearDown(mouse.removePointer);

    await _scrollToAndTap(tester, find.text('Artist Codex'));
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(find.byType(AlertDialog)));
    await tester.pump();
    expect(find.text('Select codex'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();

    await _scrollToAndTap(tester, find.text('All categories'));
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(find.byType(AlertDialog)));
    await tester.pump();
    expect(find.text('Category'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();

    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('quick-tag-cloud-contributors')),
    );
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(find.byType(AlertDialog)));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quick-tag-cloud-open-origin')),
      findsOneWidget,
    );
    expect(find.text('Open original page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aligns category counts across parent and leaf rows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickTagCloudCatalogProvider.overrideWith((ref) async => _catalog()),
          quickTagCloudCodexProvider.overrideWith(
            (ref, id) async => _codex(
              tree: const [
                {
                  'name': 'Parent',
                  'count': 120,
                  'children': [
                    {'name': 'Child', 'count': 12},
                  ],
                },
                {'name': 'Leaf', 'count': 9},
              ],
            ),
          ),
          quickTagCloudFilterProvider.overrideWith(
            _TestQuickTagCloudFilterNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _toolbar(onFiltersChanged: () async {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollToAndTap(tester, find.text('All categories'));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('120')).right,
      closeTo(tester.getRect(find.text('9')).right, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'does not duplicate content-rating controls in the filter dialog',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickTagCloudCatalogProvider.overrideWith(
              (ref) async => _catalog(nsfw: true),
            ),
            quickTagCloudCodexProvider.overrideWith(
              (ref, id) async => _codex(nsfw: true),
            ),
            quickTagCloudFilterProvider.overrideWith(
              _NsfwQuickTagCloudFilterNotifier.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: _toolbar(onFiltersChanged: () async {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToAndTap(tester, find.text('Filter'));
      await tester.pumpAndSettle();

      expect(find.text('Show adult content'), findsNothing);
      expect(find.text('Show R18G / extreme content'), findsNothing);
    },
  );

  testWidgets('applies filter changes only after confirmation', (tester) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickTagCloudCatalogProvider.overrideWith((ref) async => _catalog()),
          quickTagCloudCodexProvider.overrideWith((ref, id) async => _codex()),
          quickTagCloudFilterProvider.overrideWith(
            _TestQuickTagCloudFilterNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _toolbar(onFiltersChanged: () async => refreshCount++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuickTagCloudToolbar)),
    );

    await _scrollToAndTap(tester, find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('With images'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      container.read(quickTagCloudFilterProvider).mediaFilter,
      QuickTagCloudMediaFilter.all,
    );
    expect(refreshCount, 0);

    await _scrollToAndTap(tester, find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('With images'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      container.read(quickTagCloudFilterProvider).mediaFilter,
      QuickTagCloudMediaFilter.withImages,
    );
    expect(refreshCount, 1);
  });
}

Future<void> _scrollToAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

QuickTagCloudToolbar _toolbar({
  required Future<void> Function() onFiltersChanged,
  Set<String> selectedRatings = const {'g'},
  bool wrapControls = false,
}) => QuickTagCloudToolbar(
  onFiltersChanged: onFiltersChanged,
  selectedRatings: selectedRatings,
  wrapControls: wrapControls,
);

class _TestQuickTagCloudFilterNotifier extends QuickTagCloudFilterNotifier {
  @override
  QuickTagCloudGalleryQuery build() =>
      const QuickTagCloudGalleryQuery(codexId: 'artist');

  @override
  Future<bool> initializeContentAccess() async => false;

  @override
  Future<void> applyFilters({
    required String codexId,
    required String updateFilterId,
    required QuickTagCloudBrowseScope scope,
    required QuickTagCloudMediaFilter mediaFilter,
    required bool allowNsfw,
    required bool allowR18g,
  }) async {
    state = QuickTagCloudGalleryQuery(
      codexId: codexId,
      updateFilterId: updateFilterId,
      scope: scope,
      mediaFilter: mediaFilter,
      allowNsfw: allowNsfw,
      allowR18g: allowNsfw && allowR18g,
    );
  }
}

class _NsfwQuickTagCloudFilterNotifier extends QuickTagCloudFilterNotifier {
  @override
  QuickTagCloudGalleryQuery build() =>
      const QuickTagCloudGalleryQuery(codexId: 'artist', allowNsfw: true);

  @override
  Future<bool> initializeContentAccess() async => false;

  @override
  Future<void> applyFilters({
    required String codexId,
    required String updateFilterId,
    required QuickTagCloudBrowseScope scope,
    required QuickTagCloudMediaFilter mediaFilter,
    required bool allowNsfw,
    required bool allowR18g,
  }) async {
    state = QuickTagCloudGalleryQuery(
      codexId: codexId,
      updateFilterId: updateFilterId,
      scope: scope,
      mediaFilter: mediaFilter,
      allowNsfw: allowNsfw,
      allowR18g: allowNsfw && allowR18g,
    );
  }
}

QuickTagCloudCatalog _catalog({bool nsfw = false}) => QuickTagCloudCatalog(
  config: QuickTagCloudDataSourceConfig(
    schemaVersion: 1,
    baseUrl: Uri.https('example.test', '/data'),
    pointer: 'current.json',
  ),
  pointer: const QuickTagCloudReleasePointer(
    schemaVersion: 1,
    release: 'r-0123456789abcdef0123',
    manifest: 'manifest.json',
  ),
  manifest: QuickTagCloudReleaseManifest(
    schemaVersion: 1,
    release: 'r-0123456789abcdef0123',
    files: const {},
  ),
  codexes: [
    QuickTagCloudCodexMeta(
      id: 'artist',
      title: 'Artist Codex',
      version: '1.0',
      author: 'Alice',
      entryCount: 1,
      nsfw: nsfw,
      imagedCount: 1,
      contributors: const [
        QuickTagCloudContributor(name: 'Alice', role: 'Compiler'),
      ],
    ),
  ],
  media: const QuickTagCloudMediaConfig(),
);

QuickTagCloudCodex _codex({bool nsfw = false, List<dynamic> tree = const []}) =>
    QuickTagCloudCodex(
      id: 'artist',
      type: 'codex',
      title: 'Artist Codex',
      version: '1.0',
      author: 'Alice',
      nsfw: nsfw,
      assetBaseUrl: '',
      assetPathMode: '',
      dataUrl: '',
      sourceDataUrl: '',
      fallbackDataUrl: '',
      source: '',
      aliases: const [],
      hasOriginal: false,
      entries: const [],
      entryCount: 1,
      imagedCount: 1,
      tree: tree,
      loadSource: QuickTagCloudCodexLoadSource.canonical,
    );
