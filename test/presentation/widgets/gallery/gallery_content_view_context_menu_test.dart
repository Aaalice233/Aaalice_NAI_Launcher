import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/services/local_gallery_deletion.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_thumbnail_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_top_bar.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_content_view.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

void main() {
  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  for (final firstRead in ['成功', '读取异常', '返回空页']) {
    testWidgets('末页删除后读取网格新页（$firstRead），删空返回图库', (tester) async {
      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.android,
      );
      await tester.binding.setSurfaceSize(const Size(1600, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final l10n = lookupAppLocalizations(const Locale('en'));
      final records = [
        for (var i = 0; i < 51; i++)
          LocalImageRecord(
            path: 'gallery/$i.png',
            size: i,
            modifiedAt: DateTime(2026),
            metadata: NaiImageMetadata(seed: i),
          ),
      ];
      final notifier = _ViewerGallery(records.last);
      var outcome = GalleryImageDeleteResult.cancelled;
      var newPage = records.take(50).toList();
      final targets = <String>[];
      final sends = <(String, LocalImageContextAction)>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localGalleryNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                final page = ref.watch(localGalleryNotifierProvider);
                if (page.isLoading) {
                  return const Scaffold(body: Text('loading gallery'));
                }
                if (page.currentImages.isEmpty) {
                  return const Scaffold(body: Text('empty gallery'));
                }
                return Scaffold(
                  body: LocalGalleryContentView(
                    columns: 1,
                    itemWidth: 120,
                    onDelete: (record) async {
                      targets.add(record.path);
                      if (outcome.fileIsGone) {
                        if (firstRead != '成功' &&
                            outcome ==
                                GalleryImageDeleteResult.alreadyMissing) {
                          notifier.failThenRetry(
                            newPage,
                            reportError: firstRead == '读取异常',
                          );
                        } else {
                          if (outcome ==
                              GalleryImageDeleteResult.alreadyMissing) {
                            notifier.startReplacementPage();
                            await WidgetsBinding.instance.endOfFrame;
                          }
                          notifier.show(newPage);
                        }
                      }
                      return outcome;
                    },
                    onSendAction: (record, action, {onSent}) async {
                      expect(onSent, isNotNull);
                      sends.add((record.path, action));
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      final originalGrid = tester.element(find.byType(LocalGalleryContentView));
      final grid = tester.widget<GenericGalleryContentView<LocalImageRecord>>(
        find.byType(GenericGalleryContentView<LocalImageRecord>),
      );
      grid.view3DConfig!.showDetailViewer(grid.state.currentImages, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      Future<void> invokeDelete() async {
        tester.widget<DetailTopBar>(find.byType(DetailTopBar)).onDelete!();
        await tester.pump();
        await tester.pump();
      }

      for (final keep in [
        GalleryImageDeleteResult.cancelled,
        GalleryImageDeleteResult.failed,
      ]) {
        outcome = keep;
        await invokeDelete();
        expect(find.text('1 / 1'), findsOneWidget);
        expect(find.byType(DetailThumbnailBar), findsNothing);
      }
      outcome = GalleryImageDeleteResult.alreadyMissing;
      await invokeDelete();
      if (firstRead != '成功') {
        if (firstRead == '读取异常') {
          expect(find.textContaining('page unavailable'), findsOneWidget);
        }
        expect(find.byType(DetailTopBar), findsNothing);
        expect(targets, List.filled(3, records.last.path));
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump();
        expect(notifier.readPages, [0]);
        expect(targets, List.filled(3, records.last.path));
      }
      expect(find.text('50 / 50'), findsOneWidget);
      final bar = tester.widget<DetailThumbnailBar>(
        find.byType(DetailThumbnailBar),
      );
      expect(
        bar.images.map((image) => image.identifier),
        newPage.map((record) => record.path),
      );
      expect(bar.currentIndex, 49);
      expect(originalGrid.mounted, isFalse);
      await tester.pump();
      for (final label in [
        l10n.detail_sendToImg2Img,
        l10n.detail_sendToReversePrompt,
      ]) {
        final button = find.byTooltip(label).hitTestable();
        expect(button, findsOneWidget);
        await tester.tap(button);
      }
      await tester.pump();
      expect(sends, [
        (records[49].path, LocalImageContextAction.sendToImg2Img),
        (records[49].path, LocalImageContextAction.sendToReversePrompt),
      ]);
      outcome = GalleryImageDeleteResult.deleted;
      newPage = [];
      await invokeDelete();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(targets, [...List.filled(3, records.last.path), records[49].path]);
      expect(find.text('empty gallery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('grouped gallery forwards secondary taps to the context menu', (
    tester,
  ) async {
    final record = LocalImageRecord(
      path: 'G:/gallery/grouped-image.png',
      size: 42,
      modifiedAt: DateTime(2026, 7, 11),
    );
    LocalImageRecord? selectedRecord;
    Offset? selectedPosition;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GenericGalleryContentView<LocalImageRecord>(
              columns: 1,
              itemWidth: 160,
              state: _GroupedGalleryState(record),
              selectionState: const _InactiveSelectionState(),
              idExtractor: (item) => item.path,
              onContextMenu: (item, position) {
                selectedRecord = item;
                selectedPosition = position;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final card = find.byType(LocalImageCard3D);
    expect(card, findsOneWidget);

    await tester.tap(card, buttons: kSecondaryMouseButton);
    await tester.pump();

    expect(selectedRecord, same(record));
    expect(selectedPosition, isNotNull);
  });

  testWidgets('grouped card aspect ratio follows a replaced file', (
    tester,
  ) async {
    Future<double?> pumpCardHeight(LocalImageRecord record) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: GenericGalleryContentView<LocalImageRecord>(
                columns: 1,
                itemWidth: 160,
                state: _GroupedGalleryState(record),
                selectionState: const _InactiveSelectionState(),
                idExtractor: (item) => item.path,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return tester
          .widget<LocalImageCard3D>(find.byType(LocalImageCard3D))
          .height;
    }

    final portrait = LocalImageRecord(
      path: 'G:/gallery/replaced-image.png',
      size: 42,
      modifiedAt: DateTime(2026, 9, 1),
      metadata: const NaiImageMetadata(width: 100, height: 200),
    );
    expect(await pumpCardHeight(portrait), 320);

    final replaced = portrait.copyWith(
      modifiedAt: DateTime(2026, 9, 2),
      metadata: const NaiImageMetadata(width: 200, height: 100),
    );
    expect(await pumpCardHeight(replaced), 80);
  });

  testWidgets('local card action layout follows the image aspect ratio', (
    tester,
  ) async {
    final record = LocalImageRecord(
      path: 'G:/gallery/action-layout-image.png',
      size: 42,
      modifiedAt: DateTime(2026, 7, 29),
    );

    Future<Axis> readDirection({
      required double width,
      required double height,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: LocalImageCard3D(
                  record: record,
                  width: width,
                  height: height,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(LocalImageCard3D)),
      );
      await tester.pump();
      final direction = tester
          .widget<CardActionButtons>(find.byType(CardActionButtons))
          .direction;
      await mouse.removePointer();
      await tester.pump();
      return direction;
    }

    expect(await readDirection(width: 160, height: 220), Axis.vertical);
    expect(await readDirection(width: 220, height: 120), Axis.horizontal);
  });

  testWidgets(
    'moving away immediately after a card action does not open the image',
    (tester) async {
      final record = LocalImageRecord(
        path: 'G:/gallery/action-race-image.png',
        size: 42,
        modifiedAt: DateTime(2026, 7, 29),
      );
      var cardTapCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: LocalImageCard3D(
                  record: record,
                  width: 160,
                  height: 220,
                  onTap: () => cardTapCount++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.byType(LocalImageCard3D)),
      );
      await tester.pump();

      final copyButton = find.byIcon(Icons.copy);
      expect(copyButton, findsOneWidget);
      await mouse.moveTo(tester.getCenter(copyButton));
      await mouse.down(tester.getCenter(copyButton));
      await mouse.moveTo(const Offset(300, 300));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(cardTapCount, 0);
    },
  );

  testWidgets('touch cards expose favorite and context actions without hover', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    final record = LocalImageRecord(
      path: 'G:/gallery/touch-actions.png',
      size: 42,
      modifiedAt: DateTime(2026, 8, 2),
    );
    var cardTapCount = 0;
    var favoriteCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: InteractionPolicyScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: LocalImageCard3D(
                  record: record,
                  width: 160,
                  height: 220,
                  onTap: () => cardTapCount++,
                  onFavoriteToggle: () => favoriteCount++,
                  onSendAction: (_) async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _observeTouch(tester);

    expect(find.byTooltip('More actions'), findsOneWidget);
    expect(find.byTooltip('Copy Prompt'), findsNothing);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Copy Prompt'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Delete'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Delete'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Favorite'),
      -120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Favorite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(favoriteCount, 1);
    expect(cardTapCount, 0);
  });

  for (final grouped in [false, true]) {
    testWidgets('${grouped ? '分组视图' : '主网格'}：在相簿里才有「移出相簿」', (tester) async {
      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.android,
      );
      final record = LocalImageRecord(
        path: 'G:/gallery/in-album-${grouped ? 'grouped' : 'grid'}.png',
        size: 42,
        modifiedAt: DateTime(2026, 11, 3),
      );
      Future<void> openMenu({required bool inAlbum}) async {
        await tester.pumpWidget(
          ProviderScope(
            child: InteractionPolicyScope(
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 360,
                      height: 600,
                      child: GenericGalleryContentView<LocalImageRecord>(
                        columns: 1,
                        itemWidth: 160,
                        state: _GroupedGalleryState(record, grouped: grouped),
                        selectionState: const _InactiveSelectionState(),
                        idExtractor: (item) => item.path,
                        onSendAction: (_, __) async {},
                        inAlbum: inAlbum,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await _observeTouch(tester);
        await tester.tap(find.byTooltip('More actions'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // 菜单是可滚动列表，滚到「删除」所在的末尾，管理组的项都已构建
      Future<void> scrollToEnd() => tester.scrollUntilVisible(
        find.text('Delete'),
        180,
        scrollable: find.byType(Scrollable).last,
      );

      await openMenu(inAlbum: true);
      await scrollToEnd();
      expect(find.text('Remove from Album'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await openMenu(inAlbum: false);
      await scrollToEnd();
      expect(find.text('Add to Album'), findsOneWidget);
      expect(find.text('Remove from Album'), findsNothing);
    });
  }

  testWidgets('grouped gallery send button dispatches the shared send action', (
    tester,
  ) async {
    final record = LocalImageRecord(
      path: 'G:/gallery/grouped-send-image.png',
      size: 42,
      modifiedAt: DateTime(2026, 7, 29),
    );
    LocalImageRecord? selectedRecord;
    LocalImageContextAction? selectedAction;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                height: 600,
                child: GenericGalleryContentView<LocalImageRecord>(
                  columns: 1,
                  itemWidth: 160,
                  state: _GroupedGalleryState(record),
                  selectionState: const _InactiveSelectionState(),
                  idExtractor: (item) => item.path,
                  onSendAction: (item, action) async {
                    selectedRecord = item;
                    selectedAction = action;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getCenter(find.byType(LocalImageCard3D)),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Send to Reverse Prompt'), findsOneWidget);
    expect(find.text('Import Image Metadata'), findsNothing);

    await tester.tap(find.text('Send to Reverse Prompt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selectedRecord, same(record));
    expect(selectedAction, LocalImageContextAction.sendToReversePrompt);

    selectedAction = null;
    await tester.tap(find.byIcon(Icons.text_snippet_outlined));
    await tester.pump();
    expect(selectedAction, LocalImageContextAction.copyPrompt);

    selectedAction = null;
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(selectedAction, LocalImageContextAction.delete);

    await mouse.removePointer();
    await tester.pump();
  });
}

Future<void> _observeTouch(WidgetTester tester) async {
  final position =
      tester.getBottomRight(find.byType(Scaffold)) - const Offset(1, 1);
  final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
  await touch.addPointer(location: position);
  await touch.down(position);
  await tester.pump();
  await touch.up();
  await tester.pump();
}

class _ViewerGallery extends LocalGalleryNotifier {
  _ViewerGallery(this.initial);
  final LocalImageRecord initial;
  late List<LocalImageRecord> retryPage;
  final readPages = <int>[];
  @override
  LocalGalleryState build() => LocalGalleryState(
    currentImages: [initial],
    currentPage: 1,
    isPageLoading: true,
    isInitialized: true,
  );

  void startReplacementPage() {
    state = state.copyWith(currentImages: [], isLoading: true);
  }

  void show(List<LocalImageRecord> records) {
    state = state.copyWith(
      currentPage: 0,
      currentImages: records,
      isLoading: false,
      error: null,
      totalCount: records.length,
    );
  }

  void failThenRetry(
    List<LocalImageRecord> records, {
    required bool reportError,
  }) {
    retryPage = records;
    state = state.copyWith(
      currentPage: 0,
      currentImages: [],
      totalCount: records.length,
      error: reportError
          ? const LocalGalleryError(
              LocalGalleryErrorCode.databaseFailed,
              details: 'page unavailable',
            )
          : null,
    );
  }

  @override
  Future<void> loadPage(int page, {bool showLoading = true}) async {
    readPages.add(page);
    show(retryPage);
  }
}

class _GroupedGalleryState implements GalleryState<LocalImageRecord> {
  const _GroupedGalleryState(this.record, {this.grouped = true});

  final LocalImageRecord record;
  final bool grouped;

  @override
  List<LocalImageRecord> get currentImages => [record];

  @override
  List<LocalImageRecord> get groupedImages => [record];

  @override
  bool get isGroupedView => grouped;

  @override
  bool get isPageLoading => false;

  @override
  bool get isGroupedLoading => false;

  @override
  bool get hasFilters => false;

  @override
  List<LocalImageRecord> get filteredFiles => [record];
}

class _InactiveSelectionState implements SelectionState {
  const _InactiveSelectionState();

  @override
  bool get isActive => false;

  @override
  Set<String> get selectedIds => const {};
}
