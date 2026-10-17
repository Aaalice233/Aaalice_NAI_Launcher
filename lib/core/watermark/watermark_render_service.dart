import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/watermark/watermark_settings.dart';
import '../../data/services/metadata/unified_metadata_parser.dart';
import '../derivatives/derivative_registry.dart';
import '../derivatives/derivative_render.dart';
import '../utils/image_share_sanitizer.dart';
import '../utils/isolate_pool.dart';
import 'watermark_scene.dart';
import 'watermark_source_analysis.dart';
import 'watermark_tone.dart';

class WatermarkRenderException implements Exception {
  const WatermarkRenderException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
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

class WatermarkRenderResult implements DerivativeRenderedCopy {
  const WatermarkRenderResult({
    required this.bytes,
    required this.fileName,
    required this.width,
    required this.height,
    required this.metadataPreserved,
  });

  @override
  final Uint8List bytes;
  @override
  final String fileName;
  final int width;
  final int height;
  final bool metadataPreserved;
}

typedef WatermarkRenderOperation =
    Future<WatermarkRenderResult> Function(
      WatermarkRenderRequest request, {
      DerivativeRenderCancellationToken? cancellationToken,
    });

typedef WatermarkPreviewDecoder =
    Future<ui.Image> Function(Uint8List bytes, {bool requireStatic});

class WatermarkRenderService {
  WatermarkRenderService._();

  static const int _maxSourcePixels = 64000000;
  static const int _maxSourceDimension = 32768;
  static const int _previewEdgeLimit = 2048;

  /// 编辑器预览用的缩小解码；保存时由 [render] 按原尺寸重新解码。
  static Future<ui.Image> decodePreview(
    Uint8List bytes, {
    bool requireStatic = false,
  }) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longestEdge = math.max(descriptor.width, descriptor.height);
      final scale = longestEdge > _previewEdgeLimit
          ? _previewEdgeLimit / longestEdge
          : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      if (requireStatic && codec.frameCount != 1) {
        throw const WatermarkRenderException(
          'Choose a static source image. Animated images are not supported.',
        );
      }
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static Future<WatermarkRenderResult> render(
    WatermarkRenderRequest request, {
    DerivativeRenderCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? DerivativeRenderCancellationToken();
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
      final canvasSize = ui.Size(width.toDouble(), height.toDouble());
      final decision = await _decideAutoAdjust(
        request,
        canvasSize: canvasSize,
        logo: logoImage,
      );
      token.throwIfCancelled();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(sourceImage, ui.Offset.zero, ui.Paint());
      WatermarkScene.paint(
        canvas: canvas,
        canvasSize: canvasSize,
        settings: request.settings,
        logo: logoImage,
        decision: decision,
      );
      final picture = recorder.endRecording();
      try {
        outputImage = await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }
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
      // 下一步要排 ComputeGate，已取消就不再占槽位
      token.throwIfCancelled();
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
        final transfer = await _preserveMetadataInBackground(
          request.sourceBytes,
          outputBytes,
        );
        outputBytes = transfer.bytes;
        metadataPreserved = transfer.preserved;
      }
      token.throwIfCancelled();

      return WatermarkRenderResult(
        bytes: outputBytes,
        fileName: DerivativeKind.watermark.outputFileName(
          request.sourceFileName,
        ),
        width: width,
        height: height,
        metadataPreserved: metadataPreserved,
      );
    } on DerivativeRenderCancelledException {
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

  static Future<WatermarkAutoDecision> _decideAutoAdjust(
    WatermarkRenderRequest request, {
    required ui.Size canvasSize,
    ui.Image? logo,
  }) async {
    final settings = request.settings;
    if (!settings.usesSourceAnalysis) return WatermarkAutoDecision.none;
    final analysis = await WatermarkSourceAnalysis.fromEncoded(
      request.sourceBytes,
    );
    final logoBytes = request.logoBytes;
    final logoLuminance =
        settings.logoStyle.enabled &&
            settings.logoStyle.autoTone &&
            logoBytes != null
        ? await WatermarkLogoLuminance.fromEncoded(logoBytes)
        : null;
    return WatermarkScene.decide(
      canvasSize: canvasSize,
      settings: settings,
      analysis: analysis,
      logo: logo,
      logoLuminance: logoLuminance,
    );
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

Future<_MetadataTransfer> _preserveMetadataInBackground(
  Uint8List source,
  Uint8List targetPng,
) => ComputeGate().runIsolate(
  () => WatermarkRenderService._preserveSupportedMetadata(
    source: source,
    targetPng: targetPng,
  ),
);

class _MetadataTransfer {
  const _MetadataTransfer({required this.bytes, required this.preserved});

  final Uint8List bytes;
  final bool preserved;
}
