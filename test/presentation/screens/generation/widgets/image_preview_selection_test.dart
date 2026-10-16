import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_view_state_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_card_selection_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/preview_selection_provider.dart';
import 'package:nai_launcher/presentation/providers/history_click_behavior_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/bulk_action_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_batch_scope.dart';
import 'package:nai_launcher/presentation/widgets/common/image_comparison_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_comparison_view.dart';
import 'package:nai_launcher/presentation/widgets/common/transparency_background.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/image_preview.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/preview_info_bar.dart';
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

  testWidgets('send-to-Krita is only offered where the Krita bridge exists', (
    tester,
  ) async {
    addTearDown(() => PlatformCapabilities.debugOverride = null);
    Future<SelectableImageCard> pumpOn(TargetPlatform platform) async {
      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        platform,
      );
      final container = ProviderContainer(
        overrides: [
          imageGenerationNotifierProvider.overrideWith(
            () => _SelectionImageGenerationNotifier(
              ImageGenerationState(displayImages: [_image('only', 20)]),
            ),
          ),
          shortcutConfigNotifierProvider.overrideWith(
            _DefaultShortcutConfigNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      return tester.widget<SelectableImageCard>(
        find.byType(SelectableImageCard),
      );
    }

    expect((await pumpOn(TargetPlatform.windows)).onSendToKrita, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect((await pumpOn(TargetPlatform.android)).onSendToKrita, isNull);
  });

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

  testWidgets('server scaled result keeps comparison entry', (tester) async {
    final result = _comparisonImage(
      id: 'server-scaled',
      resultWidth: 137,
      resultHeight: 200,
      sourceWidth: 100,
      sourceHeight: 146,
    );
    final container = _comparisonContainer(result);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.generation_imageComparison), findsOneWidget);
  });

  testWidgets(
    'comparison card reserves its toolbar and keeps every control reachable',
    (tester) async {
      // Chinese glyph widths in the test font are close to real ones.
      const locale = Locale('zh');
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final size in const [Size(320, 560), Size(600, 720)]) {
        for (final textScale in const [1.0, 3.0]) {
          final reason = '$size text ${textScale}x';
          final result = _comparisonImage(
            id: 'drifted',
            resultWidth: 137,
            resultHeight: 200,
            sourceWidth: 100,
            sourceHeight: 146,
          );
          final container = _comparisonContainer(result);
          container
              .read(generationImageCardSelectionProvider.notifier)
              .enterAndSelect(result.id);

          await tester.pumpWidget(
            _app(
              container,
              size: size,
              textScale: textScale,
              locale: locale,
              policy: InteractionPolicy.touchFirst,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SelectableImageCard>(find.byType(SelectableImageCard))
                .isSelected,
            isTrue,
            reason: reason,
          );
          expect(find.byType(BulkActionBar), findsOneWidget, reason: reason);

          tester
              .widget<PreviewInfoBar>(find.byType(PreviewInfoBar))
              .onComparisonChanged!(true);
          await tester.pumpAndSettle();

          expect(
            container.read(generationImageCardSelectionProvider).isActive,
            isFalse,
            reason: reason,
          );
          expect(find.byType(BulkActionBar), findsNothing, reason: reason);
          final card = tester.widget<SelectableImageCard>(
            find.byType(SelectableImageCard),
          );
          final view = tester.widget<ImageComparisonView>(
            find.byType(ImageComparisonView),
          );
          final toolbarFinder = find.byType(ImageComparisonToolbar);
          final toolbarHeight = ImageComparisonToolbar.singleRowHeight(
            tester.element(toolbarFinder),
          );
          expect(card.isSelected, isFalse, reason: reason);
          expect(card.selectionMode, isFalse, reason: reason);
          expect(card.enableSelection, isFalse, reason: reason);
          expect(card.onLongPress, isNull, reason: reason);
          expect(card.imageContentFooterHeight, toolbarHeight, reason: reason);
          expect(view.fit, BoxFit.contain, reason: reason);
          expect(view.imageBackdrop, isA<TransparencyBackgroundLayer>());

          final cardRect = tester.getRect(find.byType(SelectableImageCard));
          final toolbarRect = tester.getRect(toolbarFinder);
          final viewport = tester.getRect(
            find.byKey(const ValueKey('generation-image-comparison')),
          );
          expect(toolbarRect.height, toolbarHeight, reason: reason);
          expect(toolbarRect.bottom, closeTo(cardRect.bottom, 0.01));
          expect(
            viewport.width / viewport.height,
            closeTo(137 / 200, 0.01),
            reason: reason,
          );

          final more = tester.getRect(find.byTooltip(l10n.common_moreActions));
          final follow = tester.getRect(
            find.byKey(const ValueKey('comparison-follow-mouse')),
          );
          expect(more.bottom, lessThanOrEqualTo(toolbarRect.top + 0.01));
          expect(cardRect.contains(more.topLeft), isTrue, reason: reason);
          expect(more.overlaps(follow), isFalse, reason: reason);
          expect(tester.takeException(), isNull, reason: reason);

          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
        }
      }
    },
  );

  testWidgets('short preview widens the comparison card to fit its toolbar', (
    tester,
  ) async {
    const locale = Locale('zh');
    final l10n = await AppLocalizations.delegate.load(locale);
    for (final size in const [Size(400, 220), Size(640, 240)]) {
      for (final textScale in const [1.0, 3.0]) {
        final reason = '$size text ${textScale}x';
        final result = _comparisonImage(
          id: 'short-preview',
          resultWidth: 137,
          resultHeight: 200,
          sourceWidth: 100,
          sourceHeight: 146,
        );
        final container = _comparisonContainer(result);
        container.read(generationComparisonEnabledProvider.notifier).state =
            true;

        await tester.pumpWidget(
          _app(container, size: size, textScale: textScale, locale: locale),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: reason);

        final label = tester.renderObject<RenderParagraph>(
          find.text(l10n.comparison_followMouse),
        );
        final generated = tester.getRect(
          find.byKey(const ValueKey('generation-comparison-generated')),
        );
        expect(label.didExceedMaxLines, isFalse, reason: reason);
        expect(
          generated.width / generated.height,
          closeTo(137 / 200, 0.01),
          reason: reason,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    }
  });

  testWidgets('turning comparison on leaves batch selection', (tester) async {
    final result = _comparisonImage(
      id: 'selected-then-compared',
      resultWidth: 4,
      resultHeight: 4,
      sourceWidth: 8,
      sourceHeight: 8,
    );
    final container = _comparisonContainer(result);
    addTearDown(container.dispose);
    container
        .read(generationImageCardSelectionProvider.notifier)
        .enterAndSelect(result.id);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byType(BulkActionBar), findsOneWidget);

    await tester.tap(find.text(l10n.generation_imageComparison));
    await tester.pumpAndSettle();

    expect(
      container.read(generationImageCardSelectionProvider).isActive,
      isFalse,
    );
    expect(find.byType(BulkActionBar), findsNothing);
    expect(
      tester
          .widget<ImageCardBatchScope>(find.byType(ImageCardBatchScope))
          .targetIds,
      isEmpty,
    );
    expect(find.byType(ImageComparisonView), findsOneWidget);
    expect(container.read(generationComparisonEnabledProvider), isTrue);
  });

  testWidgets('batch selection entered elsewhere suspends comparison', (
    tester,
  ) async {
    final result = _comparisonImage(
      id: 'compared-then-selected',
      resultWidth: 4,
      resultHeight: 4,
      sourceWidth: 8,
      sourceHeight: 8,
    );
    final container = _comparisonContainer(result);
    addTearDown(container.dispose);
    container.read(generationComparisonEnabledProvider.notifier).state = true;

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    expect(find.byType(ImageComparisonView), findsOneWidget);

    // History cards and Ctrl+A share this selection with the preview.
    container
        .read(generationImageCardSelectionProvider.notifier)
        .enterAndSelect(result.id);
    await tester.pumpAndSettle();

    final card = tester.widget<SelectableImageCard>(
      find.byType(SelectableImageCard),
    );
    expect(find.byType(ImageComparisonView), findsNothing);
    expect(find.byType(BulkActionBar), findsOneWidget);
    expect(card.selectionMode, isTrue);
    expect(card.isSelected, isTrue);
    expect(card.imageContent, isNull);
    expect(card.imageContentFooterHeight, 0);
    expect(
      tester
          .widget<PreviewInfoBar>(find.byType(PreviewInfoBar))
          .comparisonEnabled,
      isFalse,
    );

    container.read(generationImageCardSelectionProvider.notifier).exit();
    await tester.pumpAndSettle();

    expect(find.byType(ImageComparisonView), findsOneWidget);
    expect(find.byType(BulkActionBar), findsNothing);
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

  testWidgets('compact single preview keeps the metadata strip tight', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        imageGenerationNotifierProvider.overrideWith(
          () => _SelectionImageGenerationNotifier(
            ImageGenerationState(displayImages: [_portraitImage()]),
          ),
        ),
        shortcutConfigNotifierProvider.overrideWith(
          _DefaultShortcutConfigNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container, size: const Size(360, 560)));
    await tester.pumpAndSettle();

    final preview = find.byType(ImagePreviewWidget);
    final card = find.byType(SelectableImageCard);
    final infoBar = find.byType(PreviewInfoBar);
    expect(infoBar, findsOneWidget);
    expect(
      tester.getRect(infoBar).top - tester.getRect(card).bottom,
      closeTo(4, 0.01),
    );
    expect(
      tester.getRect(preview).bottom - tester.getRect(infoBar).bottom,
      closeTo(4, 0.01),
    );
    expect(tester.getSize(infoBar).height, PreviewInfoBar.barHeight);
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _comparisonContainer(GeneratedImage image) {
  return ProviderContainer(
    overrides: [
      imageGenerationNotifierProvider.overrideWith(
        () => _SelectionImageGenerationNotifier(
          ImageGenerationState(displayImages: [image]),
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
}

Widget _app(
  ProviderContainer container, {
  Size size = const Size(640, 480),
  double textScale = 1,
  Locale? locale,
  InteractionPolicy? policy,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: policy == null
            ? child!
            : InteractionPolicyScope(initialPolicy: policy, child: child!),
      ),
      home: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: const ImagePreviewWidget(),
        ),
      ),
    ),
  );
}

GeneratedImage _portraitImage() {
  final image = img.Image(width: 4, height: 6);
  image.clear(img.ColorRgba8(80, 20, 30, 255));
  return GeneratedImage(
    id: 'portrait',
    bytes: Uint8List.fromList(img.encodePng(image)),
    width: 4,
    height: 6,
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
