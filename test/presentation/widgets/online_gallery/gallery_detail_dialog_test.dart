import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_detail_dialog.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_detail_overview_card.dart';
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
      var negativeCopyCount = 0;
      var characterCopyCount = 0;
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
                labels: _labels(),
                onCopyPrompt: () => copyCount++,
                onCopyNegativePrompt: () => negativeCopyCount++,
                onCopyCharacter: (_) => characterCopyCount++,
                onCopyAll: () {},
                onToggleFavorite: () async => favoriteSucceeds,
                onOpenSource: () {},
                onSendToGenerate: () => sentToGenerate = true,
                onAddToQueue: () async => addedToQueue = true,
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
      final copyPositive = find.descendant(
        of: infoList,
        matching: find.byTooltip('Copy positive'),
      );
      final infoScrollable = find.ancestor(
        of: copyPositive,
        matching: find.byType(Scrollable),
      );
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

      await tester.scrollUntilVisible(
        copyPositive,
        -180,
        scrollable: infoScrollable,
      );
      await tester.ensureVisible(copyPositive);
      await tester.pumpAndSettle();
      expect(copyPositive.hitTestable(), findsOneWidget);
      await tester.tap(copyPositive);
      await tester.tap(find.byTooltip('Copy negative'));
      await tester.tap(find.byTooltip('Copy this character'));
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Queue'));
      await tester.pumpAndSettle();
      expect(copyCount, 1);
      expect(negativeCopyCount, 1);
      expect(characterCopyCount, 1);
      expect(sentToGenerate, isTrue);
      expect(addedToQueue, isTrue);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Download original'),
            )
            .onPressed,
        isNull,
      );
    },
  );

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
              labels: _labels(),
              onCopyPrompt: () {},
              onCopyNegativePrompt: () {},
              onCopyCharacter: (_) {},
              onCopyAll: () {},
              onToggleFavorite: () async => true,
              onOpenSource: () {},
              onSendToGenerate: () {},
              onAddToQueue: () async {},
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
    expect(find.widgetWithText(OutlinedButton, 'Reverse'), findsNothing);
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
              labels: _labels(),
              onCopyPrompt: () {},
              onCopyNegativePrompt: () {},
              onCopyCharacter: (_) {},
              onCopyAll: () {},
              onToggleFavorite: () async => true,
              onOpenSource: () {},
              onSendToGenerate: () {},
              onAddToQueue: () async {},
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
    expect(find.text('Copy'), findsNWidgets(2));
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

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GalleryDetailDialog(
              item: item,
              detail: GalleryDetail(item: item, media: [media]),
              isFavorited: false,
              favoriteLoading: false,
              labels: _labels(),
              onCopyPrompt: () {},
              onCopyNegativePrompt: () {},
              onCopyCharacter: (_) {},
              onCopyAll: () {},
              onToggleFavorite: () async => true,
              onOpenSource: () {},
              onSendToGenerate: () {},
              onAddToQueue: () async {},
              onDownloadCurrentOriginal: (_) async {},
              onTagSearch: (_) {},
              onBlacklistChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('832 × 1216 · WEBP'), findsOneWidget);
    expect(find.text('book/preview-only.webp'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Download original'),
          )
          .onPressed,
      isNull,
    );
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
                labels: _labels(),
                onCopyPrompt: () {},
                onCopyNegativePrompt: () {},
                onCopyCharacter: (_) {},
                onCopyAll: () {},
                onToggleFavorite: () async => true,
                onOpenSource: () {},
                onSendToGenerate: () {},
                onAddToQueue: () async {},
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
}

GalleryDetailDialogLabels _labels() {
  return GalleryDetailDialogLabels(
    sourceName: 'Codex',
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
    copyActions: 'Copy',
    copyPositive: 'Copy positive',
    copyNegative: 'Copy negative',
    copyCharacter: 'Copy this character',
    copyAll: 'Copy all',
    addFavorite: 'Add favorite',
    removeFavorite: 'Remove favorite',
    openSource: 'Open source',
    sendToGenerate: 'Generate',
    addToQueue: 'Queue',
    downloadOriginal: 'Download original',
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
    copyMetadata: 'Copy metadata',
    downloadAll: 'Download all',
    sendToReverse: 'Reverse',
    copyArtistChain: 'Copy artist chain',
    copyFullPrompt: 'Copy full prompt',
    copyRawArtistFragments: 'Copy raw artists',
    noArtistChain: 'No artist chain',
  );
}
