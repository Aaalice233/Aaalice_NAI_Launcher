import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/quick_tag_cloud_detail_dialog.dart';

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
        tags: const ['tag'],
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
        characterPrompts: const [
          GalleryCharacterPrompt(
            label: 'Character',
            prompt: 'character prompt',
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
        MaterialApp(
          home: Scaffold(
            body: QuickTagCloudDetailDialog(
              item: item,
              detail: detail,
              isFavorited: false,
              favoriteLoading: false,
              labels: _labels(),
              onCopyPrompt: () => copyCount++,
              onCopyNegativePrompt: () {},
              onCopyCharacter: (_) => characterCopyCount++,
              onCopyAll: () {},
              onToggleFavorite: () async => favoriteSucceeds,
              onOpenSource: () {},
              onSendToGenerate: () => sentToGenerate = true,
              onAddToQueue: () async => addedToQueue = true,
              onDownloadCurrentOriginal: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Text entry'), findsOneWidget);
      expect(find.text('No image'), findsOneWidget);
      expect(find.text('positive prompt'), findsOneWidget);
      expect(find.text('negative prompt'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Contributor · maintainer'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Contributor · maintainer'), findsOneWidget);
      expect(find.text('Original dataset'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byTooltip('Add favorite'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      favoriteSucceeds = true;
      await tester.tap(find.byTooltip('Add favorite'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Copy positive'));
      await tester.tap(find.byTooltip('Copy this character'));
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Queue'));
      await tester.pumpAndSettle();
      expect(copyCount, 1);
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
      MaterialApp(
        home: Scaffold(
          body: QuickTagCloudDetailDialog(
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
}

QuickTagCloudDetailDialogLabels _labels() {
  return QuickTagCloudDetailDialogLabels(
    sourceName: 'Codex',
    untitled: 'Untitled',
    codex: 'Codex',
    category: 'Category',
    positivePrompt: 'Positive',
    negativePrompt: 'Negative',
    characterPrompts: 'Characters',
    note: 'Note',
    rawTags: 'Raw tags',
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
  );
}
