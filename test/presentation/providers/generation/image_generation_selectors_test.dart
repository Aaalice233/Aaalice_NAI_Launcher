import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/generation/image_generation_selectors.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

class _TestImageGenerationNotifier extends ImageGenerationNotifier {
  _TestImageGenerationNotifier(this.initialState);

  final ImageGenerationState initialState;

  @override
  ImageGenerationState build() => initialState;

  void replace(ImageGenerationState value) => state = value;
}

class _Counter {
  int value = 0;
}

void main() {
  late ProviderContainer container;
  late _TestImageGenerationNotifier notifier;
  late _Counter wholeState;
  late _Counter button;
  late _Counter panel;
  late _Counter display;
  late _Counter canvasId;
  late _Counter progress;

  final current = _image('current');
  final history = _image('history');
  final display0 = _image('display');

  final base = ImageGenerationState(
    status: GenerationStatus.generating,
    currentImages: [current],
    history: [history],
    displayImages: [display0],
    currentImage: 1,
    totalImages: 4,
    progress: 0.1,
    isSubmitting: true,
  );

  _Counter listen<T>(T Function(ImageGenerationState state) selector) {
    final counter = _Counter();
    container.listen(
      imageGenerationNotifierProvider.select(selector),
      (_, __) => counter.value++,
    );
    return counter;
  }

  setUp(() {
    notifier = _TestImageGenerationNotifier(base);
    container = ProviderContainer(
      overrides: [imageGenerationNotifierProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);
    wholeState = listen((state) => state);
    button = listen(selectGenerationButtonViewData);
    panel = listen(selectGenerationPanelImages);
    display = listen(selectDisplayImages);
    canvasId = listen(selectCurrentCanvasImageId);
    progress = listen(selectGenerationProgress);
  });

  test('流式预览帧只通知进度投影', () {
    notifier.replace(
      base.copyWith(
        streamPreview: Uint8List.fromList([1, 2, 3]),
        streamPreviewSlots: [
          const StreamPreviewSlot(
            imageNumber: 1,
            totalImages: 4,
            progress: 0.2,
          ),
        ],
        progress: 0.2,
      ),
    );

    expect(wholeState.value, 1);
    expect(progress.value, 1);
    expect(button.value, 0);
    expect(panel.value, 0);
    expect(display.value, 0);
    expect(canvasId.value, 0);
  });

  test('批次序号推进通知按钮投影，不通知图像集合', () {
    notifier.replace(
      base.copyWith(
        currentImage: 2,
        progress: 0.5,
        streamPreview: Uint8List.fromList([4]),
      ),
    );

    expect(button.value, 1);
    expect(progress.value, 1);
    expect(panel.value, 0);
    expect(display.value, 0);
    expect(canvasId.value, 0);
  });

  test('准备态切换通知按钮投影', () {
    notifier.replace(base.copyWith(status: GenerationStatus.idle));

    expect(button.value, 1);
    expect(panel.value, 0);
    expect(progress.value, 0);
  });

  test('完成一张图只通知面板集合投影', () {
    notifier.replace(
      base.copyWith(
        currentImages: [current, _image('current-2')],
        streamPreview: Uint8List.fromList([5]),
      ),
    );

    expect(panel.value, 1);
    expect(display.value, 0);
    expect(canvasId.value, 0);
    expect(button.value, 0);
  });

  test('中央区域换图通知展示图像与画布引用投影', () {
    notifier.replace(base.copyWith(displayImages: [_image('display-2')]));

    expect(display.value, 1);
    expect(panel.value, 1);
    expect(canvasId.value, 1);
    expect(button.value, 0);
    expect(progress.value, 0);
  });

  test('同一份列表实例重复写入不产生通知', () {
    notifier.replace(
      base.copyWith(
        currentImages: base.currentImages,
        history: base.history,
        displayImages: base.displayImages,
        streamPreview: Uint8List.fromList([6]),
      ),
    );

    expect(wholeState.value, 1);
    expect(panel.value, 0);
    expect(display.value, 0);
  });

  test('画布引用跳过失败的流式快照', () {
    notifier.replace(
      base.copyWith(
        displayImages: [
          _image('failed', kind: GeneratedImageKind.failedStreamSnapshot),
          _image('completed'),
        ],
      ),
    );

    expect(
      container.read(
        imageGenerationNotifierProvider.select(selectCurrentCanvasImageId),
      ),
      'completed',
    );
  });
}

GeneratedImage _image(
  String id, {
  GeneratedImageKind kind = GeneratedImageKind.completed,
}) => GeneratedImage(
  id: id,
  bytes: Uint8List.fromList([1]),
  width: 64,
  height: 64,
  kind: kind,
);
