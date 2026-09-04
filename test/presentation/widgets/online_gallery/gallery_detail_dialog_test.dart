import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_prompt_projection.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_detail_dialog.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_detail_overview_card.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_prompt_copy_dialog.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/video_player_widget.dart';
import 'package:nai_launcher/presentation/widgets/tag_chip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'renders text-only entries and only commits successful favorites',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var favoriteSucceeds = false;
      var copyCount = 0;
      var sentToGenerate = false;
      var addedToQueue = false;
      final item = GalleryItem(
        id: 0,
        workId: 'book/entry-1',
        sourceId: GallerySourceId.quickTagCloud,
        title: 'Text entry',
        author: 'Author',
        previewFileUrl: '',
        sampleUrl: '',
        fileUrl: '',
        tagString: 'positive prompt',
        tags: const ['positive prompt', 'positive prompt'],
        createdAt: DateTime.utc(2025).toIso8601String(),
        rating: 'g',
        score: 0,
        width: 0,
        height: 0,
        fileExt: '',
      );
      final detail = GalleryDetail(
        item: item,
        prompt: 'positive prompt',
        negativePrompt: 'negative prompt',
        note: 'A useful note',
        categoryPath: const ['Root', 'Leaf'],
        contributors: const [
          GalleryContributor(name: 'Contributor', role: 'maintainer'),
        ],
        rawTags: const ['raw parameters'],
        characterPrompts: const [
          GalleryCharacterPrompt(
            label: 'Character',
            prompt: 'character prompt',
            negativePrompt: 'character negative',
          ),
        ],
        rawSourceMetadata: const {
          'codexTitle': 'Codex',
          'codexVersion': 'v1',
          'declaredSource': 'Original dataset',
        },
        media: const [],
        sourceUrl: item.postUrl,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GalleryDetailDialog(
                item: item,
                detail: detail,
                isFavorited: false,
                favoriteLoading: false,
                canUseGenerationActions: true,
                labels: _labels(),
                onCopyPrompt: (_) => copyCount++,
                onToggleFavorite: () async => favoriteSucceeds,
                onOpenSource: () {},
                onSendToGenerate: (_) => sentToGenerate = true,
                onAddToQueue: (_) async => addedToQueue = true,
                onDownloadCurrentOriginal: (_) async {},
                onTagSearch: (_) {},
                onBlacklistChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Text entry'), findsOneWidget);
      expect(find.text('No image'), findsOneWidget);
      expect(find.text('positive prompt'), findsOneWidget);
      expect(find.text('negative prompt'), findsOneWidget);
      expect(find.text('character prompt'), findsOneWidget);
      expect(find.text('character negative'), findsOneWidget);
      expect(find.text('raw parameters'), findsOneWidget);
      expect(find.byType(SimpleTagChip), findsNWidgets(4));
      final overview = find.byType(GalleryDetailOverviewCard);
      expect(
        find.descendant(of: overview, matching: find.text('negative prompt')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: overview, matching: find.text('raw parameters')),
        findsOneWidget,
      );
      final infoList = find.byKey(const ValueKey('gallery-detail-info-list'));
      final infoScrollable = find
          .descendant(of: infoList, matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(
        find.text('Contributor · maintainer'),
        180,
        scrollable: infoScrollable,
      );
      expect(find.text('Contributor · maintainer'), findsOneWidget);
      expect(find.text('Original dataset'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('gallery-detail-stats')),
          matching: find.byType(VerticalDivider),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byTooltip('Add favorite'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      favoriteSucceeds = true;
      await tester.tap(find.byTooltip('Add favorite'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      expect(find.byTooltip('Copy positive'), findsNothing);
      expect(find.byTooltip('Copy negative'), findsNothing);
      expect(find.byTooltip('Copy this character'), findsNothing);
      await tester.tap(find.byTooltip('Copy prompt'));
      await tester.tap(find.byKey(const ValueKey('gallery-detail-generate')));
      await tester.tap(find.byKey(const ValueKey('gallery-detail-queue')));
      await tester.pumpAndSettle();
      expect(copyCount, 1);
      expect(sentToGenerate, isTrue);
      expect(addedToQueue, isTrue);
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey('gallery-detail-action-download')),
            )
            .onTap,
        isNull,
      );
    },
  );

  testWidgets(
    'generation actions use projected capability for tags-only entries',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const item = GalleryItem(
        id: 42,
        workId: '42',
        sourceId: GallerySourceId.danbooru,
        tags: ['1girl', 'solo'],
        tagString: '1girl solo',
      );
      const detail = GalleryDetail(item: item, media: []);
      final canUseGenerationActions = ValueNotifier(false);
      addTearDown(canUseGenerationActions.dispose);
      var sentToGenerate = false;
      var addedToQueue = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: canUseGenerationActions,
                builder: (context, canUseActions, _) => GalleryDetailDialog(
                  item: item,
                  detail: detail,
                  isFavorited: false,
                  favoriteLoading: false,
                  canUseGenerationActions: canUseActions,
                  labels: _labels(),
                  onCopyPrompt: (_) {},
                  onToggleFavorite: () async => true,
                  onOpenSource: () {},
                  onSendToGenerate: (_) => sentToGenerate = true,
                  onAddToQueue: (_) async => addedToQueue = true,
                  onDownloadCurrentOriginal: (_) async {},
                  onTagSearch: (_) {},
                  onBlacklistChanged: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final generateButton = find.byKey(
        const ValueKey('gallery-detail-generate'),
      );
      final queueButton = find.byKey(const ValueKey('gallery-detail-queue'));
      expect(tester.widget<FilledButton>(generateButton).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(queueButton).onPressed, isNull);

      canUseGenerationActions.value = true;
      await tester.pump();

      expect(tester.widget<FilledButton>(generateButton).onPressed, isNotNull);
      expect(tester.widget<OutlinedButton>(queueButton).onPressed, isNotNull);
      await tester.tap(generateButton);
      await tester.tap(queueButton);
      await tester.pumpAndSettle();
      expect(sentToGenerate, isTrue);
      expect(addedToQueue, isTrue);
    },
  );

  testWidgets('action rail expands only the focused action without relayout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const item = GalleryItem(
      id: 43,
      sourceId: GallerySourceId.danbooru,
      tags: ['solo'],
      tagStringGeneral: 'solo',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GalleryDetailDialog(
              item: item,
              detail: const GalleryDetail(
                item: item,
                media: [
                  GalleryMedia(id: 'media-1'),
                  GalleryMedia(id: 'media-2'),
                ],
              ),
              isFavorited: false,
              favoriteLoading: false,
              canUseGenerationActions: true,
              labels: _labels(),
              onCopyPrompt: (_) {},
              onToggleFavorite: () async => true,
              onOpenSource: () {},
              onSendToGenerate: (_) {},
              onAddToQueue: (_) async {},
              onDownloadCurrentOriginal: (_) async {},
              onTagSearch: (_) {},
              onBlacklistChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copyAction = find.byKey(const ValueKey('gallery-detail-action-copy'));
    final viewerBefore = tester.getRect(find.byType(PageView));
    final expandedLabel = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == 'Copy prompt' &&
          widget.style?.fontWeight == FontWeight.w600,
    );
    for (
      var index = 0;
      index < 8 && expandedLabel.evaluate().isEmpty;
      index++
    ) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 180));
    }

    expect(copyAction, findsOneWidget);
    expect(expandedLabel, findsOneWidget);
    expect(find.text('Download original'), findsNothing);
    expect(tester.getRect(find.byType(PageView)), viewerBefore);
    final nextMedia = find.byKey(const ValueKey('gallery-detail-next-media'));
    expect(
      tester.getRect(nextMedia).right,
      lessThanOrEqualTo(tester.getRect(copyAction).left),
    );
  });

  testWidgets('320x568 detail avoids SafeArea and IME insets', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const item = GalleryItem(
      id: 47,
      sourceId: GallerySourceId.quickTagCloud,
      title: 'Compact detail',
      tags: ['solo'],
    );
    const safePadding = EdgeInsets.fromLTRB(0, 24, 0, 16);
    const viewInsets = EdgeInsets.only(bottom: 220);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: safePadding,
              viewPadding: safePadding,
              viewInsets: viewInsets,
            ),
            child: child!,
          ),
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: GalleryDetailDialog(
              item: item,
              detail: const GalleryDetail(item: item, media: []),
              isFavorited: false,
              favoriteLoading: false,
              canUseGenerationActions: true,
              labels: _labels(),
              onCopyPrompt: (_) {},
              onToggleFavorite: () async => true,
              onOpenSource: () {},
              onSendToGenerate: (_) {},
              onAddToQueue: (_) async {},
              onDownloadCurrentOriginal: (_) async {},
              onTagSearch: (_) {},
              onBlacklistChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dialogRect = tester.getRect(find.byType(Dialog));
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(320));
    expect(dialogRect.top, greaterThanOrEqualTo(safePadding.top));
    expect(
      dialogRect.bottom,
      lessThanOrEqualTo(568 - viewInsets.bottom - safePadding.bottom),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('gallery-detail-info-list')))
          .height,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact landscape dialog stays within the viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const item = GalleryItem(
      id: 45,
      sourceId: GallerySourceId.quickTagCloud,
      title: 'A deliberately long gallery title for responsive layout',
      tags: ['solo'],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: GalleryDetailDialog(
              item: item,
              detail: const GalleryDetail(
                item: item,
                media: [
                  GalleryMedia(id: 'landscape-1'),
                  GalleryMedia(id: 'landscape-2'),
                ],
              ),
              isFavorited: false,
              favoriteLoading: false,
              canUseGenerationActions: true,
              labels: _labels(),
              onCopyPrompt: (_) {},
              onToggleFavorite: () async => true,
              onOpenSource: () {},
              onSendToGenerate: (_) {},
              onAddToQueue: (_) async {},
              onDownloadCurrentOriginal: (_) async {},
              onTagSearch: (_) {},
              onBlacklistChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    final dialogRect = tester.getRect(find.byType(Dialog));
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.top, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(600));
    expect(dialogRect.bottom, lessThanOrEqualTo(360));

    final mediaRect = tester.getRect(find.byType(PageView));
    final infoRect = tester.getRect(
      find.byKey(const ValueKey('gallery-detail-info-list')),
    );
    expect(mediaRect.bottom, lessThanOrEqualTo(infoRect.top));
    expect(mediaRect.height, greaterThan(0));
    expect(infoRect.height, greaterThan(0));
    final nextMedia = find.byKey(const ValueKey('gallery-detail-next-media'));
    final actionOverflow = find.byKey(
      const ValueKey('gallery-detail-action-overflow'),
    );
    expect(nextMedia, findsOneWidget);
    expect(actionOverflow, findsOneWidget);
    expect(
      tester.getRect(nextMedia).right,
      lessThanOrEqualTo(tester.getRect(actionOverflow).left),
    );
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(600, 180));
    await tester.pumpAndSettle();
    final shortDialogRect = tester.getRect(find.byType(Dialog));
    expect(shortDialogRect.top, greaterThanOrEqualTo(0));
    expect(shortDialogRect.bottom, lessThanOrEqualTo(180));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow detail collapses actions without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const item = GalleryItem(
      id: 44,
      sourceId: GallerySourceId.quickTagCloud,
      tags: ['solo'],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GalleryDetailDialog(
              item: item,
              detail: const GalleryDetail(item: item, media: []),
              isFavorited: false,
              favoriteLoading: false,
              canUseGenerationActions: true,
              labels: _labels(),
              onCopyPrompt: (_) {},
              onToggleFavorite: () async => true,
              onOpenSource: () {},
              onSendToGenerate: (_) {},
              onAddToQueue: (_) async {},
              onDownloadCurrentOriginal: (_) async {},
              onTagSearch: (_) {},
              onBlacklistChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('gallery-detail-action-rail')),
      findsOneWidget,
    );
    final generate = find.byKey(const ValueKey('gallery-detail-generate'));
    final queue = find.byKey(const ValueKey('gallery-detail-queue'));
    expect(generate, findsOneWidget);
    expect(queue, findsOneWidget);
    expect(
      tester.getRect(generate).bottom,
      lessThan(tester.getRect(queue).top),
    );
    expect(find.text('Generate'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header keeps every action at 320 and 390 with large text', (
    tester,
  ) async {
    const item = GalleryItem(
      id: 46,
      sourceId: GallerySourceId.quickTagCloud,
      title: 'A deliberately long title that must remain constrained',
      tags: ['solo'],
    );

    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 700));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(3)),
              child: child!,
            ),
            home: Scaffold(
              body: GalleryDetailDialog(
                item: item,
                detail: const GalleryDetail(item: item, media: []),
                isFavorited: false,
                favoriteLoading: false,
                canUseGenerationActions: true,
                labels: _labels(sourceName: 'A very long gallery source name'),
                onCopyPrompt: (_) {},
                onToggleFavorite: () async => true,
                onOpenSource: () {},
                onSendToGenerate: (_) {},
                onAddToQueue: (_) async {},
                onDownloadCurrentOriginal: (_) async {},
                onTagSearch: (_) {},
                onBlacklistChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add favorite'), findsOneWidget);
      expect(find.byTooltip('Open source'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(
        tester.getRect(find.byTooltip('Close')).right,
        lessThanOrEqualTo(width),
      );
      final queue = find.byKey(const ValueKey('gallery-detail-queue'));
      await tester.ensureVisible(queue);
      await tester.pump();
      expect(tester.getRect(queue).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(queue).right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('conflicting video metadata renders a stable placeholder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const item = GalleryItem(
      id: 7,
      workId: '7',
      sourceId: GallerySourceId.danbooru,
    );
    const detail = GalleryDetail(
      item: item,
      media: [
        GalleryMedia(
          id: 'video-conflict',
          mediaType: 'video',
          displayUrl: 'https://example.test/not-a-video.jpg',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GalleryDetailDialog(
              item: item,
              detail: detail,
              isFavorited: false,
              favoriteLoading: false,
              canUseGenerationActions: false,
              labels: _labels(),
              onCopyPrompt: (_) {},
              onToggleFavorite: () async => true,
              onOpenSource: () {},
              onSendToGenerate: (_) {},
              onAddToQueue: (_) async {},
              onSendToReverse: (_) async {},
              onDownloadCurrentOriginal: (_) async {},
              onTagSearch: (_) {},
              onBlacklistChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(VideoPlayerWidget), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(find.byTooltip('Reverse'), findsNothing);
  });

  testWidgets('tag context menu searches one normalized tag', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const item = GalleryItem(
      id: 42,
      workId: '42',
      sourceId: GallerySourceId.danbooru,
      site: 'danbooru',
      tags: ['{red hair}', 'solo'],
      tagString: '{red hair}, solo',
    );
    String? searchedTag;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GalleryDetailDialog(
              item: item,
              detail: const GalleryDetail(item: item, media: []),
              isFavorited: false,
              favoriteLoading: false,
              canUseGenerationActions: true,
              labels: _labels(),
              onCopyPrompt: (_) {},
              onToggleFavorite: () async => true,
              onOpenSource: () {},
              onSendToGenerate: (_) {},
              onAddToQueue: (_) async {},
              onDownloadCurrentOriginal: (_) async {},
              onTagSearch: (tag) => searchedTag = tag,
              onBlacklistChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('{red hair}'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Empty'), findsNothing);
    await tester.tap(find.text('{red hair}'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(searchedTag, 'red_hair');
  });

  testWidgets('disables original download when only a preview exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final item = GalleryItem(
      id: 0,
      workId: 'book/preview-only',
      sourceId: GallerySourceId.quickTagCloud,
      title: 'Preview only',
      previewFileUrl: 'https://example.invalid/preview.webp',
      sampleUrl: 'https://example.invalid/preview.webp',
      fileUrl: 'https://example.invalid/preview.webp',
      tags: const [],
      createdAt: DateTime.utc(2025).toIso8601String(),
      rating: 'g',
      score: 0,
      width: 832,
      height: 1216,
      fileExt: 'webp',
    );
    final media = GalleryMedia(
      id: 'preview-only:0',
      previewUrl: item.previewUrl,
      displayUrl: item.previewUrl,
      downloadUrl: item.previewUrl,
      width: 832,
      height: 1216,
      extension: 'webp',
      metadata: const {'hasOriginal': false, 'path': 'book/preview-only.webp'},
    );

    GalleryMedia? watermarkedMedia;
    Widget buildDialog(GalleryMedia currentMedia) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: GalleryDetailDialog(
            item: item,
            detail: GalleryDetail(item: item, media: [currentMedia]),
            isFavorited: false,
            favoriteLoading: false,
            canUseGenerationActions: false,
            labels: _labels(),
            onCopyPrompt: (_) {},
            onToggleFavorite: () async => true,
            onOpenSource: () {},
            onSendToGenerate: (_) {},
            onAddToQueue: (_) async {},
            onDownloadCurrentOriginal: (_) async {},
            onDownloadAndWatermark: (selected) async {
              watermarkedMedia = selected;
            },
            onTagSearch: (_) {},
            onBlacklistChanged: () {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildDialog(media));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('832 × 1216 · WEBP'), findsOneWidget);
    expect(find.text('book/preview-only.webp'), findsOneWidget);
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey('gallery-detail-action-download')),
          )
          .onTap,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('gallery-detail-action-watermark')),
      findsNothing,
    );

    final originalMedia = GalleryMedia(
      id: 'original:0',
      previewUrl: item.previewUrl,
      displayUrl: item.previewUrl,
      downloadUrl: 'https://example.invalid/original.png',
      width: 832,
      height: 1216,
      extension: 'png',
      metadata: const {'hasOriginal': true},
    );
    await tester.pumpWidget(buildDialog(originalMedia));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(const ValueKey('gallery-detail-action-watermark')),
    );
    await tester.pump();

    expect(watermarkedMedia?.id, originalMedia.id);
  });

  testWidgets('prompt copy dialog rejects an empty selection', (tester) async {
    const projection = GalleryPromptCopyProjection(
      mainPositive: 'main',
      mainNegative: 'bad',
      characterPrompts: [
        GalleryCharacterPrompt(
          label: 'Alice',
          prompt: 'alice',
          negativePrompt: 'glasses',
        ),
      ],
    );
    GalleryPromptCopySelection? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await GalleryPromptCopyDialog.show(
                context,
                projection: projection,
                initialSelection: projection.defaultSelection(),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Main / global positive prompt'), findsOneWidget);
    expect(find.text('Main / global negative prompt'), findsOneWidget);
    expect(find.text('Character 1 positive prompt'), findsOneWidget);
    expect(find.text('Character 1 negative prompt'), findsOneWidget);

    final optionScroll = find
        .descendant(
          of: find.byKey(const ValueKey('adaptive-bottom-sheet')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final label in [
      'Main / global positive prompt',
      'Main / global negative prompt',
      'Character 1 positive prompt',
      'Character 1 negative prompt',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        80,
        scrollable: optionScroll,
      );
      await tester.tap(find.text(label));
      await tester.pump();
    }
    final copyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Copy'),
    );
    expect(copyButton.onPressed, isNull);
    expect(result, isNull);
  });

  testWidgets('moves to focused media when only focus changes', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const media = [GalleryMedia(id: 'first'), GalleryMedia(id: 'second')];
    const initialItem = GalleryItem(
      id: 7,
      workId: 'work-7',
      sourceId: GallerySourceId.aiTag,
      focusedMediaId: 'first',
      focusedMediaIndex: 0,
    );
    const updatedItem = GalleryItem(
      id: 7,
      workId: 'work-7',
      sourceId: GallerySourceId.aiTag,
      focusedMediaId: 'second',
      focusedMediaIndex: 1,
    );
    const detail = GalleryDetail(item: initialItem, media: media);
    final focusedItem = ValueNotifier<GalleryItem>(initialItem);
    addTearDown(focusedItem.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<GalleryItem>(
              valueListenable: focusedItem,
              builder: (context, item, _) => GalleryDetailDialog(
                item: item,
                detail: detail,
                isFavorited: false,
                favoriteLoading: false,
                canUseGenerationActions: false,
                labels: _labels(),
                onCopyPrompt: (_) {},
                onToggleFavorite: () async => true,
                onOpenSource: () {},
                onSendToGenerate: (_) {},
                onAddToQueue: (_) async {},
                onDownloadCurrentOriginal: (_) async {},
                onTagSearch: (_) {},
                onBlacklistChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    focusedItem.value = updatedItem;
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller?.page, 1);
  });

  testWidgets('embedded detail composes with the adaptive presenter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const item = GalleryItem(
      id: 9,
      workId: 'embedded-detail',
      sourceId: GallerySourceId.aiTag,
      title: 'Embedded detail',
    );
    const detail = GalleryDetail(item: item, media: []);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AdaptivePresenter.showForm<void>(
                  context: context,
                  showHeader: false,
                  builder: (context, _) => GalleryDetailDialog(
                    embedded: true,
                    item: item,
                    detail: detail,
                    isFavorited: false,
                    favoriteLoading: false,
                    canUseGenerationActions: false,
                    labels: _labels(),
                    onCopyPrompt: (_) {},
                    onToggleFavorite: () async => true,
                    onOpenSource: () {},
                    onSendToGenerate: (_) {},
                    onAddToQueue: (_) async {},
                    onDownloadCurrentOriginal: (_) async {},
                    onTagSearch: (_) {},
                    onBlacklistChanged: () {},
                  ),
                ),
                child: const Text('Open embedded detail'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open embedded detail'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.text('Embedded detail'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded detail uses a wide centered dialog on desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const item = GalleryItem(
      id: 10,
      workId: 'desktop-embedded-detail',
      sourceId: GallerySourceId.aiTag,
      title: 'Desktop embedded detail',
    );
    const detail = GalleryDetail(item: item, media: []);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AdaptivePresenter.showForm<void>(
                  context: context,
                  showHeader: false,
                  dialogWidth: 960,
                  builder: (context, _) => GalleryDetailDialog(
                    embedded: true,
                    item: item,
                    detail: detail,
                    isFavorited: false,
                    favoriteLoading: false,
                    canUseGenerationActions: false,
                    labels: _labels(),
                    onCopyPrompt: (_) {},
                    onToggleFavorite: () async => true,
                    onOpenSource: () {},
                    onSendToGenerate: (_) {},
                    onAddToQueue: (_) async {},
                    onDownloadCurrentOriginal: (_) async {},
                    onTagSearch: (_) {},
                    onBlacklistChanged: () {},
                  ),
                ),
                child: const Text('Open desktop embedded detail'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open desktop embedded detail'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(surface, findsOneWidget);
    final rect = tester.getRect(surface);
    expect(rect.width, 960);
    expect(rect.center, const Offset(800, 450));
    expect(find.text('Desktop embedded detail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GalleryDetailDialogLabels _labels({String sourceName = 'Codex'}) {
  return GalleryDetailDialogLabels(
    sourceName: sourceName,
    untitled: 'Untitled',
    codex: 'Codex',
    category: 'Category',
    positivePrompt: 'Positive',
    negativePrompt: 'Negative',
    characterPrompts: 'Characters',
    note: 'Note',
    rawTags: 'Raw tags',
    artists: 'Artists',
    characters: 'Characters',
    copyrights: 'Copyrights',
    general: 'General',
    metadata: 'Metadata',
    tagContextMenuTooltip: 'Tag actions',
    outputFilteredTagTooltip: 'Output filtered',
    author: 'Author',
    imageFile: 'Image file',
    originalFile: 'Original file',
    declaredSource: 'Data source',
    contributors: 'Contributors',
    noImage: 'No image',
    noImageDescription: 'This entry is text only.',
    imageLoadFailed: 'Image failed',
    retry: 'Retry',
    zoomHint: 'Zoom',
    copyPrompt: 'Copy prompt',
    addFavorite: 'Add favorite',
    removeFavorite: 'Remove favorite',
    openSource: 'Open source',
    sendToGenerate: 'Generate',
    addToQueue: 'Queue',
    downloadOriginal: 'Download original',
    downloadAndWatermark: 'Download and watermark',
    previousImage: 'Previous',
    nextImage: 'Next',
    close: 'Close',
    emptyValue: 'Empty',
    imageCounter: (current, total) => '$current / $total',
    multipleImages: (count) => '$count images',
    views: 'Views',
    favoriteCount: 'Favorites',
    rating: 'Rating',
    score: 'Score',
    downloadAll: 'Download all',
    sendToReverse: 'Reverse',
  );
}
