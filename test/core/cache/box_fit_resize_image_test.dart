import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/box_fit_resize_image.dart';

import '../../helpers/image_stream_resolution.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BoxFitResizeImage.decodeTarget', () {
    test('cover 覆盖解码框，contain 保持在解码框内', () {
      final cover = BoxFitResizeImage.decodeTarget(
        intrinsicWidth: 4000,
        intrinsicHeight: 2000,
        boxWidth: 192,
        boxHeight: 224,
        fit: DecodeFit.cover,
      );
      final contain = BoxFitResizeImage.decodeTarget(
        intrinsicWidth: 4000,
        intrinsicHeight: 2000,
        boxWidth: 192,
        boxHeight: 224,
        fit: DecodeFit.contain,
      );

      expect((cover.width, cover.height), (448, 224));
      expect((contain.width, contain.height), (192, 96));
    });

    test('只有一条边受限时按该边等比缩放', () {
      final byWidth = BoxFitResizeImage.decodeTarget(
        intrinsicWidth: 1000,
        intrinsicHeight: 500,
        boxWidth: 250,
        boxHeight: null,
        fit: DecodeFit.cover,
      );
      final byHeight = BoxFitResizeImage.decodeTarget(
        intrinsicWidth: 1000,
        intrinsicHeight: 500,
        boxWidth: null,
        boxHeight: 100,
        fit: DecodeFit.contain,
      );

      expect((byWidth.width, byWidth.height), (250, 125));
      expect((byHeight.width, byHeight.height), (200, 100));
    });

    test('小原图不会被解码放大', () {
      final result = BoxFitResizeImage.decodeTarget(
        intrinsicWidth: 80,
        intrinsicHeight: 60,
        boxWidth: 384,
        boxHeight: 448,
        fit: DecodeFit.cover,
      );

      expect((result.width, result.height), (80, 60));
    });

    test('极端宽高比保持比例并限制最长解码边', () {
      final result = BoxFitResizeImage.decodeTarget(
        intrinsicWidth: 100000,
        intrinsicHeight: 100,
        boxWidth: 384,
        boxHeight: 448,
        fit: DecodeFit.cover,
      );

      expect(result.width, BoxFitResizeImage.maximumDecodedDimension);
      expect(result.height, 5);
    });
  });

  group('BoxFitResizeImage.resizeIfNeeded', () {
    final source = MemoryImage(Uint8List.fromList(const [1, 2, 3]));

    test('按 BoxFit 的绘制方式选择解码框', () {
      final expectations = <BoxFit, (int?, int?, DecodeFit)?>{
        BoxFit.contain: (300, 200, DecodeFit.contain),
        BoxFit.scaleDown: (300, 200, DecodeFit.contain),
        BoxFit.cover: (300, 200, DecodeFit.cover),
        BoxFit.fill: (300, 200, DecodeFit.cover),
        BoxFit.fitWidth: (300, null, DecodeFit.contain),
        BoxFit.fitHeight: (null, 200, DecodeFit.contain),
        BoxFit.none: null,
      };
      expect(expectations.keys, unorderedEquals(BoxFit.values));

      for (final MapEntry(key: fit, value: expected) in expectations.entries) {
        final resized = BoxFitResizeImage.resizeIfNeeded(
          source,
          fit: fit,
          width: 300,
          height: 200,
        );
        if (expected == null) {
          expect(resized, same(source), reason: fit.name);
          continue;
        }
        expect(resized, isA<BoxFitResizeImage>(), reason: fit.name);
        final box = resized as BoxFitResizeImage;
        expect(box.imageProvider, same(source), reason: fit.name);
        expect((box.width, box.height, box.fit), expected, reason: fit.name);
      }
    });

    test('没有受限的边时原样返回', () {
      expect(
        BoxFitResizeImage.resizeIfNeeded(source, fit: BoxFit.cover),
        same(source),
      );
      expect(
        BoxFitResizeImage.resizeIfNeeded(
          source,
          fit: BoxFit.fitWidth,
          height: 200,
        ),
        same(source),
      );
    });
  });

  group('BoxFitResizeImage 缓存键', () {
    test('同步内层键保持同步，参数相同的实例共用缓存键', () async {
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      BoxFitResizeImage resize({int width = 256, DecodeFit? fit}) =>
          BoxFitResizeImage(
            MemoryImage(bytes),
            width: width,
            height: 128,
            fit: fit ?? DecodeFit.cover,
          );

      final pending = resize().obtainKey(ImageConfiguration.empty);
      expect(pending, isA<SynchronousFuture<BoxFitResizeImageKey>>());

      final key = await pending;
      expect(await resize().obtainKey(ImageConfiguration.empty), key);
      expect(resize(), resize());
      expect(
        await resize(width: 320).obtainKey(ImageConfiguration.empty),
        isNot(key),
      );
      expect(
        await resize(
          fit: DecodeFit.contain,
        ).obtainKey(ImageConfiguration.empty),
        isNot(key),
      );
    });

    test('内层键异步失败时错误交给图片流', () async {
      const provider = BoxFitResizeImage(
        _FailingKeyImage(),
        width: 64,
        fit: DecodeFit.contain,
      );

      await expectLater(
        provider.obtainKey(ImageConfiguration.empty),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('BoxFitResizeImage 解码', () {
    tearDown(() {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    });

    test('cover 按覆盖尺寸解码，contain 按适配尺寸解码', () async {
      final bytes = _pngBytes(width: 200, height: 100);

      final cover = await resolveImageInfo(
        BoxFitResizeImage(
          MemoryImage(bytes),
          width: 50,
          height: 50,
          fit: DecodeFit.cover,
        ),
      );
      addTearDown(cover.dispose);
      final contain = await resolveImageInfo(
        BoxFitResizeImage(
          MemoryImage(bytes),
          width: 50,
          height: 50,
          fit: DecodeFit.contain,
        ),
      );
      addTearDown(contain.dispose);

      expect((cover.image.width, cover.image.height), (100, 50));
      expect((contain.image.width, contain.image.height), (50, 25));
    });

    test('解码失败后从图片缓存移除', () async {
      final provider = BoxFitResizeImage(
        MemoryImage(Uint8List.fromList(const [0, 1, 2, 3])),
        width: 32,
        height: 32,
        fit: DecodeFit.cover,
      );
      final key = await provider.obtainKey(ImageConfiguration.empty);

      await expectLater(resolveImageInfo(provider), throwsA(anything));
      await Future<void>.delayed(Duration.zero);

      expect(
        PaintingBinding.instance.imageCache.statusForKey(key).untracked,
        isTrue,
      );
    });
  });
}

class _FailingKeyImage extends ImageProvider<Object> {
  const _FailingKeyImage();

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      Future<Object>.error(StateError('key unavailable'));

  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) =>
      throw UnimplementedError();
}

Uint8List _pngBytes({required int width, required int height}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));
