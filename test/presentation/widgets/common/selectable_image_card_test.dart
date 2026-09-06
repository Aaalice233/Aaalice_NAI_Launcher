import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/presentation/providers/copy_drag_watermark_provider.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/data/models/watermark/watermark_settings.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/watermark_settings_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/image_preview.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_memory_image.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_actions.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_hover_motion.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_stream_preview.dart';
import 'package:nai_launcher/presentation/widgets/common/pro_context_menu.dart';
import 'package:nai_launcher/presentation/widgets/common/selectable_image_card.dart';
import 'package:nai_launcher/presentation/widgets/common/transparency_background.dart';

void main() {
  late Directory hiveTempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_selectable_card_hive_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  tearDown(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  testWidgets('hover actions should expose inpaint and upscale shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCardApp());

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.byType(SelectableImageCard)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('局部重绘'), findsOneWidget);
    expect(find.byTooltip('放大'), findsOneWidget);
    expect(find.byTooltip('DLSSNR 图像增强…'), findsOneWidget);
  });

  testWidgets('agent reference action is shown on hover only when available', (
    tester,
  ) async {
    var addCount = 0;
    await tester.pumpWidget(_buildCardApp(onAddToAgent: () => addCount++));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.byType(SelectableImageCard)));
    await tester.pumpAndSettle();

    final action = find.byTooltip('发送到智能体');
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(addCount, 1);

    await tester.pumpWidget(_buildCardApp());
    await tester.pumpAndSettle();
    expect(find.byTooltip('发送到智能体'), findsNothing);
  });

  testWidgets('generating cards settle decorative motion when disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCardApp(isGenerating: true, disableAnimations: true),
    );

    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
    for (final indicator in tester.widgetList<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    )) {
      expect(indicator.value, isNotNull);
    }
  });

  testWidgets('stream preview progress stays legible over image content', (
    tester,
  ) async {
    final preview = Uint8List.fromList(
      img.encodePng(img.Image(width: 32, height: 32)),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox.square(
              dimension: 160,
              child: SelectableImageCard(
                isGenerating: true,
                progress: 0.42,
                currentImage: 1,
                totalImages: 1,
                streamPreview: preview,
                imageWidth: 32,
                imageHeight: 32,
                enableSelection: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byKey(const ValueKey('stream-generation-progress-ring')),
    );
    final count = tester.widget<Text>(
      find.byKey(const ValueKey('stream-generation-progress-count')),
    );
    final percent = tester.widget<Text>(
      find.byKey(const ValueKey('stream-generation-progress-percent')),
    );
    expect(indicator.color, Colors.white);
    expect(indicator.backgroundColor, Colors.white.withValues(alpha: 0.24));
    expect(count.style?.color, Colors.white);
    expect(percent.style?.color, Colors.white);
    expect(percent.style?.shadows, isNotEmpty);
  });

  testWidgets('completed image cards use the shared hover scale', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCardApp());

    final motion = find.byType(ImageCardHoverMotion);
    expect(motion, findsOneWidget);
    expect(tester.widget<ImageCardHoverMotion>(motion).hovered, isFalse);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.byType(SelectableImageCard)));
    await tester.pump();

    expect(tester.widget<ImageCardHoverMotion>(motion).hovered, isTrue);
    expect(
      tester
          .widget<AnimatedScale>(
            find.descendant(of: motion, matching: find.byType(AnimatedScale)),
          )
          .scale,
      ImageCardHoverMotion.hoverScale,
    );
  });

  testWidgets('context menu should expose inpaint and upscale shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCardApp());

    final center = tester.getCenter(find.byType(SelectableImageCard));
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('局部重绘'), findsOneWidget);
    expect(find.text('放大'), findsOneWidget);
  });

  testWidgets('context menu closes before invoking route launching actions', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      _buildCardApp(
        navigatorKey: navigatorKey,
        onInpaint: () {
          navigatorKey.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('inpaint route')),
            ),
          );
        },
      ),
    );

    final center = tester.getCenter(find.byType(SelectableImageCard));
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    addTearDown(gesture.removePointer);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('局部重绘'));
    await tester.pumpAndSettle();

    expect(find.text('inpaint route'), findsOneWidget);
    expect(find.byType(ProContextMenu), findsNothing);
  });

  testWidgets('hover actions should expose generation destination shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCardApp(
        onReversePrompt: _noop,
        onImageToImage: _noop,
        onVibeTransfer: _noop,
        onPreciseReference: _noop,
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.byType(SelectableImageCard)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('反推'), findsOneWidget);
    expect(find.byTooltip('图生图'), findsOneWidget);
    expect(find.byTooltip('风格迁移'), findsOneWidget);
    expect(find.byTooltip('精准参考'), findsOneWidget);
  });

  testWidgets('context menu should expose generation destination shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCardApp(
        onReversePrompt: _noop,
        onImageToImage: _noop,
        onVibeTransfer: _noop,
        onPreciseReference: _noop,
      ),
    );

    final center = tester.getCenter(find.byType(SelectableImageCard));
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    addTearDown(gesture.removePointer);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('反推'), findsOneWidget);
    expect(find.text('图生图'), findsOneWidget);
    expect(find.text('风格迁移'), findsOneWidget);
    expect(find.text('精准参考'), findsOneWidget);
  });

  testWidgets(
    'generation preview hover exposes history destination shortcuts',
    (tester) async {
      final container = _createContainerWithPreviewImage();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildPreviewApp(container));
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.byType(SelectableImageCard)));
      await tester.pumpAndSettle();

      expect(find.byTooltip('反推'), findsOneWidget);
      expect(find.byTooltip('图生图'), findsOneWidget);
      expect(find.byTooltip('风格迁移'), findsOneWidget);
      expect(find.byTooltip('精准参考'), findsOneWidget);
    },
  );

  testWidgets(
    'generation preview context menu exposes history destination shortcuts',
    (tester) async {
      final container = _createContainerWithPreviewImage(
        watermarkEnabled: true,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildPreviewApp(container));
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(SelectableImageCard));
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      addTearDown(gesture.removePointer);
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('反推'), findsOneWidget);
      expect(find.text('图生图'), findsOneWidget);
      expect(find.text('风格迁移'), findsOneWidget);
      expect(find.text('精准参考'), findsOneWidget);
      expect(find.text('创建水印副本…'), findsOneWidget);
      expect(find.text('发送到智能体'), findsOneWidget);
      expect(find.byType(ProContextMenu), findsOneWidget);
      expect(
        find.byType(PopupMenuItem<bool>, skipOffstage: false),
        findsNothing,
      );

      final menu = tester.widget<ProContextMenu>(find.byType(ProContextMenu));
      final itemIds = menu.items
          .where((item) => !item.isDivider)
          .map((item) => item.id)
          .toList();
      final addToAgentIndex = itemIds.indexOf(
        ImageCardActionId.addToAgent.name,
      );
      final shareDiscordIndex = itemIds.indexOf(
        ImageCardActionId.shareDiscord.name,
      );
      expect(addToAgentIndex, greaterThanOrEqualTo(0));
      expect(shareDiscordIndex, addToAgentIndex + 1);
    },
  );

  testWidgets(
    'generation preview right-click copy writes the displayed image',
    (tester) async {
      Uint8List? copiedBytes;
      bool? menuVisibleWhenCopyStarted;
      final container = _createContainerWithPreviewImage(
        clipboardWriter: (bytes) async {
          menuVisibleWhenCopyStarted = find
              .byType(ProContextMenu)
              .evaluate()
              .isNotEmpty;
          copiedBytes = bytes;
        },
      );
      addTearDown(container.dispose);
      final expectedBytes = container
          .read(imageGenerationNotifierProvider)
          .displayImages
          .single
          .bytes;

      await tester.pumpWidget(_buildPreviewApp(container));
      await tester.pumpAndSettle();
      await _openImageContextMenu(tester);

      await tester.tap(find.text('复制图像'));
      await tester.pump();

      expect(copiedBytes, orderedEquals(expectedBytes));
      expect(menuVisibleWhenCopyStarted, isFalse);
      expect(find.byType(ProContextMenu), findsNothing);
      await tester.pumpAndSettle();

      expect(find.byType(ProContextMenu), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generation preview copy applies the active watermark transform',
    (tester) async {
      Uint8List? copiedBytes;
      var transformed = false;
      final output = Uint8List.fromList(
        img.encodePng(img.Image(width: 16, height: 16)),
      );
      final container = _createContainerWithPreviewImage(
        clipboardWriter: (bytes) async => copiedBytes = bytes,
        copyDragTransform: ShareImageTransform(
          cacheKey: 'saved-default',
          apply: (image, {required stripMetadata}) async {
            transformed = true;
            expect(stripMetadata, isFalse);
            return SanitizedShareImage(
              bytes: output,
              fileName: 'marked.png',
              mimeType: 'image/png',
            );
          },
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_buildPreviewApp(container));
      await tester.pumpAndSettle();
      await _openImageContextMenu(tester);
      await tester.tap(find.text('复制图像'));
      await tester.pumpAndSettle();
      expect(transformed, isTrue);
      expect(copiedBytes, orderedEquals(output));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('generation history right-click copy writes the history image', (
    tester,
  ) async {
    Uint8List? copiedBytes;
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 32, height: 32)),
    );
    final container = ProviderContainer(
      overrides: [
        imageClipboardWriterProvider.overrideWithValue(
          (imageBytes) async => copiedBytes = imageBytes,
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(
      history: [
        GeneratedImage(
          id: 'history-copy-image',
          bytes: bytes,
          width: 32,
          height: 32,
        ),
      ],
    );

    await tester.pumpWidget(_buildHistoryApp(container));
    await tester.pumpAndSettle();
    await _openImageContextMenu(tester);

    await tester.tap(find.text('复制图像'));
    await tester.pumpAndSettle();

    expect(copiedBytes, orderedEquals(bytes));
    expect(find.byType(ProContextMenu), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'generation preview makes completed single and grid images draggable',
    (tester) async {
      final container = _createContainerWithPreviewImage();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildPreviewApp(container));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableMemoryImage), findsOneWidget);

      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 32, height: 32)),
      );
      container
          .read(imageGenerationNotifierProvider.notifier)
          .updateDisplayImages([
            GeneratedImage(id: 'grid-1', bytes: bytes, width: 32, height: 32),
            GeneratedImage(id: 'grid-2', bytes: bytes, width: 32, height: 32),
          ]);
      await tester.pumpAndSettle();

      expect(find.byType(DraggableMemoryImage), findsNWidgets(2));
    },
  );

  testWidgets('generation preview keeps failed snapshots non-draggable', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 32, height: 32)),
    );
    container
        .read(imageGenerationNotifierProvider.notifier)
        .updateDisplayImages([
          GeneratedImage(
            id: 'failed-preview',
            bytes: bytes,
            width: 32,
            height: 32,
            kind: GeneratedImageKind.failedStreamSnapshot,
          ),
        ]);

    await tester.pumpWidget(_buildPreviewApp(container));
    await tester.pumpAndSettle();

    expect(find.byType(SelectableImageCard), findsOneWidget);
    expect(find.byType(DraggableMemoryImage), findsNothing);
  });

  testWidgets('generation preview renders multiple stream preview slots', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final firstPreview = Uint8List.fromList(
      img.encodePng(img.Image(width: 32, height: 32)),
    );
    final secondPreview = Uint8List.fromList(
      img.encodePng(img.Image(width: 48, height: 32)),
    );
    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(
      status: GenerationStatus.generating,
      currentImage: 1,
      totalImages: 2,
      batchWidth: 32,
      batchHeight: 32,
      streamPreviewSlots: [
        StreamPreviewSlot(
          imageNumber: 1,
          totalImages: 2,
          progress: 0.25,
          previewBytes: firstPreview,
        ),
        StreamPreviewSlot(
          imageNumber: 2,
          totalImages: 2,
          progress: 0.35,
          previewBytes: secondPreview,
        ),
      ],
      clearStreamPreview: true,
    );

    await tester.pumpWidget(_buildPreviewApp(container));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SelectableImageCard), findsNWidgets(2));
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('focused stream preview with mask uses masked preview path', (
    tester,
  ) async {
    final sourceBytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 32, height: 32)),
    );
    final previewBytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 16, height: 16)),
    );
    final mask = img.Image(width: 16, height: 16, numChannels: 4);
    mask.setPixelRgba(8, 8, 255, 255, 255, 255);
    final maskBytes = Uint8List.fromList(img.encodePng(mask));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 160,
              height: 160,
              child: SelectableImageCard(
                imageBytes: sourceBytes,
                streamPreview: previewBytes,
                focusedPreviewPlacement: FocusedStreamPreviewPlacement(
                  sourceImage: sourceBytes,
                  maskImage: maskBytes,
                  xPercent: 0.25,
                  yPercent: 0.25,
                  widthPercent: 0.5,
                  heightPercent: 0.5,
                ),
                isGenerating: true,
                imageWidth: 32,
                imageHeight: 32,
                currentImage: 1,
                totalImages: 1,
                progress: 0.5,
                enableSelection: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ImageCardStreamPreview), findsOneWidget);
  });

  testWidgets('stream preview keeps the last frame while a new one decodes', (
    tester,
  ) async {
    final firstPreview = Uint8List.fromList(
      img.encodePng(img.Image(width: 8, height: 8)),
    );
    final secondPreview = Uint8List.fromList(
      img.encodePng(img.Image(width: 12, height: 12)),
    );

    await tester.pumpWidget(_buildStreamPreviewApp(firstPreview));
    await _pumpUntilDecoded(
      tester,
      () => _streamPreviewPainter(tester).previewImage != null,
    );
    final firstFrame = _streamPreviewPainter(tester).previewImage;
    expect(firstFrame, isNotNull);

    await tester.pumpWidget(_buildStreamPreviewApp(secondPreview));

    expect(_streamPreviewPainter(tester).previewImage, same(firstFrame));

    await _pumpUntilDecoded(
      tester,
      () => !identical(_streamPreviewPainter(tester).previewImage, firstFrame),
    );
    expect(_streamPreviewPainter(tester).previewImage, isNotNull);
  });

  testWidgets('completion preview covers the card until its first frame', (
    tester,
  ) async {
    final preview = Uint8List.fromList(
      img.encodePng(img.Image(width: 24, height: 24)),
    );
    final result = Uint8List.fromList(
      img.encodePng(img.Image(width: 40, height: 40)),
    );

    await tester.pumpWidget(
      _buildCompletionApp(
        imageBytes: result,
        completionPreview: StreamPreviewFrame(bytes: preview),
      ),
    );

    expect(find.byType(ImageCardStreamPreview), findsOneWidget);
    expect(find.byType(TransparencyBackgroundLayer), findsNothing);

    await _pumpUntilDecoded(
      tester,
      () => find.byType(TransparencyBackgroundLayer).evaluate().isNotEmpty,
    );

    expect(find.byType(TransparencyBackgroundLayer), findsOneWidget);
    expect(find.byType(ImageCardStreamPreview), findsNothing);

    await tester.pumpWidget(_buildCompletionApp(imageBytes: result));
    await tester.pump();

    expect(find.byType(ImageCardStreamPreview), findsNothing);
    expect(find.byType(TransparencyBackgroundLayer), findsOneWidget);
  });

  testWidgets(
    'a completed card without a preview waits on neutral image color',
    (tester) async {
      final result = Uint8List.fromList(
        img.encodePng(img.Image(width: 40, height: 40)),
      );

      await tester.pumpWidget(_buildCompletionApp(imageBytes: result));

      final placeholder = find.descendant(
        of: find.byKey(const ValueKey('selectable-image-content')),
        matching: find.byType(ColoredBox),
      );
      expect(find.byType(ImageCardStreamPreview), findsNothing);
      expect(find.byType(TransparencyBackgroundLayer), findsNothing);
      expect(placeholder, findsOneWidget);
      expect(
        tester.widget<ColoredBox>(placeholder).color,
        const Color(0xFF141414),
      );

      await _pumpUntilDecoded(
        tester,
        () => find.byType(TransparencyBackgroundLayer).evaluate().isNotEmpty,
      );

      expect(placeholder, findsNothing);
      expect(find.byType(TransparencyBackgroundLayer), findsOneWidget);
    },
  );

  testWidgets('an underlay-free card draws nothing before its first frame', (
    tester,
  ) async {
    final result = Uint8List.fromList(
      img.encodePng(img.Image(width: 40, height: 40)),
    );

    await tester.pumpWidget(
      _buildCompletionApp(imageBytes: result, withUnderlay: false),
    );

    expect(find.byType(ImageCardStreamPreview), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('selectable-image-content')),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });

  testWidgets('disabled hover effects should not expose hover action bar', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCardApp(hoverEffectsEnabled: false));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.byType(SelectableImageCard)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('局部重绘'), findsNothing);
    expect(find.byTooltip('放大'), findsNothing);
  });

  testWidgets('favorite button should appear at the top right and toggle', (
    tester,
  ) async {
    var toggled = false;
    await tester.pumpWidget(
      _buildCardApp(isFavorite: true, onFavoriteToggle: () => toggled = true),
    );

    expect(find.byTooltip('取消收藏'), findsOneWidget);

    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('read-only card hides save and copy actions but keeps badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCardApp(
        enableSaveAction: false,
        enableCopyAction: false,
        statusBadgeLabel: '失败快照',
        onInpaint: null,
        onUpscale: null,
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.byType(SelectableImageCard)));
    await tester.pumpAndSettle();

    expect(find.text('失败快照'), findsOneWidget);
    expect(find.byTooltip('保存'), findsNothing);
    expect(find.byTooltip('复制'), findsNothing);

    final center = tester.getCenter(find.byType(SelectableImageCard));
    final secondary = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    addTearDown(secondary.removePointer);
    await tester.pumpAndSettle();
    await secondary.up();
    await tester.pumpAndSettle();

    expect(find.text('保存图片'), findsNothing);
    expect(find.text('复制图片'), findsNothing);
    expect(find.byType(ProContextMenu), findsNothing);
  });
}

void _noop() {}

Widget _buildStreamPreviewApp(Uint8List previewBytes) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox.square(
        dimension: 160,
        child: ImageCardStreamPreview(previewBytes: previewBytes),
      ),
    ),
  );
}

Widget _buildCompletionApp({
  required Uint8List imageBytes,
  StreamPreviewFrame? completionPreview,
  bool withUnderlay = true,
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 160,
            child: SelectableImageCard(
              imageBytes: imageBytes,
              completionPreview: completionPreview,
              underlay: withUnderlay
                  ? const TransparencyBackgroundLayer(
                      style: TransparencyBackgrounds.checker,
                    )
                  : null,
              enableSelection: false,
              enableContextMenu: false,
              hoverEffectsEnabled: false,
            ),
          ),
        ),
      ),
    ),
  );
}

ImageCardStreamPreviewPainter _streamPreviewPainter(WidgetTester tester) {
  return tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(ImageCardStreamPreview),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!
      as ImageCardStreamPreviewPainter;
}

/// 图像解码只在真实事件循环里推进，pump 之间必须放行 runAsync。
Future<void> _pumpUntilDecoded(
  WidgetTester tester,
  bool Function() decoded,
) async {
  for (var attempt = 0; attempt < 50 && !decoded(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

class _EnabledWatermarkSettingsNotifier extends WatermarkSettingsNotifier {
  @override
  WatermarkSettingsState build() => const WatermarkSettingsState(
    configuration: WatermarkSettings(enabled: true),
  );
}

ProviderContainer _createContainerWithPreviewImage({
  ImageClipboardWriter? clipboardWriter,
  bool watermarkEnabled = false,
  ShareImageTransform? copyDragTransform,
}) {
  final container = ProviderContainer(
    overrides: [
      if (copyDragTransform != null)
        copyDragWatermarkProvider.overrideWithValue(copyDragTransform),
      if (clipboardWriter != null)
        imageClipboardWriterProvider.overrideWithValue(clipboardWriter),
      if (watermarkEnabled)
        watermarkSettingsProvider.overrideWith(
          _EnabledWatermarkSettingsNotifier.new,
        ),
    ],
  );
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 32, height: 32)),
  );

  container.read(imageGenerationNotifierProvider.notifier).updateDisplayImages([
    GeneratedImage(id: 'preview-image', bytes: bytes, width: 32, height: 32),
  ]);

  return container;
}

Widget _buildPreviewApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      locale: Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SizedBox(width: 480, height: 480, child: ImagePreviewWidget()),
      ),
    ),
  );
}

Widget _buildHistoryApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      locale: Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SizedBox(width: 320, height: 640, child: HistoryPanel()),
      ),
    ),
  );
}

Future<void> _openImageContextMenu(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(SelectableImageCard).first);
  final gesture = await tester.startGesture(
    center,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  addTearDown(gesture.removePointer);
  await tester.pumpAndSettle();
  await gesture.up();
  await tester.pumpAndSettle();
}

Widget _buildCardApp({
  bool hoverEffectsEnabled = true,
  bool isFavorite = false,
  bool isGenerating = false,
  bool disableAnimations = false,
  bool enableSaveAction = true,
  bool enableCopyAction = true,
  String? statusBadgeLabel,
  VoidCallback? onFavoriteToggle,
  VoidCallback? onInpaint = _noop,
  VoidCallback? onUpscale = _noop,
  VoidCallback? onReversePrompt,
  VoidCallback? onImageToImage,
  VoidCallback? onVibeTransfer,
  VoidCallback? onPreciseReference,
  VoidCallback? onAddToAgent,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  final bytes = Uint8List.fromList(
    img.encodePng(img.Image(width: 32, height: 32)),
  );

  final card = SelectableImageCard(
    imageBytes: bytes,
    isGenerating: isGenerating,
    currentImage: isGenerating ? 1 : null,
    totalImages: isGenerating ? 2 : null,
    imageWidth: 32,
    imageHeight: 32,
    enableSelection: false,
    hoverEffectsEnabled: hoverEffectsEnabled,
    enableSaveAction: enableSaveAction,
    enableCopyAction: enableCopyAction,
    statusBadgeLabel: statusBadgeLabel,
    isFavorite: isFavorite,
    onFavoriteToggle: onFavoriteToggle,
    onInpaint: onInpaint,
    onUpscale: onUpscale,
    onReversePrompt: onReversePrompt,
    onImageToImage: onImageToImage,
    onVibeTransfer: onVibeTransfer,
    onPreciseReference: onPreciseReference,
  );

  return ProviderScope(
    child: MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: onAddToAgent == null
                  ? card
                  : ImageCardActionScope(
                      onAddToAgent: onAddToAgent,
                      child: card,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
