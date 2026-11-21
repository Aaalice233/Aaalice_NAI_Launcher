import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/copy_drag_watermark_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_card_selection_provider.dart';
import 'package:nai_launcher/presentation/providers/history_click_behavior_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel/history_image_card.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel/history_panel_empty_state.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel/history_panel_header.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel/history_panel_list.dart';
import 'package:nai_launcher/presentation/selection/card_selection_scope.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_batch_scope.dart';
import 'package:nai_launcher/presentation/widgets/common/selectable_image_card.dart';

void main() {
  testWidgets('chunks rebuild the stream card without rebuilding the panel', (
    tester,
  ) async {
    final firstBytes = _png(32);
    final nextBytes = _png(128);
    final fixture = await _pumpPanel(
      tester,
      _generatingState(
        history: [_image('history')],
        slots: [
          StreamPreviewSlot(
            imageNumber: 1,
            totalImages: 4,
            progress: 0.25,
            previewBytes: firstBytes,
          ),
        ],
      ),
    );
    final panel = _panelWidgets(tester);
    final stream = tester.widget<HistoryStreamPreviewCard>(_streamFinder(0));
    final history = tester.widget<HistoryImageCard>(
      find.byType(HistoryImageCard),
    );

    fixture.notifier.emit(
      fixture.notifier.state.copyWith(
        currentImage: 1,
        progress: 0.175,
        streamPreview: nextBytes,
        streamPreviewSlots: [
          StreamPreviewSlot(
            imageNumber: 1,
            totalImages: 4,
            progress: 0.7,
            previewBytes: nextBytes,
          ),
        ],
      ),
    );
    await tester.pump();

    _expectSamePanel(tester, panel);
    expect(tester.widget(_streamFinder(0)), same(stream));
    expect(tester.widget(find.byType(HistoryImageCard)), same(history));
    final card = _streamCard(tester, 0);
    expect(card.progress, 0.7);
    expect(card.streamPreview, same(nextBytes));
    expect(find.text('70%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback frames update without rebuilding the panel', (
    tester,
  ) async {
    final firstBytes = _png(32);
    final nextBytes = _png(128);
    final placement = _placement(firstBytes);
    final nextPlacement = _placement(nextBytes);
    final fixture = await _pumpPanel(
      tester,
      _generatingState().copyWith(
        currentImage: 2,
        progress: 0.25,
        streamPreview: firstBytes,
        focusedPreviewPlacement: placement,
      ),
    );
    final panel = _panelWidgets(tester);
    final firstCard = _streamCard(tester, 0);
    expect(firstCard.currentImage, 2);
    expect(firstCard.totalImages, 4);
    expect(firstCard.progress, 0.25);
    expect(firstCard.streamPreview, same(firstBytes));
    expect(firstCard.focusedPreviewPlacement, same(placement));

    fixture.notifier.emit(
      fixture.notifier.state.copyWith(
        currentImage: 3,
        totalImages: 5,
        progress: 0.75,
        streamPreview: nextBytes,
        focusedPreviewPlacement: nextPlacement,
      ),
    );
    await tester.pump();
    _expectSamePanel(tester, panel);
    final nextCard = _streamCard(tester, 0);
    expect(nextCard.currentImage, 3);
    expect(nextCard.totalImages, 5);
    expect(nextCard.progress, 0.75);
    expect(nextCard.streamPreview, same(nextBytes));
    expect(nextCard.focusedPreviewPlacement, same(nextPlacement));

    fixture.notifier.emit(
      fixture.notifier.state.copyWith(clearFocusedPreviewPlacement: true),
    );
    await tester.pump();
    _expectSamePanel(tester, panel);
    expect(_streamCard(tester, 0).focusedPreviewPlacement, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the changed visible slot rebuilds in a multi-slot batch', (
    tester,
  ) async {
    final firstBytes = _png(32);
    final secondBytes = _png(128);
    final nextBytes = _png(240);
    final completed = _image('completed');
    final placement = _placement(firstBytes);
    final slots = [
      StreamPreviewSlot(
        imageNumber: 3,
        totalImages: 4,
        progress: 0.3,
        previewBytes: secondBytes,
      ),
      const StreamPreviewSlot(imageNumber: 1, totalImages: 4, progress: 1),
      StreamPreviewSlot(
        imageNumber: 2,
        totalImages: 4,
        progress: 0.2,
        previewBytes: firstBytes,
        focusedPreviewPlacement: placement,
      ),
    ];
    final fixture = await _pumpPanel(
      tester,
      _generatingState(currentImages: [completed], slots: slots),
    );
    final panel = _panelWidgets(tester);
    final firstCard = _streamCard(tester, 0);
    final secondCard = _streamCard(tester, 1);
    expect(firstCard.currentImage, 2);
    expect(firstCard.totalImages, 4);
    expect(firstCard.progress, 0.2);
    expect(firstCard.streamPreview, same(firstBytes));
    expect(firstCard.focusedPreviewPlacement, same(placement));
    expect(secondCard.currentImage, 3);
    expect(secondCard.totalImages, 4);
    expect(secondCard.progress, 0.3);
    expect(secondCard.streamPreview, same(secondBytes));

    fixture.notifier.emit(
      fixture.notifier.state.copyWith(
        currentImage: 3,
        progress: 0.7,
        streamPreview: nextBytes,
        streamPreviewSlots: [
          slots[2].copyWith(),
          slots[0].copyWith(progress: 0.8, previewBytes: nextBytes),
          slots[1],
        ],
      ),
    );
    await tester.pump();
    _expectSamePanel(tester, panel);
    expect(_streamCard(tester, 0), same(firstCard));
    expect(_streamCard(tester, 1).currentImage, 3);
    expect(_streamCard(tester, 1).progress, 0.8);
    expect(_streamCard(tester, 1).streamPreview, same(nextBytes));
    expect(find.text('20%'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting and stopping generation updates the list structure', (
    tester,
  ) async {
    final fixture = await _pumpPanel(
      tester,
      ImageGenerationState(history: [_image('history')]),
    );
    fixture.notifier.emit(
      fixture.notifier.state.copyWith(
        status: GenerationStatus.generating,
        currentImage: 1,
        totalImages: 1,
        batchWidth: 400,
        batchHeight: 200,
      ),
    );
    await tester.pump();
    _expectHistoryItemCount(tester, 2);
    expect(_streamCard(tester, 0).currentImage, 1);
    expect(find.byKey(const ValueKey('history')), findsOneWidget);

    fixture.notifier.emit(
      fixture.notifier.state.copyWith(
        status: GenerationStatus.cancelled,
        clearStreamPreview: true,
      ),
    );
    await tester.pump();
    _expectHistoryItemCount(tester, 1);
    expect(find.byType(HistoryStreamPreviewCard), findsNothing);
    expect(find.byKey(const ValueKey('history')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history changes update the list and prune selection without chunk churn',
    (tester) async {
      final history = _image('history');
      final added = _image('added');
      final fixture = await _pumpPanel(
        tester,
        _generatingState(history: [history]),
      );
      fixture.notifier.emit(
        fixture.notifier.state.copyWith(history: [added, history]),
      );
      await tester.pump();
      _expectHistoryItemCount(tester, 3);
      expect(find.byKey(const ValueKey('added')), findsOneWidget);
      expect(_panelWidgets(tester).header.totalCount, 2);

      fixture.container
          .read(generationImageCardSelectionProvider.notifier)
          .enterAndSelect(added.id);
      await tester.pump();
      final selected = fixture.container.read(
        generationImageCardSelectionProvider,
      );
      final panel = _panelWidgets(tester);
      fixture.notifier.emit(fixture.notifier.state.copyWith(progress: 0.5));
      await tester.pump();
      _expectSamePanel(tester, panel);
      expect(
        fixture.container.read(generationImageCardSelectionProvider),
        same(selected),
      );

      fixture.notifier.emit(
        fixture.notifier.state.copyWith(history: [history]),
      );
      await tester.pump();
      _expectHistoryItemCount(tester, 2);
      expect(find.byKey(const ValueKey('added')), findsNothing);
      expect(
        fixture.container
            .read(generationImageCardSelectionProvider)
            .selectedIds,
        isEmpty,
      );

      fixture.notifier.emit(
        fixture.notifier.state.copyWith(
          history: [],
          status: GenerationStatus.idle,
          clearStreamPreview: true,
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<HistoryPanelHeader>(find.byType(HistoryPanelHeader))
            .totalCount,
        0,
      );
      expect(find.byType(HistoryPanelList), findsNothing);
      expect(find.byType(HistoryPanelEmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a completed image replaces its slot without duplicating history',
    (tester) async {
      final completed = _image('completed');
      final history = _image('history');
      final frame = StreamPreviewFrame(bytes: _png(64));
      final fixture = await _pumpPanel(
        tester,
        _generatingState(
          history: [history],
          slots: const [
            StreamPreviewSlot(imageNumber: 1, totalImages: 4, progress: 0.5),
            StreamPreviewSlot(imageNumber: 2, totalImages: 4, progress: 0.2),
          ],
        ),
      );
      fixture.notifier.emit(
        fixture.notifier.state.copyWith(
          currentImages: [completed],
          history: [completed, history],
          completionPreviews: {completed.id: frame},
        ),
      );
      await tester.pump();
      _expectHistoryItemCount(tester, 3);
      expect(find.byKey(const ValueKey('completed')), findsOneWidget);
      expect(_streamCard(tester, 0).currentImage, 2);
      expect(_panelWidgets(tester).header.totalCount, 2);
      expect(
        tester
            .widget<SelectableImageCard>(
              find.byKey(const ValueKey('completed')),
            )
            .completionPreview,
        same(frame),
      );

      fixture.notifier.emit(
        fixture.notifier.state.copyWith(
          status: GenerationStatus.completed,
          clearStreamPreview: true,
        ),
      );
      await tester.pump();
      _expectHistoryItemCount(tester, 2);
      expect(find.byType(HistoryStreamPreviewCard), findsNothing);
      expect(find.byKey(const ValueKey('completed')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('slot count and image numbers update the list', (tester) async {
    const firstSlot = StreamPreviewSlot(
      imageNumber: 1,
      totalImages: 4,
      progress: 0.2,
    );
    const secondSlot = StreamPreviewSlot(
      imageNumber: 2,
      totalImages: 4,
      progress: 0.3,
    );
    final fixture = await _pumpPanel(
      tester,
      _generatingState(history: [_image('history')], slots: [firstSlot]),
    );
    fixture.notifier.emit(
      fixture.notifier.state.copyWith(
        streamPreviewSlots: [firstSlot, secondSlot],
      ),
    );
    await tester.pump();
    _expectHistoryItemCount(tester, 3);
    expect(_streamCard(tester, 1).currentImage, 2);

    fixture.notifier.emit(
      fixture.notifier.state.copyWith(
        streamPreviewSlots: [firstSlot, secondSlot.copyWith(imageNumber: 4)],
      ),
    );
    await tester.pump();
    _expectHistoryItemCount(tester, 3);
    expect(_streamCard(tester, 1).currentImage, 4);

    fixture.notifier.emit(
      fixture.notifier.state.copyWith(streamPreviewSlots: [firstSlot]),
    );
    await tester.pump();
    _expectHistoryItemCount(tester, 2);
    expect(find.byType(HistoryStreamPreviewCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion previews and batch dimensions update their cards', (
    tester,
  ) async {
    final completed = _image('completed');
    final fixture = await _pumpPanel(
      tester,
      _generatingState(
        currentImages: [completed],
        slots: const [
          StreamPreviewSlot(imageNumber: 2, totalImages: 4, progress: 0.2),
        ],
      ),
    );
    final frame = StreamPreviewFrame(bytes: _png(64));
    fixture.notifier.emit(
      fixture.notifier.state.copyWith(
        completionPreviews: {completed.id: frame},
      ),
    );
    await tester.pump();
    _expectHistoryItemCount(tester, 2);
    expect(
      tester
          .widget<SelectableImageCard>(find.byKey(const ValueKey('completed')))
          .completionPreview,
      same(frame),
    );

    fixture.notifier.emit(
      fixture.notifier.state.copyWith(batchWidth: 800, batchHeight: 400),
    );
    await tester.pump();
    _expectHistoryItemCount(tester, 2);
    expect(_streamCard(tester, 0).imageWidth, 800);
    expect(_streamCard(tester, 0).imageHeight, 400);
    expect(tester.takeException(), isNull);
  });
}

typedef _PanelWidgets = ({
  ImageCardBatchScope batch,
  CardSelectionScope selection,
  HistoryPanelHeader header,
  HistoryPanelList list,
});

_PanelWidgets _panelWidgets(WidgetTester tester) => (
  batch: tester.widget(find.byType(ImageCardBatchScope)),
  selection: tester.widget(find.byType(CardSelectionScope)),
  header: tester.widget(find.byType(HistoryPanelHeader)),
  list: tester.widget(find.byType(HistoryPanelList)),
);

void _expectSamePanel(WidgetTester tester, _PanelWidgets previous) {
  final current = _panelWidgets(tester);
  expect(current.batch, same(previous.batch));
  expect(current.selection, same(previous.selection));
  expect(current.header, same(previous.header));
  expect(current.list, same(previous.list));
}

void _expectHistoryItemCount(WidgetTester tester, int itemCount) {
  expect(
    tester
        .widget<ListView>(find.byType(ListView))
        .childrenDelegate
        .estimatedChildCount,
    itemCount,
  );
}

Finder _streamFinder(int index) => find.byWidgetPredicate(
  (widget) =>
      widget is HistoryStreamPreviewCard && widget.generationIndex == index,
);

SelectableImageCard _streamCard(WidgetTester tester, int index) =>
    tester.widget(
      find.descendant(
        of: _streamFinder(index),
        matching: find.byType(SelectableImageCard),
      ),
    );

Future<
  ({ProviderContainer container, _ControllableImageGenerationNotifier notifier})
>
_pumpPanel(WidgetTester tester, ImageGenerationState initial) async {
  final notifier = _ControllableImageGenerationNotifier(initial);
  final preparation = _ReadySharePreparation();
  final container = ProviderContainer(
    overrides: [
      imageGenerationNotifierProvider.overrideWith(() => notifier),
      copyDragWatermarkProvider.overrideWithValue(null),
      localStorageServiceProvider.overrideWith((_) => _HistoryStorage()),
      shortcutConfigNotifierProvider.overrideWith(_HistoryShortcuts.new),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    preparation.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 640,
            child: HistoryPanel(sharePreparationService: preparation),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (container: container, notifier: notifier);
}

class _ControllableImageGenerationNotifier extends ImageGenerationNotifier {
  _ControllableImageGenerationNotifier(this.initial);
  final ImageGenerationState initial;

  @override
  ImageGenerationState build() => initial;

  void emit(ImageGenerationState next) => state = next;
}

class _HistoryStorage extends LocalStorageService {
  @override
  String getHistoryClickBehavior() =>
      HistoryClickBehavior.openDetail.storageValue;
}

class _HistoryShortcuts extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _ReadySharePreparation extends ShareImagePreparationService {
  @override
  ShareImagePreparationSnapshot snapshotFor(
    String imageId, {
    required bool stripMetadata,
    ShareImageTransform? transform,
  }) => ShareImagePreparationSnapshot(
    imageId: imageId,
    stripMetadata: stripMetadata,
    status: ShareImagePreparationStatus.ready,
    file: File('$imageId.png'),
  );

  @override
  void enqueue({
    required String imageId,
    required Uint8List imageBytes,
    required String fileName,
    required bool stripMetadata,
    String? sourceFilePath,
    ShareImageTransform? transform,
  }) {}

  @override
  Future<void> retainHistoryImageIds(Set<String> imageIds) async {}
}

ImageGenerationState _generatingState({
  List<GeneratedImage> history = const [],
  List<GeneratedImage> currentImages = const [],
  List<StreamPreviewSlot> slots = const [],
}) => ImageGenerationState(
  status: GenerationStatus.generating,
  history: history,
  currentImages: currentImages,
  streamPreviewSlots: slots,
  currentImage: 1,
  totalImages: 4,
  batchWidth: 400,
  batchHeight: 200,
);

GeneratedImage _image(String id) =>
    GeneratedImage(id: id, bytes: _png(32), width: 400, height: 200);

Uint8List _png(int red) {
  final image = img.Image(width: 4, height: 4, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(red, 0, 0, 255));
  return Uint8List.fromList(img.encodePng(image));
}

FocusedStreamPreviewPlacement _placement(Uint8List source) =>
    FocusedStreamPreviewPlacement(
      sourceImage: source,
      xPercent: 0,
      yPercent: 0,
      widthPercent: 1,
      heightPercent: 1,
    );
