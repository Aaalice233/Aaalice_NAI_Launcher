import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;

import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/watermark/watermark_settings.dart';
import '../../data/services/metadata/unified_metadata_parser.dart';
import '../utils/image_share_sanitizer.dart';
import 'watermark_scene.dart';

class WatermarkCancelledException implements Exception {
  const WatermarkCancelledException();
}

class WatermarkRenderException implements Exception {
  const WatermarkRenderException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class WatermarkCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const WatermarkCancelledException();
  }
}

class WatermarkRenderRequest {
  const WatermarkRenderRequest({
    required this.sourceBytes,
    required this.settings,
    required this.preserveMetadata,
    this.logoBytes,
    this.sourceFileName = 'image.png',
  });

  final Uint8List sourceBytes;
  final Uint8List? logoBytes;
  final WatermarkSettings settings;
  final bool preserveMetadata;
  final String sourceFileName;
}

class WatermarkRenderResult {
  const WatermarkRenderResult({
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

class WatermarkRenderService {
  WatermarkRenderService._();

  static const int _maxSourcePixels = 64000000;
  static const int _maxSourceDimension = 32768;

  static Future<WatermarkRenderResult> render(
    WatermarkRenderRequest request, {
    WatermarkCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? WatermarkCancellationToken();
    token.throwIfCancelled();
    if (!request.settings.textStyle.enabled &&
        !request.settings.logoStyle.enabled) {
      throw const WatermarkRenderException(
        'Enable at least one watermark layer before saving.',
      );
    }

    ui.ImmutableBuffer? sourceBuffer;
    ui.ImageDescriptor? sourceDescriptor;
    ui.Codec? sourceCodec;
    ui.Codec? logoCodec;
    ui.Image? sourceImage;
    ui.Image? logoImage;
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
        throw const WatermarkRenderException(
          'The source image dimensions exceed the safe full-resolution rendering limit.',
        );
      }
      sourceDescriptor.dispose();
      sourceDescriptor = null;
      sourceBuffer.dispose();
      sourceBuffer = null;
      sourceCodec = await ui.instantiateImageCodec(request.sourceBytes);
      if (sourceCodec.frameCount != 1) {
        throw const WatermarkRenderException(
          'Choose a static source image. Animated images are not supported.',
        );
      }
      sourceImage = (await sourceCodec.getNextFrame()).image;
      token.throwIfCancelled();

      final logoBytes = request.logoBytes;
      if (request.settings.logoStyle.enabled) {
        if (logoBytes == null || logoBytes.isEmpty) {
          throw const WatermarkRenderException(
            'The selected logo is missing. Choose the logo again.',
          );
        }
        logoCodec = await ui.instantiateImageCodec(logoBytes);
        if (logoCodec.frameCount != 1) {
          throw const WatermarkRenderException(
            'Animated logos are not supported. Choose a static image.',
          );
        }
        logoImage = (await logoCodec.getNextFrame()).image;
        token.throwIfCancelled();
      }

      final width = sourceImage.width;
      final height = sourceImage.height;
      if (width <= 0 || height <= 0) {
        throw const WatermarkRenderException(
          'The source image size is invalid.',
        );
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(sourceImage, ui.Offset.zero, ui.Paint());
      WatermarkScene.paint(
        canvas: canvas,
        canvasSize: ui.Size(width.toDouble(), height.toDouble()),
        settings: request.settings,
        logo: logoImage,
      );
      final picture = recorder.endRecording();
      outputImage = await picture.toImage(width, height);
      picture.dispose();
      sourceImage.dispose();
      sourceImage = null;
      logoImage?.dispose();
      logoImage = null;
      sourceCodec.dispose();
      sourceCodec = null;
      logoCodec?.dispose();
      logoCodec = null;
      token.throwIfCancelled();
      final byteData = await outputImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw const WatermarkRenderException('PNG encoding failed.');
      }
      final sanitized =
          await ImageShareSanitizer.prepareForCopyOrDragInBackground(
            byteData.buffer.asUint8List(),
            fileName: 'watermarked.png',
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

      return WatermarkRenderResult(
        bytes: outputBytes,
        fileName: buildOutputFileName(request.sourceFileName),
        width: width,
        height: height,
        metadataPreserved: metadataPreserved,
      );
    } on WatermarkCancelledException {
      rethrow;
    } on WatermarkRenderException {
      rethrow;
    } on Object catch (error) {
      throw WatermarkRenderException(
        'The image or logo could not be decoded and rendered.',
        error,
      );
    } finally {
      outputImage?.dispose();
      logoImage?.dispose();
      sourceImage?.dispose();
      logoCodec?.dispose();
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
    return '${safeBase.isEmpty ? 'image' : safeBase}_watermarked.png';
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
      throw WatermarkRenderException(
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
      throw WatermarkRenderException(
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
