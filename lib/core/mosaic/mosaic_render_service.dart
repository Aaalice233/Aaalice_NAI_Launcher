import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/mosaic/mosaic_settings.dart';
import '../../data/services/metadata/unified_metadata_parser.dart';
import '../utils/image_share_sanitizer.dart';

class MosaicCancelledException implements Exception {
  const MosaicCancelledException();
}

class MosaicRenderException implements Exception {
  const MosaicRenderException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class MosaicCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const MosaicCancelledException();
  }
}

class MosaicRenderRequest {
  const MosaicRenderRequest({
    required this.sourceBytes,
    required this.settings,
    required this.regions,
    required this.preserveMetadata,
    this.sourceFileName = 'image.png',
  });

  final Uint8List sourceBytes;
  final MosaicSettings settings;
  final List<MosaicRegion> regions;
  final bool preserveMetadata;
  final String sourceFileName;
}

class MosaicRenderResult {
  const MosaicRenderResult({
    required this.bytes,
    required this.fileName,
    required this.width,
    required this.height,
    required this.metadataPreserved,
  });

  final Uint8List bytes;
  final String fileName;
  final int width;
  final int height;
  final bool metadataPreserved;
}

/// Full-resolution redaction renderer shared by the editor and export flow.
class MosaicRenderService {
  MosaicRenderService._();

  static const int _maxSourcePixels = 64000000;
  static const int _maxSourceDimension = 32768;

  /// Builds the processed image displayed below the editable mask.
  ///
  /// Pixelation intentionally returns a small image. The caller must scale it
  /// with [ui.FilterQuality.none] so the blocks stay crisp.
  static Future<ui.Image?> buildProcessedImage(
    ui.Image source,
    MosaicSettings settings,
  ) async {
    if (settings.effect == MosaicEffect.solid) return null;

    if (settings.effect == MosaicEffect.pixelate) {
      final shortEdge = math.min(source.width, source.height).toDouble();
      final blockPixels = math.max(2.0, shortEdge * settings.pixelSizeRatio);
      final targetWidth = math.max(1, (source.width / blockPixels).round());
      final targetHeight = math.max(1, (source.height / blockPixels).round());
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(
          0,
          0,
          source.width.toDouble(),
          source.height.toDouble(),
        ),
        ui.Rect.fromLTWH(
          0,
          0,
          targetWidth.toDouble(),
          targetHeight.toDouble(),
        ),
        ui.Paint()..filterQuality = ui.FilterQuality.low,
      );
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(targetWidth, targetHeight);
      } finally {
        picture.dispose();
      }
    }

    final sigma = math.max(
      0.5,
      math.min(source.width, source.height) * settings.blurSigmaRatio,
    );
    final bounds = ui.Rect.fromLTWH(
      0,
      0,
      source.width.toDouble(),
      source.height.toDouble(),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.saveLayer(
      bounds,
      ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.clamp,
        ),
    );
    canvas.drawImage(source, ui.Offset.zero, ui.Paint());
    canvas.restore();
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(source.width, source.height);
    } finally {
      picture.dispose();
    }
  }

  static ui.Path buildMaskPath({
    required ui.Size size,
    required MosaicSettings settings,
    required List<MosaicRegion> regions,
  }) {
    final selected = ui.Path();
    for (final rawRegion in regions) {
      final region = rawRegion.normalized();
      if (!region.isUsable) continue;
      selected.addPath(
        _regionPath(size: size, settings: settings, region: region),
        ui.Offset.zero,
      );
    }
    if (!settings.invertMask) return selected;
    final whole = ui.Path()..addRect(ui.Offset.zero & size);
    try {
      return ui.Path.combine(ui.PathOperation.difference, whole, selected);
    } on Object {
      final fallback = ui.Path()
        ..fillType = ui.PathFillType.evenOdd
        ..addRect(ui.Offset.zero & size)
        ..addPath(selected, ui.Offset.zero);
      return fallback;
    }
  }

  static ui.Path _regionPath({
    required ui.Size size,
    required MosaicSettings settings,
    required MosaicRegion region,
  }) {
    final path = ui.Path();
    if (region.shape == MosaicShape.roundedRectangle) {
      final rect = ui.Rect.fromLTWH(
        region.left * size.width,
        region.top * size.height,
        region.width * size.width,
        region.height * size.height,
      );
      final radius =
          math.min(rect.width, rect.height) * settings.cornerRadiusRatio;
      path.addRRect(
        ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)),
      );
      return path;
    }
    if (region.shape == MosaicShape.ellipse) {
      path.addOval(
        ui.Rect.fromLTWH(
          region.left * size.width,
          region.top * size.height,
          region.width * size.width,
          region.height * size.height,
        ),
      );
      return path;
    }

    if (region.points.isEmpty) return path;
    final radius = math.max(
      1.0,
      math.min(size.width, size.height) * region.brushSizeRatio / 2,
    );
    ui.Offset toOffset(MosaicPoint point) =>
        ui.Offset(point.x * size.width, point.y * size.height);
    var previous = toOffset(region.points.first);
    path.addOval(ui.Rect.fromCircle(center: previous, radius: radius));
    for (var i = 1; i < region.points.length; i++) {
      final current = toOffset(region.points[i]);
      final distance = (current - previous).distance;
      final steps = math.max(
        1,
        (distance / math.max(1.0, radius * 0.55)).ceil(),
      );
      for (var step = 1; step <= steps; step++) {
        final t = step / steps;
        final point = ui.Offset(
          previous.dx + (current.dx - previous.dx) * t,
          previous.dy + (current.dy - previous.dy) * t,
        );
        path.addOval(ui.Rect.fromCircle(center: point, radius: radius));
      }
      previous = current;
    }
    return path;
  }

  static Future<MosaicRenderResult> render(
    MosaicRenderRequest request, {
    MosaicCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? MosaicCancellationToken();
    token.throwIfCancelled();
    if (!request.regions.any((region) => region.isUsable)) {
      throw const MosaicRenderException(
        'Add at least one enabled redaction region before saving.',
      );
    }

    ui.ImmutableBuffer? sourceBuffer;
    ui.ImageDescriptor? sourceDescriptor;
    ui.Codec? sourceCodec;
    ui.Image? sourceImage;
    ui.Image? processedImage;
    ui.Image? outputImage;
    try {
      sourceBuffer = await ui.ImmutableBuffer.fromUint8List(
        request.sourceBytes,
      );
      sourceDescriptor = await ui.ImageDescriptor.encoded(sourceBuffer);
      if (sourceDescriptor.width <= 0 ||
          sourceDescriptor.height <= 0 ||
          sourceDescriptor.width > _maxSourceDimension ||
          sourceDescriptor.height > _maxSourceDimension ||
          sourceDescriptor.width * sourceDescriptor.height > _maxSourcePixels) {
        throw const MosaicRenderException(
          'The source image dimensions exceed the safe full-resolution rendering limit.',
        );
      }
      sourceDescriptor.dispose();
      sourceDescriptor = null;
      sourceBuffer.dispose();
      sourceBuffer = null;

      sourceCodec = await ui.instantiateImageCodec(request.sourceBytes);
      if (sourceCodec.frameCount != 1) {
        throw const MosaicRenderException(
          'Choose a static source image. Animated images are not supported.',
        );
      }
      sourceImage = (await sourceCodec.getNextFrame()).image;
      token.throwIfCancelled();

      final width = sourceImage.width;
      final height = sourceImage.height;
      if (width <= 0 || height <= 0) {
        throw const MosaicRenderException('The source image size is invalid.');
      }

      processedImage = await buildProcessedImage(sourceImage, request.settings);
      token.throwIfCancelled();

      final size = ui.Size(width.toDouble(), height.toDouble());
      final bounds = ui.Offset.zero & size;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(sourceImage, ui.Offset.zero, ui.Paint());
      canvas.save();
      canvas.clipPath(
        buildMaskPath(
          size: size,
          settings: request.settings,
          regions: request.regions,
        ),
        doAntiAlias: true,
      );
      final alpha = (request.settings.opacity * 255)
          .round()
          .clamp(0, 255)
          .toInt();
      if (request.settings.effect == MosaicEffect.solid) {
        canvas.drawRect(
          bounds,
          ui.Paint()
            ..color = ui.Color(
              request.settings.fillColorArgb,
            ).withAlpha(alpha),
        );
      } else if (processedImage != null) {
        canvas.drawImageRect(
          processedImage,
          ui.Rect.fromLTWH(
            0,
            0,
            processedImage.width.toDouble(),
            processedImage.height.toDouble(),
          ),
          bounds,
          ui.Paint()
            ..color = ui.Color.fromARGB(alpha, 255, 255, 255)
            ..filterQuality =
                request.settings.effect == MosaicEffect.pixelate
                ? ui.FilterQuality.none
                : ui.FilterQuality.medium,
        );
      }
      canvas.restore();

      final picture = recorder.endRecording();
      try {
        outputImage = await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }
      token.throwIfCancelled();

      final byteData = await outputImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw const MosaicRenderException('PNG encoding failed.');
      }
      final sanitized =
          await ImageShareSanitizer.prepareForCopyOrDragInBackground(
            byteData.buffer.asUint8List(),
            fileName: 'redacted.png',
            stripMetadata: true,
          );
      var outputBytes = sanitized.bytes;
      token.throwIfCancelled();

      var metadataPreserved = false;
      if (request.preserveMetadata) {
        final transfer = _preserveSupportedMetadata(
          source: request.sourceBytes,
          targetPng: outputBytes,
        );
        outputBytes = transfer.bytes;
        metadataPreserved = transfer.preserved;
      }
      token.throwIfCancelled();

      return MosaicRenderResult(
        bytes: outputBytes,
        fileName: buildOutputFileName(request.sourceFileName),
        width: width,
        height: height,
        metadataPreserved: metadataPreserved,
      );
    } on MosaicCancelledException {
      rethrow;
    } on MosaicRenderException {
      rethrow;
    } on Object catch (error) {
      throw MosaicRenderException(
        'The image could not be decoded or redacted.',
        error,
      );
    } finally {
      outputImage?.dispose();
      processedImage?.dispose();
      sourceImage?.dispose();
      sourceCodec?.dispose();
      sourceDescriptor?.dispose();
      sourceBuffer?.dispose();
    }
  }

  static String buildOutputFileName(String sourceFileName) {
    final leaf = p.basename(sourceFileName.trim());
    final base = p.basenameWithoutExtension(leaf);
    final safeBase = base
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return '${safeBase.isEmpty ? 'image' : safeBase}_redacted.png';
  }

  static _MetadataTransfer _preserveSupportedMetadata({
    required Uint8List source,
    required Uint8List targetPng,
  }) {
    final isPng = UnifiedMetadataParser.isPngHeader(source);
    final textData = isPng
        ? UnifiedMetadataParser.extractPngTextData(source)
        : const <String, String>{};
    final parsed = UnifiedMetadataParser.parseFromImage(source);
    if (textData.containsKey('Comment') && !parsed.success) {
      throw MosaicRenderException(
        'The source metadata is damaged or cannot be parsed: '
        '${parsed.errorMessage ?? 'unknown metadata format'}',
      );
    }

    var output = targetPng;
    try {
      output = UnifiedMetadataParser.copySupportedMetadata(
        source: source,
        targetPng: output,
      );
    } on FormatException catch (error) {
      throw MosaicRenderException(
        'The source metadata is damaged and cannot be preserved safely.',
        error,
      );
    }
    if (parsed.success && parsed.metadata != null) {
      final metadata = parsed.metadata!;
      if (!textData.containsKey('Comment')) {
        output = UnifiedMetadataParser.embedTextChunkOnly(
          output,
          'Comment',
          _commentFor(metadata),
        );
      }
      if (!textData.containsKey('Software') && metadata.software != null) {
        output = UnifiedMetadataParser.embedTextChunkOnly(
          output,
          'Software',
          metadata.software!,
        );
      }
      if (!textData.containsKey('Source') && metadata.source != null) {
        output = UnifiedMetadataParser.embedTextChunkOnly(
          output,
          'Source',
          metadata.source!,
        );
      }
      if (!textData.containsKey('Description') && metadata.prompt.isNotEmpty) {
        output = UnifiedMetadataParser.embedTextChunkOnly(
          output,
          'Description',
          metadata.prompt,
        );
      }
    }
    return _MetadataTransfer(
      bytes: output,
      preserved: textData.isNotEmpty || parsed.success,
    );
  }

  static String _commentFor(NaiImageMetadata metadata) {
    final raw = metadata.rawJson;
    if (raw != null && raw.trim().isNotEmpty) return raw;
    return jsonEncode({
      if (metadata.prompt.isNotEmpty) 'prompt': metadata.prompt,
      if (metadata.negativePrompt.isNotEmpty) 'uc': metadata.negativePrompt,
      if (metadata.seed != null) 'seed': metadata.seed,
      if (metadata.steps != null) 'steps': metadata.steps,
      if (metadata.width != null) 'width': metadata.width,
      if (metadata.height != null) 'height': metadata.height,
      if (metadata.scale != null) 'scale': metadata.scale,
      if (metadata.sampler != null) 'sampler': metadata.sampler,
      if (metadata.model != null) 'model': metadata.model,
      if (metadata.noiseSchedule != null)
        'noise_schedule': metadata.noiseSchedule,
    });
  }
}

class _MetadataTransfer {
  const _MetadataTransfer({required this.bytes, required this.preserved});

  final Uint8List bytes;
  final bool preserved;
}
