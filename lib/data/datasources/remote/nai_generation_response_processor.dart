import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

import '../../../core/models/image_generation_artifact.dart';
import '../../../core/network/request_builders/nai_image_request_builder.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/inpaint_mask_utils.dart';
import '../../../core/utils/isolate_pool.dart';
import '../../../core/utils/nai_api_utils.dart';
import '../../../core/utils/zip_utils.dart';
import '../../models/image/image_params.dart';
import '../../models/image/image_stream_chunk.dart';

class NaiGenerationResponseContext {
  const NaiGenerationResponseContext({
    required this.originalParams,
    required this.focusedRequest,
    required this.requestBuildResult,
  });

  final ImageParams originalParams;
  final FocusedInpaintRequest? focusedRequest;
  final NAIImageRequestBuildResult requestBuildResult;
}

class NaiGenerationResponseProcessor {
  Future<FocusedInpaintRequest?> prepareFocusedInpaint(
    ImageParams params, {
    required bool enabled,
    required double minimumContextMegaPixels,
    Rect? focusedSelectionRect,
  }) async {
    if (!enabled ||
        params.action != ImageGenerationAction.infill ||
        params.sourceImage == null ||
        params.maskImage == null) {
      return null;
    }

    final request = await FocusedInpaintUtils.prepareRequestAsync(
      sourceImage: params.sourceImage!,
      maskImage: params.maskImage!,
      focusedSelectionRect: focusedSelectionRect,
      minContextMegaPixels: minimumContextMegaPixels,
    );
    if (request != null) {
      AppLogger.d(
        'Focused inpaint prepared: crop=${request.crop.x},${request.crop.y},${request.crop.width}x${request.crop.height}, target=${request.targetWidth}x${request.targetHeight}, minContextArea=${minimumContextMegaPixels.round()}, focusRect=$focusedSelectionRect',
        'ImgGen',
      );
    }
    return request;
  }

  ImageParams applyFocusedRequest(
    ImageParams params,
    FocusedInpaintRequest? focusedRequest,
  ) {
    if (focusedRequest == null) return params;
    return params.copyWith(
      sourceImage: focusedRequest.requestSourceImage,
      maskImage: focusedRequest.requestMaskImage,
      width: focusedRequest.targetWidth,
      height: focusedRequest.targetHeight,
    );
  }

  Future<List<ImageGenerationArtifact>> processZip(
    Uint8List zipBytes,
    NaiGenerationResponseContext context,
  ) async {
    final images = ZipUtils.extractAllImages(zipBytes);
    final artifacts = await Future.wait(
      images.map((image) => composeImage(image, context)),
    );
    if (artifacts.isEmpty) {
      throw Exception('No images found in response');
    }
    return artifacts;
  }

  Stream<ImageStreamChunk> processMessagePackStream(
    Stream<Uint8List> responseStream,
    NaiGenerationResponseContext context, {
    required CancelToken cancelToken,
  }) async* {
    final buffer = <int>[];
    final completedSamples = <int>{};
    final expectedSamples = context.originalParams.nSamples <= 0
        ? 1
        : context.originalParams.nSamples;
    var messageCount = 0;

    await for (final chunk in responseStream) {
      if (cancelToken.isCancelled) {
        yield ImageStreamChunk.error('Cancelled');
        return;
      }
      buffer.addAll(chunk);

      while (buffer.length >= 4) {
        final messageLength = _readLength(buffer);
        if (buffer.length < 4 + messageLength) break;
        final messageBytes = Uint8List.fromList(
          buffer.sublist(4, 4 + messageLength),
        );
        buffer.removeRange(0, 4 + messageLength);
        messageCount += 1;

        try {
          final message = _decodeMessage(messageBytes);
          if (message == null) continue;
          final eventType = message['event_type']?.toString();
          final sampleIndex = _optionalInt(message['samp_ix']) ?? 0;

          if (eventType == 'error' || message.containsKey('error')) {
            final error =
                message['message'] ??
                message['error'] ??
                'Stream generation failed';
            yield ImageStreamChunk.error(error.toString());
            return;
          }

          final image = _decodeImage(message['image']);
          if (image == null || image.isEmpty) continue;
          if (eventType == 'final') {
            final artifact = await composeImage(image, context);
            completedSamples.add(sampleIndex);
            yield ImageStreamChunk.complete(
              artifact.displayImageBytes,
              sampleIndex: sampleIndex,
            );
          } else if (eventType == null ||
              eventType.isEmpty ||
              eventType == 'intermediate') {
            final currentStep =
                (_optionalInt(message['step_ix']) ?? messageCount) + 1;
            final totalSteps = context.originalParams.steps;
            yield ImageStreamChunk.progress(
              progress: (currentStep / totalSteps).clamp(0.0, 0.99),
              sampleIndex: sampleIndex,
              currentStep: currentStep,
              totalSteps: totalSteps,
              previewImage: image,
              focusedPreviewPlacement: previewPlacement(context),
            );
          }
        } catch (error) {
          AppLogger.w('Stream msg parse error: $error', 'Stream');
        }
      }
    }

    if (buffer.isNotEmpty) {
      try {
        final bytes = Uint8List.fromList(buffer);
        if (_isZip(bytes)) {
          final images = ZipUtils.extractAllImages(bytes);
          for (var index = 0; index < images.length; index += 1) {
            final artifact = await composeImage(images[index], context);
            yield ImageStreamChunk.complete(
              artifact.displayImageBytes,
              sampleIndex: index,
            );
          }
          if (images.isNotEmpty) return;
        }

        final fallbackImage = _decodeFallbackMessage(bytes);
        if (fallbackImage != null && fallbackImage.isNotEmpty) {
          final artifact = await composeImage(fallbackImage, context);
          yield ImageStreamChunk.complete(artifact.displayImageBytes);
          return;
        }
        yield ImageStreamChunk.error('No final image received from stream');
      } catch (error) {
        AppLogger.e('Failed to parse final stream data: $error', 'Stream');
        yield ImageStreamChunk.error('Failed to parse response');
      }
    } else if (completedSamples.length < expectedSamples) {
      yield ImageStreamChunk.error('No final image received from stream');
    }
  }

  Future<String> formatStreamDioError(DioException error) async {
    if (error.type == DioExceptionType.cancel) return 'Cancelled';
    if (error.response?.data is! ResponseBody) {
      return NAIApiUtils.formatDioError(error);
    }

    try {
      final body = error.response!.data as ResponseBody;
      final bytes = <int>[];
      await for (final chunk in body.stream) {
        bytes.addAll(chunk);
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          return 'API_ERROR_${error.response?.statusCode}|${decoded['message'] ?? decoded['error'] ?? text}';
        }
      } catch (parseError) {
        AppLogger.w('Failed to parse error JSON: $parseError', 'ImgGen');
      }
      return 'API_ERROR_${error.response?.statusCode}|$text';
    } catch (readError) {
      AppLogger.e('Failed to read error response: $readError', 'ImgGen');
      return NAIApiUtils.formatDioError(error);
    }
  }

  FocusedStreamPreviewPlacement? previewPlacement(
    NaiGenerationResponseContext context,
  ) {
    final params = context.originalParams;
    if (params.action != ImageGenerationAction.infill || params.isOutpaint) {
      return null;
    }
    final mask =
        context.requestBuildResult.inpaintMaskArtifacts?.compositeMaskBytes;
    if (mask == null) return null;

    final focusedRequest = context.focusedRequest;
    if (focusedRequest == null) {
      final source = context.requestBuildResult.normalizedSourceImageBytes;
      if (source == null) return null;
      return FocusedStreamPreviewPlacement(
        sourceImage: source,
        maskImage: mask,
        xPercent: 0,
        yPercent: 0,
        widthPercent: 1,
        heightPercent: 1,
      );
    }

    final source = params.sourceImage;
    final sourceWidth = focusedRequest.originalSourceWidth;
    final sourceHeight = focusedRequest.originalSourceHeight;
    if (source == null || sourceWidth <= 0 || sourceHeight <= 0) return null;
    return FocusedStreamPreviewPlacement(
      sourceImage: source,
      maskImage: mask,
      xPercent: focusedRequest.crop.x / sourceWidth,
      yPercent: focusedRequest.crop.y / sourceHeight,
      widthPercent: focusedRequest.crop.width / sourceWidth,
      heightPercent: focusedRequest.crop.height / sourceHeight,
    );
  }

  Future<ImageGenerationArtifact> composeImage(
    Uint8List imageBytes,
    NaiGenerationResponseContext context,
  ) {
    final params = context.originalParams;
    final focusedRequest = context.focusedRequest;
    final buildResult = context.requestBuildResult;
    final maskArtifacts = buildResult.inpaintMaskArtifacts;

    if (focusedRequest != null) {
      if (maskArtifacts == null) {
        return Future.value(
          ImageGenerationArtifact(displayImageBytes: imageBytes),
        );
      }
      return focusedRequest.composeGeneratedImageArtifactAsync(
        imageBytes,
        maskArtifacts,
      );
    }
    if (params.isOutpaint) {
      return Future.value(
        ImageGenerationArtifact(displayImageBytes: imageBytes),
      );
    }
    final sourceImage = buildResult.normalizedSourceImageBytes;
    if (params.action != ImageGenerationAction.infill ||
        sourceImage == null ||
        maskArtifacts == null) {
      return Future.value(
        ImageGenerationArtifact(displayImageBytes: imageBytes),
      );
    }

    return ComputeGate().runIsolate(() {
      return InpaintMaskUtils.composeGeneratedImageArtifact(
        normalizedSourceImage: sourceImage,
        compositeMaskImage: maskArtifacts.compositeMaskBytes,
        generatedImage: imageBytes,
      );
    });
  }

  Map<String, dynamic>? _decodeMessage(Uint8List bytes) {
    final decoded = msgpack.deserialize(bytes);
    if (decoded is! Map) return null;
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Uint8List? _decodeFallbackMessage(Uint8List bytes) {
    if (bytes.length < 4) return null;
    final messageLength = _readLength(bytes);
    if (bytes.length < 4 + messageLength) return null;
    final message = _decodeMessage(
      Uint8List.fromList(bytes.sublist(4, 4 + messageLength)),
    );
    return _decodeImage(message?['data']);
  }

  Uint8List? _decodeImage(Object? value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is String && value.isNotEmpty) {
      try {
        return Uint8List.fromList(base64Decode(value));
      } catch (error) {
        AppLogger.w('Failed to decode base64 image data: $error', 'Stream');
      }
    }
    return null;
  }

  int _readLength(List<int> bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  bool _isZip(Uint8List bytes) {
    return bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4b;
  }

  int? _optionalInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
