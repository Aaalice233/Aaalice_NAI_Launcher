import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/local_gallery_thumbnail_provider.dart';

import '../../helpers/webp_metadata_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalGalleryThumbnailTarget', () {
    test('按逻辑尺寸和常见桌面 DPR 量化物理像素', () {
      final expected = <double, (int, int)>{
        1.0: (192, 224),
        1.25: (256, 288),
        1.5: (288, 352),
        2.0: (384, 448),
      };

      for (final entry in expected.entries) {
        final target = LocalGalleryThumbnailTarget.fromLogicalSize(
          logicalWidth: 180,
          logicalHeight: 220,
          devicePixelRatio: entry.key,
        );
        expect((target.width, target.height), entry.value);
        expect(target.width, greaterThanOrEqualTo(180 * entry.key));
        expect(target.height, greaterThanOrEqualTo(220 * entry.key));
        expect(target.width - 180 * entry.key, lessThan(32));
        expect(target.height - 220 * entry.key, lessThan(32));
      }
    });

    test('限制异常窗口尺寸导致的过度解码', () {
      final target = LocalGalleryThumbnailTarget.fromLogicalSize(
        logicalWidth: 10000,
        logicalHeight: 5000,
        devicePixelRatio: 4,
      );
      expect(target.width, LocalGalleryThumbnailTarget.maximumDimension);
      expect(target.height, LocalGalleryThumbnailTarget.maximumDimension);
    });
  });

  group('LocalGalleryThumbnailProvider', () {
    test('cover 解码覆盖卡片且 contain 解码保持在边界内', () {
      const target = LocalGalleryThumbnailTarget(width: 192, height: 224);
      final cover = LocalGalleryThumbnailProvider.calculateDecodeTarget(
        intrinsicWidth: 4000,
        intrinsicHeight: 2000,
        target: target,
        fit: LocalGalleryThumbnailFit.cover,
      );
      final contain = LocalGalleryThumbnailProvider.calculateDecodeTarget(
        intrinsicWidth: 4000,
        intrinsicHeight: 2000,
        target: target,
        fit: LocalGalleryThumbnailFit.contain,
      );

      expect((cover.width, cover.height), (448, 224));
      expect((contain.width, contain.height), (192, 96));
    });

    test('极端宽高比保持比例并限制最长解码边', () {
      final result = LocalGalleryThumbnailProvider.calculateDecodeTarget(
        intrinsicWidth: 100000,
        intrinsicHeight: 100,
        target: const LocalGalleryThumbnailTarget(width: 384, height: 448),
        fit: LocalGalleryThumbnailFit.cover,
      );
      expect(
        result.width,
        LocalGalleryThumbnailProvider.maximumDecodedDimension,
      );
      expect(result.height, 5);
    });

    test('小原图不会被解码放大', () {
      final result = LocalGalleryThumbnailProvider.calculateDecodeTarget(
        intrinsicWidth: 80,
        intrinsicHeight: 60,
        target: const LocalGalleryThumbnailTarget(width: 384, height: 448),
        fit: LocalGalleryThumbnailFit.cover,
      );
      expect((result.width, result.height), (80, 60));
    });

    test('路径相同但大小或修改时间变化会生成不同缓存键', () {
      final original = LocalGallerySourceIdentity.fromRecord(
        path: 'gallery/image.png',
        size: 100,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );
      final replaced = LocalGallerySourceIdentity.fromRecord(
        path: 'gallery/image.png',
        size: 101,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      );
      const target = LocalGalleryThumbnailTarget(width: 384, height: 448);

      expect(
        LocalGalleryThumbnailProvider(
          source: original,
          target: target,
        ).cacheKey,
        isNot(
          LocalGalleryThumbnailProvider(
            source: replaced,
            target: target,
          ).cacheKey,
        ),
      );
    });

    test('透明 PNG 按目标尺寸解码并保留 alpha', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nai_local_thumbnail_alpha_',
      );
      addTearDown(() async => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}${Platform.pathSeparator}alpha.png');
      final source = img.Image(width: 400, height: 300, numChannels: 4)
        ..clear(img.ColorRgba8(255, 0, 0, 0));
      await file.writeAsBytes(img.encodePng(source), flush: true);
      final stat = await file.stat();
      final provider = LocalGalleryThumbnailProvider(
        source: LocalGallerySourceIdentity.fromRecord(
          path: file.path,
          size: stat.size,
          modifiedAt: stat.modified,
        ),
        target: const LocalGalleryThumbnailTarget(width: 128, height: 128),
        fit: LocalGalleryThumbnailFit.contain,
      );
      addTearDown(() => provider.evict());

      final info = await _resolve(provider);
      addTearDown(info.dispose);
      expect((info.image.width, info.image.height), (128, 96));
      final pixels = await info.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(pixels, isNotNull);
      expect(pixels!.getUint8(3), 0);
    });

    test('WebP 通过原生解码链路加载', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nai_local_thumbnail_webp_',
      );
      addTearDown(() async => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}${Platform.pathSeparator}image.webp');
      await file.writeAsBytes(buildNovelAiWebpFixture(), flush: true);
      final stat = await file.stat();
      final provider = LocalGalleryThumbnailProvider(
        source: LocalGallerySourceIdentity.fromRecord(
          path: file.path,
          size: stat.size,
          modifiedAt: stat.modified,
        ),
        target: const LocalGalleryThumbnailTarget(width: 64, height: 64),
      );

      final info = await _resolve(provider);
      addTearDown(info.dispose);
      expect((info.image.width, info.image.height), (1, 1));
    });

    test('JPEG EXIF 旋转由引擎应用且不会拉伸', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nai_local_thumbnail_exif_',
      );
      addTearDown(() async => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}${Platform.pathSeparator}rotated.jpg');
      final source = img.Image(width: 120, height: 60)
        ..exif.imageIfd.orientation = 6;
      await file.writeAsBytes(img.encodeJpg(source), flush: true);
      final stat = await file.stat();
      final provider = LocalGalleryThumbnailProvider(
        source: LocalGallerySourceIdentity.fromRecord(
          path: file.path,
          size: stat.size,
          modifiedAt: stat.modified,
        ),
        target: const LocalGalleryThumbnailTarget(width: 200, height: 200),
        fit: LocalGalleryThumbnailFit.contain,
      );

      final info = await _resolve(provider);
      addTearDown(info.dispose);
      expect((info.image.width, info.image.height), (60, 120));
    });

    test('图库可遇到的多帧图片由原生 codec 识别', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nai_local_thumbnail_animation_',
      );
      addTearDown(() async => tempDir.delete(recursive: true));
      final animation = img.Image(width: 20, height: 10)
        ..frameDuration = 20
        ..clear(img.ColorRgb8(255, 0, 0));
      animation.addFrame(
        img.Image(width: 20, height: 10)
          ..frameDuration = 20
          ..clear(img.ColorRgb8(0, 0, 255)),
      );
      final file = File('${tempDir.path}${Platform.pathSeparator}image.gif');
      await file.writeAsBytes(img.encodeGif(animation), flush: true);
      final stat = await file.stat();
      final provider = LocalGalleryThumbnailProvider(
        source: LocalGallerySourceIdentity.fromRecord(
          path: file.path,
          size: stat.size,
          modifiedAt: stat.modified,
        ),
        target: const LocalGalleryThumbnailTarget(width: 20, height: 10),
      );

      final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      final codec = await ui.instantiateImageCodecWithSize(buffer);
      expect(codec.frameCount, 2);
      codec.dispose();
      expect(
        provider.cacheKey.target,
        const LocalGalleryThumbnailTarget(width: 20, height: 10),
      );
    });

    test('快速滚动式批量请求最多并行四路且队列可取消', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nai_local_thumbnail_scheduler_',
      );
      addTearDown(() async {
        LocalGalleryThumbnailMemoryCache.instance.clear();
        await tempDir.delete(recursive: true);
      });
      final file = File('${tempDir.path}${Platform.pathSeparator}source.png');
      await file.writeAsBytes(
        img.encodePng(img.Image(width: 800, height: 600)),
        flush: true,
      );
      final stat = await file.stat();
      final source = LocalGallerySourceIdentity.fromRecord(
        path: file.path,
        size: stat.size,
        modifiedAt: stat.modified,
      );
      final releaseDecoders = Completer<void>();
      Future<ui.Codec> delayedDecoder(
        ui.ImmutableBuffer buffer, {
        ui.TargetImageSize Function(int, int)? getTargetSize,
      }) async {
        await releaseDecoders.future;
        return PaintingBinding.instance.instantiateImageCodecWithSize(
          buffer,
          getTargetSize: getTargetSize,
        );
      }

      final providers = <LocalGalleryThumbnailProvider>[];
      for (var index = 0; index < 8; index++) {
        final provider = LocalGalleryThumbnailProvider(
          source: source,
          target: LocalGalleryThumbnailTarget(
            width: 128 + index * 32,
            height: 160,
          ),
        );
        providers.add(provider);
        LocalGalleryThumbnailMemoryCache.instance.register(provider);
        provider.loadImage(provider.cacheKey, delayedDecoder);
      }

      expect(
        LocalGalleryThumbnailMemoryCache.instance.statistics.activeDecodes,
        4,
      );
      expect(
        LocalGalleryThumbnailMemoryCache.instance.statistics.queuedDecodes,
        4,
      );
      for (final provider in providers) {
        await LocalGalleryThumbnailMemoryCache.instance.cancelPending(provider);
      }
      expect(
        LocalGalleryThumbnailMemoryCache.instance.statistics.queuedDecodes,
        0,
      );

      releaseDecoders.complete();
      for (var attempt = 0; attempt < 100; attempt++) {
        if (LocalGalleryThumbnailMemoryCache
                .instance
                .statistics
                .activeDecodes ==
            0) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(
        LocalGalleryThumbnailMemoryCache.instance.statistics.activeDecodes,
        0,
      );
    });

    test('共享同一缓存键的卡片只在最后一个 owner 离开时取消', () async {
      final sourceFile = File('assets/icons/tray_icon.png');
      final stat = await sourceFile.stat();
      final source = LocalGallerySourceIdentity.fromRecord(
        path: sourceFile.path,
        size: stat.size,
        modifiedAt: stat.modified,
      );
      final first = LocalGalleryThumbnailProvider(
        source: source,
        target: const LocalGalleryThumbnailTarget(width: 192, height: 224),
      );
      final second = LocalGalleryThumbnailProvider(
        source: source,
        target: const LocalGalleryThumbnailTarget(width: 192, height: 224),
      );
      final releaseDecoder = Completer<void>();
      Future<ui.Codec> delayedDecoder(
        ui.ImmutableBuffer buffer, {
        ui.TargetImageSize Function(int, int)? getTargetSize,
      }) async {
        await releaseDecoder.future;
        return PaintingBinding.instance.instantiateImageCodecWithSize(
          buffer,
          getTargetSize: getTargetSize,
        );
      }

      LocalGalleryThumbnailMemoryCache.instance
        ..register(first)
        ..register(second);
      first.loadImage(first.cacheKey, delayedDecoder);
      expect(
        LocalGalleryThumbnailMemoryCache.instance.statistics.activeDecodes,
        1,
      );

      await LocalGalleryThumbnailMemoryCache.instance.cancelPending(first);
      expect(
        LocalGalleryThumbnailMemoryCache.instance.statistics.activeDecodes,
        1,
      );
      await LocalGalleryThumbnailMemoryCache.instance.cancelPending(second);
      releaseDecoder.complete();
      for (var attempt = 0; attempt < 100; attempt++) {
        if (LocalGalleryThumbnailMemoryCache
                .instance
                .statistics
                .activeDecodes ==
            0) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(
        LocalGalleryThumbnailMemoryCache.instance.statistics.activeDecodes,
        0,
      );
    });

    test('源文件在记录后变化时拒绝旧请求回填', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nai_local_thumbnail_stale_',
      );
      addTearDown(() async => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}${Platform.pathSeparator}image.png');
      await file.writeAsBytes(
        img.encodePng(img.Image(width: 32, height: 32)),
        flush: true,
      );
      final oldStat = await file.stat();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await file.writeAsBytes(
        img.encodePng(img.Image(width: 64, height: 32)),
        flush: true,
      );
      final provider = LocalGalleryThumbnailProvider(
        source: LocalGallerySourceIdentity.fromRecord(
          path: file.path,
          size: oldStat.size,
          modifiedAt: oldStat.modified,
        ),
        target: const LocalGalleryThumbnailTarget(width: 64, height: 64),
      );

      await expectLater(_resolve(provider), throwsA(isA<StateError>()));
    });
  });
}

Future<ImageInfo> _resolve(ImageProvider provider) {
  final completer = Completer<ImageInfo>();
  late ImageStreamListener listener;
  final stream = provider.resolve(ImageConfiguration.empty);
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete(info);
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return completer.future.timeout(const Duration(seconds: 5));
}
