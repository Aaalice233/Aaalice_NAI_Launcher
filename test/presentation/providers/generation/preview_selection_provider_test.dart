import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/generation/preview_selection_provider.dart';
import 'package:nai_launcher/presentation/providers/history_click_behavior_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

class _TestImageGenerationNotifier extends ImageGenerationNotifier {
  _TestImageGenerationNotifier(this.initialState);

  final ImageGenerationState initialState;

  @override
  ImageGenerationState build() => initialState;

  void replace(ImageGenerationState value) => state = value;
}

class _TestHistoryClickBehaviorNotifier extends HistoryClickBehaviorNotifier {
  _TestHistoryClickBehaviorNotifier(this.initialBehavior);

  final HistoryClickBehavior initialBehavior;

  @override
  HistoryClickBehavior build() => initialBehavior;

  void replace(HistoryClickBehavior value) => state = value;
}

void main() {
  group('ImageGenerationStateImages', () {
    test('merges current and history in panel order with id deduplication', () {
      final currentA = _image('a');
      final currentB = _image('b');
      final historyC = _image('c');
      final state = ImageGenerationState(
        currentImages: [currentA, currentB],
        history: [currentB, historyC, currentA],
      );

      expect(
        state.mergedPanelImages.map((image) => image.id),
        orderedEquals(const ['a', 'b', 'c']),
      );
    });

    test(
      'findImageById includes display-only images after history clearing',
      () {
        final displayOnly = _image('display');
        final state = ImageGenerationState(displayImages: [displayOnly]);

        expect(state.findImageById('display'), same(displayOnly));
        expect(state.findImageById('missing'), isNull);
      },
    );

    test('detailSequenceFor covers merged, display, and fallback branches', () {
      final merged = _image('merged');
      final history = _image('history');
      final display = _image('display');
      final detached = _image('detached');
      final state = ImageGenerationState(
        currentImages: [merged],
        history: [history],
        displayImages: [display],
      );

      expect(
        state.detailSequenceFor(history).map((image) => image.id),
        orderedEquals(const ['merged', 'history']),
      );
      expect(state.detailSequenceFor(display), [display]);
      expect(state.detailSequenceFor(detached), [detached]);
    });
  });

  group('GenerationPreviewSelection', () {
    late ProviderContainer container;
    late _TestImageGenerationNotifier generationNotifier;
    late _TestHistoryClickBehaviorNotifier behaviorNotifier;

    setUp(() {
      final initialState = ImageGenerationState(
        currentImages: [_image('a'), _image('b')],
        history: [_image('b'), _image('c')],
      );
      container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(
            () =>
                generationNotifier = _TestImageGenerationNotifier(initialState),
          ),
          historyClickBehaviorNotifierProvider.overrideWith(
            () => behaviorNotifier = _TestHistoryClickBehaviorNotifier(
              HistoryClickBehavior.selectPreview,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(generationPreviewSelectionProvider);
    });

    test('selects, clears, and clamps navigation boundaries', () {
      final notifier = container.read(
        generationPreviewSelectionProvider.notifier,
      );

      notifier.selectNext();
      expect(container.read(generationPreviewSelectionProvider), 'a');
      notifier.selectNext();
      expect(container.read(generationPreviewSelectionProvider), 'b');
      notifier.selectNext();
      notifier.selectNext();
      expect(container.read(generationPreviewSelectionProvider), 'c');
      notifier.selectPrevious();
      expect(container.read(generationPreviewSelectionProvider), 'b');
      notifier.clear();
      expect(container.read(generationPreviewSelectionProvider), isNull);
    });

    test('restarts from first image when the selected id disappears', () {
      final notifier = container.read(
        generationPreviewSelectionProvider.notifier,
      );
      notifier.select('c');
      generationNotifier.replace(
        ImageGenerationState(currentImages: [_image('x')]),
      );

      notifier.selectNext();
      expect(container.read(generationPreviewSelectionProvider), 'x');
    });

    test('navigation is a no-op for an empty merged list', () {
      generationNotifier.replace(const ImageGenerationState());
      final notifier = container.read(
        generationPreviewSelectionProvider.notifier,
      );

      notifier.selectNext();
      notifier.selectPrevious();
      expect(container.read(generationPreviewSelectionProvider), isNull);
    });

    test('generation start clears the selection', () {
      final notifier = container.read(
        generationPreviewSelectionProvider.notifier,
      )..select('a');

      generationNotifier.replace(
        ImageGenerationState(
          status: GenerationStatus.generating,
          currentImages: [_image('a')],
        ),
      );

      expect(container.read(generationPreviewSelectionProvider), isNull);
      expect(notifier, isNotNull);
    });

    test('new display result clears a stale history selection', () {
      final notifier = container.read(
        generationPreviewSelectionProvider.notifier,
      )..select('c');
      final result = _image('x');

      generationNotifier.replace(
        ImageGenerationState(
          currentImages: [result],
          history: [result, _image('c')],
          displayImages: [result],
        ),
      );

      expect(container.read(generationPreviewSelectionProvider), isNull);
      expect(notifier, isNotNull);
    });

    test('unrelated updates preserve the selected history image', () {
      container.read(generationPreviewSelectionProvider.notifier).select('c');
      final current = container.read(imageGenerationNotifierProvider);

      generationNotifier.replace(current.copyWith(progress: 0.5));

      expect(container.read(generationPreviewSelectionProvider), 'c');
    });

    test('display replacement preserves a selection it still contains', () {
      container.read(generationPreviewSelectionProvider.notifier).select('c');
      final selected = _image('c');

      generationNotifier.replace(
        ImageGenerationState(
          currentImages: [selected],
          history: [selected],
          displayImages: [selected],
        ),
      );

      expect(container.read(generationPreviewSelectionProvider), 'c');
    });

    test(
      'switching to classic clears selection and linked mode can resume',
      () {
        final notifier = container.read(
          generationPreviewSelectionProvider.notifier,
        )..select('a');

        behaviorNotifier.replace(HistoryClickBehavior.openDetail);
        expect(container.read(generationPreviewSelectionProvider), isNull);

        behaviorNotifier.replace(HistoryClickBehavior.selectPreview);
        notifier.selectNext();
        expect(container.read(generationPreviewSelectionProvider), 'a');
      },
    );
  });
}

GeneratedImage _image(
  String id, {
  GeneratedImageKind kind = GeneratedImageKind.completed,
}) {
  return GeneratedImage(
    id: id,
    bytes: Uint8List.fromList([id.codeUnitAt(0)]),
    width: 1,
    height: 1,
    kind: kind,
  );
}
