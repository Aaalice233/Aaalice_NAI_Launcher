import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_options.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_progress.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_service.dart';

/// 生成一张被整数倍放大的像素画 PNG。
Uint8List buildPixelArtPng({
  required int blocks,
  required int scale,
  int seed = 1,
  bool transparentEdge = false,
}) {
  final math.Random random = math.Random(seed);
  final int size = blocks * scale;
  final img.Image image = img.Image(width: size, height: size, numChannels: 4);
  final List<List<int>> palette = List<List<int>>.generate(
    blocks * blocks,
    (_) => <int>[
      random.nextInt(6) * 51,
      random.nextInt(6) * 51,
      random.nextInt(6) * 51,
    ],
  );
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final List<int> color = palette[(y ~/ scale) * blocks + x ~/ scale];
      final bool clear = transparentEdge && x >= size ~/ 2;
      image.setPixelRgba(x, y, color[0], color[1], color[2], clear ? 0 : 255);
    }
  }
  return img.encodePng(image);
}

void main() {
  const PixelSnapService service = PixelSnapService();

  test('输出尺寸等于像素块数，且不放大', () async {
    final Uint8List png = buildPixelArtPng(blocks: 32, scale: 8);
    final PixelSnapOutput out = await service.run(
      png,
      const PixelSnapOptions(paletteMode: PixelSnapPaletteMode.off),
    );

    expect(out.snappedWidth, 32);
    expect(out.snappedHeight, 32);
    expect(out.outputWidth, 32);
    expect(out.outputHeight, 32);
    expect(out.downscaledForAnalysis, isFalse);

    final img.Image decoded = img.decodePng(out.pngBytes)!;
    expect(decoded.width, 32);
    expect(decoded.height, 32);
  });

  test('开启 Upscale 后按整数倍放回接近原尺寸', () async {
    final Uint8List png = buildPixelArtPng(blocks: 32, scale: 8, seed: 2);
    final PixelSnapOutput out = await service.run(
      png,
      const PixelSnapOptions(
        paletteMode: PixelSnapPaletteMode.off,
        upscale: true,
      ),
    );

    expect(out.snappedWidth, 32);
    expect(out.outputWidth, 256);
    expect(out.outputHeight, 256);
  });

  test('进度单调递增并走完四个阶段', () async {
    final Uint8List png = buildPixelArtPng(blocks: 24, scale: 8, seed: 3);
    final List<PixelSnapProgress> updates = <PixelSnapProgress>[];
    await service.run(png, const PixelSnapOptions(), onProgress: updates.add);

    expect(updates, isNotEmpty);
    for (int i = 1; i < updates.length; i++) {
      expect(
        updates[i].fraction,
        greaterThanOrEqualTo(updates[i - 1].fraction),
      );
    }
    expect(updates.first.fraction, lessThan(0.2));
    expect(updates.last.fraction, closeTo(1, 1e-9));
    expect(
      updates.map((PixelSnapProgress p) => p.stage).toSet(),
      containsAll(PixelSnapStage.values),
    );
  });

  test('取消后以 PixelSnapCancelledException 结束', () async {
    final Uint8List png = buildPixelArtPng(blocks: 64, scale: 8, seed: 4);
    final PixelSnapCancellation cancellation = PixelSnapCancellation();
    final Future<PixelSnapOutput> pending = service.run(
      png,
      const PixelSnapOptions(),
      cancellation: cancellation,
    );

    // 等第一条进度到了再取消，确保 isolate 已经起来。
    await Future<void>.delayed(const Duration(milliseconds: 200));
    cancellation.cancel();

    await expectLater(pending, throwsA(isA<PixelSnapCancelledException>()));
    expect(cancellation.isCancelled, isTrue);
  });

  test('开始前就取消也能立刻结束', () async {
    final Uint8List png = buildPixelArtPng(blocks: 48, scale: 8, seed: 5);
    final PixelSnapCancellation cancellation = PixelSnapCancellation()
      ..cancel();

    await expectLater(
      service.run(png, const PixelSnapOptions(), cancellation: cancellation),
      throwsA(isA<PixelSnapCancelledException>()),
    );
  });

  test('全透明源图抛 PixelSnapBlankImageException', () async {
    final img.Image blank = img.Image(width: 64, height: 64, numChannels: 4);
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        blank.setPixelRgba(x, y, 12, 34, 56, 0);
      }
    }

    await expectLater(
      service.run(img.encodePng(blank), const PixelSnapOptions()),
      throwsA(isA<PixelSnapBlankImageException>()),
    );
  });

  test('半透明区域在结果里保持透明', () async {
    final Uint8List png = buildPixelArtPng(
      blocks: 24,
      scale: 8,
      seed: 6,
      transparentEdge: true,
    );
    final PixelSnapOutput out = await service.run(
      png,
      const PixelSnapOptions(paletteMode: PixelSnapPaletteMode.off),
    );

    final img.Image decoded = img.decodePng(out.pngBytes)!;
    expect(decoded.getPixel(0, 0).a, 255);
    expect(decoded.getPixel(decoded.width - 1, 0).a, 0);
  });
}
