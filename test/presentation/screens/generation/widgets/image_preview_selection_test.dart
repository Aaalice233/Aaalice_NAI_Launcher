import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/preview_selection_provider.dart';
import 'package:nai_launcher/presentation/providers/history_click_behavior_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/image_comparison_view.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/image_preview.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:nai_launcher/presentation/widgets/common/selectable_image_card.dart';

class _SelectionImageGenerationNotifier extends ImageGenerationNotifier {
  _SelectionImageGenerationNotifier(this.initialState);

  final ImageGenerationState initialState;

  @override
  ImageGenerationState build() => initialState;

  void replace(ImageGenerationState value) => state = value;
}

class _LinkedHistoryBehaviorNotifier extends HistoryClickBehaviorNotifier {
  @override
  HistoryClickBehavior build() => HistoryClickBehavior.selectPreview;
}

class _DefaultShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

void main() {
  testWidgets(
    'selected history image replaces display grid and missing id falls back',
    (tester) async {
      final displayA = _image('display-a', 20);
      final displayB = _image('display-b', 40);
      final history = _image('history', 80);
      final initialState = ImageGenerationState(
        history: [history],
        displayImages: [displayA, displayB],
      );
      final container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(
            () => _SelectionImageGenerationNotifier(initialState),
          ),
          historyClickBehaviorNotifierProvider.overrideWith(
            _LinkedHistoryBehaviorNotifier.new,
          ),
          shortcutConfigNotifierProvider.overrideWith(
            _DefaultShortcutConfigNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(generationPreviewSelectionProvider.notifier)
          .select(history.id);

      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();

      expect(find.byType(SelectableImageCard), findsOneWidget);
      expect(
        tester
            .widget<SelectableImageCard>(find.byType(SelectableImageCard))
            .imageBytes,
        same(history.bytes),
      );

      container
          .read(generationPreviewSelectionProvider.notifier)
          .select('missing');
      await tester.pumpAndSettle();

      expect(find.byType(SelectableImageCard), findsNWidgets(2));
    },
  );

  testWidgets('generating state keeps priority over linked selection', (
    tester,
  ) async {
    final history = _image('history', 80);
    late _SelectionImageGenerationNotifier generationNotifier;
    final container = ProviderContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          () => generationNotifier = _SelectionImageGenerationNotifier(
            ImageGenerationState(history: [history]),
          ),
        ),
        historyClickBehaviorNotifierProvider.overrideWith(
          _LinkedHistoryBehaviorNotifier.new,
        ),
        shortcutConfigNotifierProvider.overrideWith(
          _DefaultShortcutConfigNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(generationPreviewSelectionProvider.notifier)
        .select(history.id);
    generationNotifier.replace(
      const ImageGenerationState(
        status: GenerationStatus.generating,
        currentImage: 1,
        totalImages: 1,
        batchWidth: 64,
        batchHeight: 64,
      ),
    );

    await tester.pumpWidget(_app(container));
    await tester.pump();

    final card = tester.widget<SelectableImageCard>(
      find.byType(SelectableImageCard),
    );
    expect(card.isGenerating, isTrue);
  });

  testWidgets(
    'completed card opened during batch generation uses current batch images',
    (tester) async {
      final oldDisplay = _image('old-display', 20);
      final currentA = _image('current-a', 80);
      final currentB = _image('current-b', 120);
      final container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(
            () => _SelectionImageGenerationNotifier(
              ImageGenerationState(
                status: GenerationStatus.generating,
                currentImages: [currentA, currentB],
                displayImages: [oldDisplay],
                currentImage: 3,
                totalImages: 3,
                batchWidth: 4,
                batchHeight: 4,
              ),
            ),
          ),
          historyClickBehaviorNotifierProvider.overrideWith(
            _LinkedHistoryBehaviorNotifier.new,
          ),
          shortcutConfigNotifierProvider.overrideWith(
            _DefaultShortcutConfigNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pump();

      final currentBCard = find.byWidgetPredicate(
        (widget) =>
            widget is SelectableImageCard &&
            identical(widget.imageBytes, currentB.bytes),
      );
      expect(currentBCard, findsOneWidget);

      await tester.tap(currentBCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final viewer = tester.widget<ImageDetailViewer>(
        find.byType(ImageDetailViewer),
      );
      expect(
        viewer.images.map((image) => image.identifier),
        orderedEquals(['current-a', 'current-b']),
      );
      expect(viewer.initialIndex, 1);
    },
  );

  testWidgets('compatible sourced result exposes and toggles comparison', (
    tester,
  ) async {
    final result = _comparisonImage(
      id: 'compatible',
      resultWidth: 4,
      resultHeight: 4,
      sourceWidth: 8,
      sourceHeight: 8,
    );
    final container = ProviderContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          () => _SelectionImageGenerationNotifier(
            ImageGenerationState(displayImages: [result]),
          ),
        ),
        historyClickBehaviorNotifierProvider.overrideWith(
          _LinkedHistoryBehaviorNotifier.new,
        ),
        shortcutConfigNotifierProvider.overrideWith(
          _DefaultShortcutConfigNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.generation_imageComparison), findsOneWidget);
    expect(find.byType(ImageComparisonView), findsNothing);
    final comparisonInkWell = find.ancestor(
      of: find.text(l10n.generation_imageComparison),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(comparisonInkWell).height, greaterThanOrEqualTo(44));

    await tester.tap(find.text(l10n.generation_imageComparison));
    await tester.pump();

    expect(find.byType(ImageComparisonView), findsOneWidget);
    expect(
      tester
          .widget<SelectableImageCard>(find.byType(SelectableImageCard))
          .imageContent,
      isA<ImageComparisonView>(),
    );
  });

  testWidgets('missing or mismatched source keeps final-only preview', (
    tester,
  ) async {
    final mismatch = _comparisonImage(
      id: 'mismatch',
      resultWidth: 4,
      resultHeight: 4,
      sourceWidth: 8,
      sourceHeight: 4,
    );
    final container = ProviderContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          () => _SelectionImageGenerationNotifier(
            ImageGenerationState(displayImages: [mismatch]),
          ),
        ),
        historyClickBehaviorNotifierProvider.overrideWith(
          _LinkedHistoryBehaviorNotifier.new,
        ),
        shortcutConfigNotifierProvider.overrideWith(
          _DefaultShortcutConfigNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.generation_imageComparison), findsNothing);
    expect(find.byType(ImageComparisonView), findsNothing);
    expect(
      tester
          .widget<SelectableImageCard>(find.byType(SelectableImageCard))
          .imageContent,
      isNull,
    );
  });

  testWidgets('streaming unsupported error explains how to retry', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          () => _SelectionImageGenerationNotifier(
            const ImageGenerationState(
              status: GenerationStatus.error,
              errorMessage:
                  'API_ERROR_400|Streaming is not supported by this site',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.generation_streamingUnsupported), findsOneWidget);
    expect(find.text(l10n.generation_streamingUnsupportedHint), findsOneWidget);
    expect(
      l10n.generation_streamingUnsupportedHint,
      contains(l10n.settings_generationStreamPreview),
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(width: 640, height: 480, child: ImagePreviewWidget()),
      ),
    ),
  );
}

GeneratedImage _image(String id, int red) {
  final image = img.Image(width: 4, height: 4);
  image.clear(img.ColorRgba8(red, 20, 30, 255));
  return GeneratedImage(
    id: id,
    bytes: Uint8List.fromList(img.encodePng(image)),
    width: 4,
    height: 4,
  );
}

GeneratedImage _comparisonImage({
  required String id,
  required int resultWidth,
  required int resultHeight,
  required int sourceWidth,
  required int sourceHeight,
}) {
  final result = img.Image(width: resultWidth, height: resultHeight)
    ..clear(img.ColorRgba8(180, 20, 30, 255));
  final source = img.Image(width: sourceWidth, height: sourceHeight)
    ..clear(img.ColorRgba8(20, 180, 30, 255));
  return GeneratedImage(
    id: id,
    bytes: Uint8List.fromList(img.encodePng(result)),
    width: resultWidth,
    height: resultHeight,
    comparisonSource: ImageComparisonSource.fromBytes(
      Uint8List.fromList(img.encodePng(source)),
    ),
  );
}
