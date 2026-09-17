import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/pixel_snap/internal/numeric_utils.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_engine.dart';
import 'package:nai_launcher/core/services/pixel_snap/pixel_snap_options.dart';

/// 造一张"像素画被放大过"的图：blocks 个色块，每块放大 [scale] 倍。
///
/// [scale] 允许是小数，模拟非整数倍缩放留下的块宽抖动。
Uint8List buildScaledPixelArt({
  required int blocksX,
  required int blocksY,
  required double scale,
  required int seed,
  double noise = 0,
}) {
  final math.Random random = math.Random(seed);
  final Uint8List palette = Uint8List(blocksX * blocksY * 3);
  for (int i = 0; i < blocksX * blocksY; i++) {
    // 限制在 6 个色阶上，才像真的像素画而不是噪声。
    palette[3 * i] = (random.nextInt(6) * 51);
    palette[3 * i + 1] = (random.nextInt(6) * 51);
    palette[3 * i + 2] = (random.nextInt(6) * 51);
  }

  final int width = (blocksX * scale).round();
  final int height = (blocksY * scale).round();
  final Uint8List rgb = Uint8List(width * height * 3);
  for (int y = 0; y < height; y++) {
    final int by = math.min(blocksY - 1, (y / scale).floor());
    for (int x = 0; x < width; x++) {
      final int bx = math.min(blocksX - 1, (x / scale).floor());
      final int src = (by * blocksX + bx) * 3;
      final int dst = (y * width + x) * 3;
      for (int c = 0; c < 3; c++) {
        double value = palette[src + c].toDouble();
        if (noise > 0) {
          value += (random.nextDouble() * 2 - 1) * noise;
        }
        rgb[dst + c] = roundHalfEven(value.clamp(0, 255).toDouble());
      }
    }
  }
  return rgb;
}

int scaledWidth(int blocks, double scale) => (blocks * scale).round();

/// 少数色块内部再切 2×2 个有色差的子块，其余保持纯色，再整体放大 [scale] 倍。
///
/// [subdividedFraction] 要压得比较低：切分的块太多，半间距在 spread 上就直接赢了，
/// 间距选择阶段根本轮不到子谐波细化出场。低比例 + 少量噪声才能造出
/// "粗间距先胜出、再被 MAE 拉回细间距"这条路径。
Uint8List buildSubdividedPixelArt({
  required int blocksX,
  required int blocksY,
  required double scale,
  required int seed,
  double subdividedFraction = 0.15,
  int shift = 36,
  double noise = 4,
}) {
  final math.Random random = math.Random(seed);
  final int subX = blocksX * 2;
  final int subY = blocksY * 2;
  final Uint8List palette = Uint8List(subX * subY * 3);
  for (int by = 0; by < blocksY; by++) {
    for (int bx = 0; bx < blocksX; bx++) {
      final List<int> base = <int>[
        random.nextInt(6) * 51,
        random.nextInt(6) * 51,
        random.nextInt(6) * 51,
      ];
      final bool subdivided = random.nextDouble() < subdividedFraction;
      for (int sy = 0; sy < 2; sy++) {
        for (int sx = 0; sx < 2; sx++) {
          final int at = ((by * 2 + sy) * subX + bx * 2 + sx) * 3;
          final int delta = subdivided
              ? (sy * 2 + sx) * (shift ~/ 2) - shift
              : 0;
          for (int c = 0; c < 3; c++) {
            palette[at + c] = (base[c] + delta).clamp(0, 255);
          }
        }
      }
    }
  }

  final int width = (blocksX * scale).round();
  final int height = (blocksY * scale).round();
  final double subScale = scale / 2;
  final Uint8List rgb = Uint8List(width * height * 3);
  for (int y = 0; y < height; y++) {
    final int sy = math.min(subY - 1, (y / subScale).floor());
    for (int x = 0; x < width; x++) {
      final int sx = math.min(subX - 1, (x / subScale).floor());
      final int src = (sy * subX + sx) * 3;
      final int dst = (y * width + x) * 3;
      for (int c = 0; c < 3; c++) {
        rgb[dst + c] = roundHalfEven(
          (palette[src + c] + (random.nextDouble() * 2 - 1) * noise)
              .clamp(0, 255)
              .toDouble(),
        );
      }
    }
  }
  return rgb;
}

void main() {
  const PixelSnapEngineParams noPalette = PixelSnapEngineParams(
    colors: 0,
    autoTolerance: PixelSnapOptions.autoTolerance,
    maxDetail: PixelSnapEngineParams.defaultMaxDetail,
    upscale: false,
  );

  group('PixelSnapEngine', () {
    test('整数倍放大的像素画能被还原成原始块数', () async {
      const int blocksX = 40;
      const int blocksY = 30;
      const double scale = 8;
      final Uint8List rgb = buildScaledPixelArt(
        blocksX: blocksX,
        blocksY: blocksY,
        scale: scale,
        seed: 1,
      );

      final PixelSnapEngineResult result = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: scaledWidth(blocksX, scale),
        height: scaledWidth(blocksY, scale),
        params: noPalette,
      );

      expect(result.width, blocksX);
      expect(result.height, blocksY);
      expect(result.pitchX, closeTo(scale, 0.4));
      expect(result.pitchY, closeTo(scale, 0.4));
    });

    test('非整数倍放大同样能还原块数', () async {
      const int blocksX = 36;
      const int blocksY = 28;
      const double scale = 7.3;
      final Uint8List rgb = buildScaledPixelArt(
        blocksX: blocksX,
        blocksY: blocksY,
        scale: scale,
        seed: 2,
      );

      final PixelSnapEngineResult result = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: scaledWidth(blocksX, scale),
        height: scaledWidth(blocksY, scale),
        params: noPalette,
      );

      expect(result.width, blocksX);
      expect(result.height, blocksY);
      expect(result.pitchX, closeTo(scale, 0.5));
    });

    test('带噪声时仍能还原块数', () async {
      const int blocksX = 32;
      const int blocksY = 32;
      const double scale = 9;
      final Uint8List rgb = buildScaledPixelArt(
        blocksX: blocksX,
        blocksY: blocksY,
        scale: scale,
        seed: 3,
        noise: 4,
      );

      final PixelSnapEngineResult result = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: scaledWidth(blocksX, scale),
        height: scaledWidth(blocksY, scale),
        params: noPalette,
      );

      expect(result.width, blocksX);
      expect(result.height, blocksY);
    });

    test('块内有子结构时默认细化到半间距，Avoid Over-Refining 保持粗间距', () async {
      const int blocksX = 24;
      const int blocksY = 24;
      const double scale = 8;
      final int width = blocksX * scale.toInt();
      final int height = blocksY * scale.toInt();
      final Uint8List rgb = buildSubdividedPixelArt(
        blocksX: blocksX,
        blocksY: blocksY,
        scale: scale,
        seed: 7,
      );

      final PixelSnapEngineResult refined = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: width,
        height: height,
        params: noPalette,
      );
      expect(refined.width, blocksX * 2);
      expect(refined.height, blocksY * 2);

      final PixelSnapEngineResult kept = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: width,
        height: height,
        params: const PixelSnapEngineParams(
          colors: 0,
          autoTolerance: PixelSnapOptions.autoTolerance,
          maxDetail: null,
          upscale: false,
        ),
      );
      expect(kept.width, blocksX);
      expect(kept.height, blocksY);
    });

    test('纯色图找不到网格时抛 PixelSnapNoGridException', () async {
      const int width = 160;
      const int height = 160;
      final Uint8List rgb = Uint8List(width * height * 3);
      for (int i = 0; i < width * height; i++) {
        rgb[3 * i] = 90;
        rgb[3 * i + 1] = 140;
        rgb[3 * i + 2] = 200;
      }

      await expectLater(
        () => PixelSnapEngine.run(
          rgb: rgb,
          alpha: null,
          width: width,
          height: height,
          params: noPalette,
        ),
        throwsA(isA<PixelSnapNoGridException>()),
      );
    });

    test('平滑渐变不会越界崩溃', () async {
      const int width = 200;
      const int height = 200;
      final Uint8List rgb = Uint8List(width * height * 3);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int at = (y * width + x) * 3;
          rgb[at] = (x * 255 / width).floor();
          rgb[at + 1] = (y * 255 / height).floor();
          rgb[at + 2] = 128;
        }
      }

      // 渐变会让搜索退化到极小间距，格子下界因此可能算成负数。
      final PixelSnapEngineResult result = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: width,
        height: height,
        params: noPalette,
      );
      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
    });

    test('自动定色数会把色数压到源色板附近', () async {
      const int blocksX = 32;
      const int blocksY = 32;
      const double scale = 8;
      final Uint8List rgb = buildScaledPixelArt(
        blocksX: blocksX,
        blocksY: blocksY,
        scale: scale,
        seed: 4,
        noise: 6,
      );

      final PixelSnapEngineResult result = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: scaledWidth(blocksX, scale),
        height: scaledWidth(blocksY, scale),
        params: const PixelSnapEngineParams(
          colors: PixelSnapEngineParams.autoColors,
          autoTolerance: PixelSnapOptions.autoTolerance,
          maxDetail: PixelSnapEngineParams.defaultMaxDetail,
          upscale: false,
        ),
      );

      expect(result.paletteSize, greaterThan(0));
      expect(result.paletteSize, lessThanOrEqualTo(256));
    });

    test('固定色数不会超过目标值', () async {
      const int blocksX = 32;
      const int blocksY = 32;
      const double scale = 8;
      final Uint8List rgb = buildScaledPixelArt(
        blocksX: blocksX,
        blocksY: blocksY,
        scale: scale,
        seed: 5,
        noise: 6,
      );

      final PixelSnapEngineResult result = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: scaledWidth(blocksX, scale),
        height: scaledWidth(blocksY, scale),
        params: const PixelSnapEngineParams(
          colors: 16,
          autoTolerance: PixelSnapOptions.autoTolerance,
          maxDetail: PixelSnapEngineParams.defaultMaxDetail,
          upscale: false,
        ),
      );

      expect(result.paletteSize, lessThanOrEqualTo(16));
    });

    test('并行与单线程结果逐位相同', () async {
      const int blocksX = 30;
      const int blocksY = 22;
      const double scale = 7.3;
      final Uint8List rgb = buildScaledPixelArt(
        blocksX: blocksX,
        blocksY: blocksY,
        scale: scale,
        seed: 9,
        noise: 3,
      );
      final int width = scaledWidth(blocksX, scale);
      final int height = scaledWidth(blocksY, scale);
      const PixelSnapEngineParams params = PixelSnapEngineParams(
        colors: PixelSnapEngineParams.autoColors,
        autoTolerance: PixelSnapOptions.autoTolerance,
        maxDetail: PixelSnapEngineParams.defaultMaxDetail,
        upscale: false,
      );

      final PixelSnapEngineResult sequential = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: width,
        height: height,
        params: params,
        parallel: false,
      );
      final PixelSnapEngineResult parallel = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: null,
        width: width,
        height: height,
        params: params,
        parallel: true,
      );

      expect(parallel.width, sequential.width);
      expect(parallel.height, sequential.height);
      expect(parallel.pitchX, sequential.pitchX);
      expect(parallel.pitchY, sequential.pitchY);
      expect(parallel.paletteSize, sequential.paletteSize);
      expect(parallel.rgb, orderedEquals(sequential.rgb));
    });

    test('半透明区域的 alpha 被保留', () async {
      const int blocksX = 24;
      const int blocksY = 24;
      const double scale = 8;
      final int width = scaledWidth(blocksX, scale);
      final int height = scaledWidth(blocksY, scale);
      final Uint8List rgb = buildScaledPixelArt(
        blocksX: blocksX,
        blocksY: blocksY,
        scale: scale,
        seed: 6,
      );
      final Uint8List alpha = Uint8List(width * height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          alpha[y * width + x] = x < width ~/ 2 ? 255 : 0;
        }
      }

      final PixelSnapEngineResult result = await PixelSnapEngine.run(
        rgb: rgb,
        alpha: alpha,
        width: width,
        height: height,
        params: noPalette,
      );

      expect(result.alpha, isNotNull);
      expect(result.alpha!.length, result.width * result.height);
      expect(result.alpha![0], 255);
      expect(result.alpha![result.width - 1], 0);
    });
  });

  group('PixelSnapEngineParams.fromOptions', () {
    test('off 关掉量化', () async {
      final PixelSnapEngineParams params = PixelSnapEngineParams.fromOptions(
        const PixelSnapOptions(paletteMode: PixelSnapPaletteMode.off),
      );
      expect(params.colors, 0);
      expect(params.isAutoColors, isFalse);
    });

    test('auto 走自动定色数', () async {
      final PixelSnapEngineParams params = PixelSnapEngineParams.fromOptions(
        const PixelSnapOptions(),
      );
      expect(params.isAutoColors, isTrue);
      expect(params.autoTolerance, 6.5);
    });

    test('custom 透传色数', () async {
      final PixelSnapEngineParams params = PixelSnapEngineParams.fromOptions(
        const PixelSnapOptions(
          paletteMode: PixelSnapPaletteMode.custom,
          colors: 48,
        ),
      );
      expect(params.colors, 48);
    });

    test('avoidOverRefining 勾选后关掉子谐波细化', () async {
      expect(
        PixelSnapEngineParams.fromOptions(
          const PixelSnapOptions(avoidOverRefining: true),
        ).maxDetail,
        isNull,
      );
      expect(
        PixelSnapEngineParams.fromOptions(const PixelSnapOptions()).maxDetail,
        PixelSnapEngineParams.defaultMaxDetail,
      );
    });
  });
}
