import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/box_fit_resize_image.dart';
import 'package:nai_launcher/presentation/widgets/common/decoded_memory_image.dart';

void main() {
  test('DecodedMemoryImage 根据逻辑尺寸计算并向上分档解码缓存尺寸', () {
    expect(
      DecodedMemoryImage.resolveCacheDimension(
        logicalSize: null,
        constrainedSize: 100,
        pixelRatio: 2,
      ),
      224,
    );
    expect(
      DecodedMemoryImage.resolveCacheDimension(
        logicalSize: 50,
        constrainedSize: 100,
        pixelRatio: 2,
        decodeScale: 1.5,
      ),
      160,
    );
    expect(
      DecodedMemoryImage.resolveCacheDimension(
        logicalSize: null,
        constrainedSize: null,
        pixelRatio: 2,
      ),
      isNull,
    );
    expect(
      DecodedMemoryImage.resolveCacheDimension(
        logicalSize: 10000,
        constrainedSize: null,
        pixelRatio: 4,
      ),
      BoxFitResizeImage.maximumDecodedDimension,
    );
  });

  test('分档解码尺寸不小于显示像素，最多多出 25%，拖动范围内只有少数几档', () {
    for (final pixelRatio in const [1.0, 1.25, 1.5, 2.0, 2.625]) {
      final classes = <int>{};
      for (var logical = 1.0; logical <= 1600; logical += 0.5) {
        final physical = logical * pixelRatio;
        if (physical > BoxFitResizeImage.maximumDecodedDimension) break;
        final resolved = DecodedMemoryImage.resolveCacheDimension(
          logicalSize: logical,
          constrainedSize: null,
          pixelRatio: pixelRatio,
        )!;
        final reason = 'logical $logical @ $pixelRatio';
        expect(resolved, greaterThanOrEqualTo(physical), reason: reason);
        expect(
          resolved,
          lessThanOrEqualTo(physical.ceil() * 1.25),
          reason: reason,
        );
        if (logical >= 300 && logical <= 600) classes.add(resolved);
      }
      // 宽度翻倍最多经过 5 个档位
      expect(classes.length, lessThanOrEqualTo(5), reason: '$pixelRatio');
    }
  });

  test('各种 BoxFit 下解码像素都不小于实际绘制像素且有上界', () {
    const intrinsicSizes = [
      Size(832, 1216),
      Size(1216, 832),
      Size(1024, 1024),
      Size(3000, 600),
      Size(64, 48),
    ];
    const boxes = [
      Size(100, 200),
      Size(360, 180),
      Size(74, 74),
      Size(412.5, 917.3),
    ];
    final source = MemoryImage(Uint8List(0));

    for (final fit in BoxFit.values.where((fit) => fit != BoxFit.none)) {
      for (final intrinsic in intrinsicSizes) {
        for (final box in boxes) {
          for (final pixelRatio in const [1.0, 1.25, 1.5, 2.0, 2.625]) {
            final resized =
                BoxFitResizeImage.resizeIfNeeded(
                      source,
                      fit: fit,
                      width: DecodedMemoryImage.resolveCacheDimension(
                        logicalSize: box.width,
                        constrainedSize: null,
                        pixelRatio: pixelRatio,
                      ),
                      height: DecodedMemoryImage.resolveCacheDimension(
                        logicalSize: box.height,
                        constrainedSize: null,
                        pixelRatio: pixelRatio,
                      ),
                    )
                    as BoxFitResizeImage;
            final target = BoxFitResizeImage.decodeTarget(
              intrinsicWidth: intrinsic.width.toInt(),
              intrinsicHeight: intrinsic.height.toInt(),
              boxWidth: resized.width,
              boxHeight: resized.height,
              fit: resized.fit,
            );

            // scaleDown 最多画到 contain 的大小，按 contain 要求更严
            final painted = applyBoxFit(
              fit == BoxFit.scaleDown ? BoxFit.contain : fit,
              intrinsic,
              box,
            );
            final requiredX =
                painted.destination.width / painted.source.width * pixelRatio;
            final requiredY =
                painted.destination.height / painted.source.height * pixelRatio;
            final decodedX = target.width! / intrinsic.width;
            final decodedY = target.height! / intrinsic.height;
            final reason =
                '${fit.name} $intrinsic in $box @ $pixelRatio → '
                '${target.width}×${target.height}';

            // 原图不够大时只能解到原尺寸，不放大
            expect(
              decodedX,
              greaterThanOrEqualTo(math.min(requiredX, 1) - 1e-9),
              reason: reason,
            );
            expect(
              decodedY,
              greaterThanOrEqualTo(math.min(requiredY, 1) - 1e-9),
              reason: reason,
            );
            // 分档多出的 25% 加上两次向上取整
            final ceiling =
                math.max(requiredX, requiredY) * 1.25 +
                3 / math.min(intrinsic.width, intrinsic.height);
            expect(
              math.max(decodedX, decodedY),
              lessThanOrEqualTo(ceiling),
              reason: reason,
            );
          }
        }
      }
    }
  });

  group('DecodedMemoryImage 解码缓存键', () {
    late Uint8List bytes;

    setUp(() {
      bytes = _testPngBytes(width: 832, height: 1216);
      _clearImageCache();
    });
    tearDown(_clearImageCache);

    Future<BoxFitResizeImage> pumpPanelBackground(
      WidgetTester tester,
      double width,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: width,
              height: 180,
              child: DecodedMemoryImage(bytes: bytes, decodeScale: 0.5),
            ),
          ),
        ),
      );
      final provider = tester.widget<Image>(find.byType(Image)).image;
      expect(provider, isA<BoxFitResizeImage>());
      return provider as BoxFitResizeImage;
    }

    testWidgets('面板宽度小幅变化时缓存键不变，不重复解码', (tester) async {
      tester.view.devicePixelRatio = 1.25;
      addTearDown(tester.view.resetDevicePixelRatio);

      final first = await pumpPanelBackground(tester, 360);
      final firstKey = await first.obtainKey(ImageConfiguration.empty);
      expect(
        (first.width, first.height, first.fit),
        (256, 128, DecodeFit.cover),
      );
      expect((first.imageProvider as MemoryImage).bytes, same(bytes));

      for (final width in const [362.5, 368.0, 372.0, 409.0]) {
        final provider = await pumpPanelBackground(tester, width);
        expect(
          await provider.obtainKey(ImageConfiguration.empty),
          firstKey,
          reason: 'width $width',
        );
        expect(provider.width!, greaterThanOrEqualTo(width * 1.25 * 0.5));
      }
      expect(_trackedImageCount(), 1);
    });

    testWidgets('跨档时只多解码一次，回到原宽度命中缓存', (tester) async {
      tester.view.devicePixelRatio = 1.25;
      addTearDown(tester.view.resetDevicePixelRatio);

      final narrow = await pumpPanelBackground(tester, 360);
      final narrowKey = await narrow.obtainKey(ImageConfiguration.empty);

      final wide = await pumpPanelBackground(tester, 420);
      final wideKey = await wide.obtainKey(ImageConfiguration.empty);
      expect(wideKey, isNot(narrowKey));
      expect(wide.width, 320);
      expect(_trackedImageCount(), 2);

      final back = await pumpPanelBackground(tester, 364);
      expect(await back.obtainKey(ImageConfiguration.empty), narrowKey);
      expect(_trackedImageCount(), 2);
    });

    testWidgets('BoxFit.none 按原图解码，不改变绘制尺寸', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: DecodedMemoryImage(bytes: bytes, fit: BoxFit.none),
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect(image.gaplessPlayback, isTrue);
    });
  });
}

void _clearImageCache() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}

int _trackedImageCount() {
  final cache = PaintingBinding.instance.imageCache;
  return cache.pendingImageCount + cache.currentSize;
}

Uint8List _testPngBytes({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}
