import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/cache/local_gallery_thumbnail_provider.dart';
import 'package:path/path.dart' as p;

/// Controlled cold-cache benchmark for the retired fixed-JPEG pipeline and
/// the dynamic native decoder. Run explicitly with:
///
/// flutter test tool/diagnostics/local_gallery_thumbnail_benchmark_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local gallery thumbnail cold-cache benchmark',
    () async {
      const sampleCount = 12;
      const sourceWidth = 1600;
      const sourceHeight = 1200;
      const logicalWidth = 180.0;
      const logicalHeight = 220.0;
      const devicePixelRatio = 2.0;
      final root = await Directory.systemTemp.createTemp(
        'nai_local_thumbnail_benchmark_',
      );
      addTearDown(() async {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await root.delete(recursive: true);
      });

      final sourceImage = img.Image(width: sourceWidth, height: sourceHeight);
      for (var y = 0; y < sourceHeight; y++) {
        for (var x = 0; x < sourceWidth; x++) {
          sourceImage.setPixelRgba(x, y, x % 256, y % 256, (x + y) % 256, 255);
        }
      }
      final sourceBytes = img.encodePng(sourceImage, level: 1);
      final sources = <File>[];
      for (var index = 0; index < sampleCount; index++) {
        final file = File('${root.path}${Platform.pathSeparator}$index.png');
        await file.writeAsBytes(sourceBytes, flush: true);
        sources.add(file);
      }

      final legacyDirectory = Directory(
        '${root.path}${Platform.pathSeparator}.thumbs',
      );
      await legacyDirectory.create();
      final legacyTimes = <int>[];
      final legacyWatch = Stopwatch()..start();
      for (final source in sources) {
        final itemWatch = Stopwatch()..start();
        final decoded = img.decodeImage(await source.readAsBytes())!;
        final resized = img.copyResize(
          decoded,
          width: 180,
          maintainAspect: true,
          interpolation: img.Interpolation.cubic,
        );
        await File(
          '${legacyDirectory.path}${Platform.pathSeparator}'
          '${p.basenameWithoutExtension(source.path)}.small.thumb.jpg',
        ).writeAsBytes(img.encodeJpg(resized, quality: 82), flush: true);
        itemWatch.stop();
        legacyTimes.add(itemWatch.elapsedMicroseconds);
      }
      legacyWatch.stop();
      final legacyFiles = await legacyDirectory
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      final legacyDiskBytes = (await Future.wait<int>(
        legacyFiles.map((file) => file.length()),
      )).fold<int>(0, (sum, bytes) => sum + bytes);

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      final target = LocalGalleryThumbnailTarget.fromLogicalSize(
        logicalWidth: logicalWidth,
        logicalHeight: logicalHeight,
        devicePixelRatio: devicePixelRatio,
      );
      final dynamicTimes = <int>[];
      var decodedBytes = 0;
      var peakCacheBytes = 0;
      final dynamicWatch = Stopwatch()..start();
      for (final source in sources) {
        final stat = await source.stat();
        final provider = LocalGalleryThumbnailProvider(
          source: LocalGallerySourceIdentity.fromRecord(
            path: source.path,
            size: stat.size,
            modifiedAt: stat.modified,
          ),
          target: target,
        );
        final itemWatch = Stopwatch()..start();
        final info = await _resolve(provider);
        itemWatch.stop();
        dynamicTimes.add(itemWatch.elapsedMicroseconds);
        decodedBytes += info.sizeBytes;
        info.dispose();
        peakCacheBytes = math.max(
          peakCacheBytes,
          PaintingBinding.instance.imageCache.currentSizeBytes,
        );
      }
      dynamicWatch.stop();

      final newSize = LocalGalleryThumbnailProvider.calculateDecodeTarget(
        intrinsicWidth: sourceWidth,
        intrinsicHeight: sourceHeight,
        target: target,
        fit: LocalGalleryThumbnailFit.cover,
      );
      final newWidth = newSize.width!;
      final newHeight = newSize.height!;
      final legacyScaleShortfall = newWidth / 180;
      final report = <String, Object>{
        'sampleCount': sampleCount,
        'source': '${sourceWidth}x$sourceHeight PNG',
        'card': '${logicalWidth}x$logicalHeight @ ${devicePixelRatio}x',
        'legacy': {
          'elapsedMs': legacyWatch.elapsedMilliseconds,
          'p95ItemMs': _percentile95(legacyTimes) / 1000,
          'outputPixels': '180x135',
          'diskFiles': legacyFiles.length,
          'diskBytes': legacyDiskBytes,
          'estimatedDecodedBytes': sampleCount * 180 * 135 * 4,
        },
        'dynamic': {
          'elapsedMs': dynamicWatch.elapsedMilliseconds,
          'p95ItemMs': _percentile95(dynamicTimes) / 1000,
          'outputPixels': '${newWidth}x$newHeight',
          'diskFiles': 0,
          'diskBytes': 0,
          'decodedBytes': decodedBytes,
          'peakSharedCacheBytes': peakCacheBytes,
        },
        'quality': {
          'legacyLinearUpscaleAt2x': legacyScaleShortfall,
          'dynamicMeetsCoverTarget':
              newWidth >= target.width && newHeight >= target.height,
        },
      };
      // Machine-readable output is intentionally stable for before/after runs.
      // ignore: avoid_print
      print(const JsonEncoder.withIndent('  ').convert(report));

      expect(legacyFiles, hasLength(sampleCount));
      expect(newWidth, greaterThanOrEqualTo(target.width));
      expect(newHeight, greaterThanOrEqualTo(target.height));
      expect(legacyScaleShortfall, greaterThan(2));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

int _percentile95(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[((sorted.length - 1) * 0.95).round()];
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
  return completer.future.timeout(const Duration(seconds: 30));
}
