import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../../../core/krita/krita_bridge_models.dart';
import '../../../core/models/image_generation_artifact.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/image/image_stream_chunk.dart';

typedef KritaBridgeBaseParamsReader = ImageParams Function();
typedef KritaBridgePromptSnapshot = ({String prompt, String negativePrompt});
typedef KritaBridgePromptSnapshotReader =
    KritaBridgePromptSnapshot Function(ImageParams params);
typedef KritaBridgeMinimumContextReader = int Function();
typedef KritaBridgeBusyReader = bool Function();
typedef KritaBridgeSender = void Function(Map<String, dynamic> message);
typedef KritaBridgeStreamGenerator =
    Stream<ImageStreamChunk> Function(KritaBridgeGenerateRequest request);
typedef KritaBridgeFallbackGenerator =
    Future<List<ImageGenerationArtifact>> Function(
      KritaBridgeGenerateRequest request,
    );
typedef KritaBridgeExternalImageRegistrar =
    Future<String?> Function(
      Uint8List image, {
      required ImageParams params,
      bool? addToDisplay,
    });
typedef KritaBridgeCancelGeneration = void Function();
typedef KritaBridgeClock = DateTime Function();
typedef KritaBridgeActiveRequestReporter = void Function(String? requestId);

abstract class KritaBridgeMessageService {
  Future<void> handle(KritaBridgeMessage message);

  void handleClientDisconnected();

  void setActiveRequestReporter(KritaBridgeActiveRequestReporter reporter) {}
}

class KritaBridgeGenerateRequest {
  const KritaBridgeGenerateRequest({
    required this.id,
    required this.params,
    required this.focusedInpaintEnabled,
    required this.minimumContextPixels,
    this.focusedSelectionRect,
  });

  final String id;
  final ImageParams params;
  final bool focusedInpaintEnabled;
  final double minimumContextPixels;
  final Rect? focusedSelectionRect;
}

class KritaBridgeService implements KritaBridgeMessageService {
  KritaBridgeService({
    required KritaBridgeBaseParamsReader readBaseParams,
    required KritaBridgeSender send,
    required KritaBridgeBusyReader isUiGenerating,
    required KritaBridgeStreamGenerator generateStream,
    required KritaBridgeFallbackGenerator generateFallback,
    required KritaBridgeExternalImageRegistrar registerExternalImage,
    required KritaBridgeCancelGeneration cancelGeneration,
    KritaBridgePromptSnapshotReader? readPromptSnapshot,
    KritaBridgeMinimumContextReader? readMinimumContextPixels,
    KritaBridgeClock? clock,
    Duration failureCooldown = const Duration(seconds: 2),
  }) : _readBaseParams = readBaseParams,
       _readPromptSnapshot =
           readPromptSnapshot ??
           ((params) =>
               (prompt: params.prompt, negativePrompt: params.negativePrompt)),
       _send = send,
       _isUiGenerating = isUiGenerating,
       _generateStream = generateStream,
       _generateFallback = generateFallback,
       _registerExternalImage = registerExternalImage,
       _cancelGeneration = cancelGeneration,
       _clock = clock ?? DateTime.now,
       _failureCooldown = failureCooldown,
       _readMinimumContextPixels = readMinimumContextPixels ?? (() => 88);

  final KritaBridgeBaseParamsReader _readBaseParams;
  final KritaBridgePromptSnapshotReader _readPromptSnapshot;
  final KritaBridgeMinimumContextReader _readMinimumContextPixels;
  final KritaBridgeSender _send;
  final KritaBridgeBusyReader _isUiGenerating;
  final KritaBridgeStreamGenerator _generateStream;
  final KritaBridgeFallbackGenerator _generateFallback;
  final KritaBridgeExternalImageRegistrar _registerExternalImage;
  final KritaBridgeCancelGeneration _cancelGeneration;
  final KritaBridgeClock _clock;
  final Duration _failureCooldown;

  bool _isBridgeGenerating = false;
  String? _activeRequestId;
  bool _cancelled = false;
  DateTime? _failureCooldownUntil;
  KritaBridgeActiveRequestReporter? _activeRequestReporter;
  static const String _logTag = 'KritaBridge';

  bool get isBridgeGenerating => _isBridgeGenerating;

  @override
  void setActiveRequestReporter(KritaBridgeActiveRequestReporter reporter) {
    _activeRequestReporter = reporter;
  }

  @override
  void handleClientDisconnected() {
    if (!_isBridgeGenerating) {
      return;
    }

    _cancelled = true;
    _cancelGeneration();
    AppLogger.w(
      'Krita client disconnected during request $_activeRequestId; cancelled',
      _logTag,
    );
  }

  @override
  Future<void> handle(KritaBridgeMessage message) async {
    switch (message) {
      case KritaGetParamsMessage():
        _sendParams(message);
      case KritaCancelMessage():
        _cancel(message);
      case KritaImg2ImgMessage():
        await _generate(message.id, message.toImageParams(_readBaseParams()));
      case KritaInpaintMessage():
        await _generate(message.id, message.toImageParams(_readBaseParams()));
      case KritaPingMessage():
        break;
    }
  }

  void _sendParams(KritaGetParamsMessage message) {
    final params = _readBaseParams();
    final promptSnapshot = _readPromptSnapshot(params);
    _send({
      'type': 'params',
      'id': message.id,
      'prompt': promptSnapshot.prompt,
      'negative_prompt': promptSnapshot.negativePrompt,
      'model': params.model,
      'sampler': params.sampler,
      'steps': params.steps,
      'cfg_scale': params.scale,
      'seed': params.seed,
      'width': params.width,
      'height': params.height,
      'strength': params.strength,
      'noise': params.noise,
      'inpaint_strength': params.inpaintStrength,
      'minimum_context_pixels': _readMinimumContextPixels(),
    });
    AppLogger.d('Sent params snapshot to Krita: ${message.id}', _logTag);
  }

  void _cancel(KritaCancelMessage message) {
    if (!_isBridgeGenerating || _activeRequestId != message.id) {
      _sendError(
        message.id,
        KritaBridgeErrorCode.invalidRequest,
        'No active Krita request matches this id.',
      );
      return;
    }

    _cancelled = true;
    _cancelGeneration();
    _send({'type': 'cancelled', 'id': message.id});
    AppLogger.i('Cancelled Krita request: ${message.id}', _logTag);
  }

  Future<void> _generate(String id, KritaImageParamsMapping mapping) async {
    if (_isUiGenerating() || _isBridgeGenerating) {
      AppLogger.w('Rejected Krita request as busy: $id', _logTag);
      _sendError(
        id,
        KritaBridgeErrorCode.busy,
        'Launcher is already generating.',
      );
      return;
    }

    final cooldownUntil = _failureCooldownUntil;
    if (cooldownUntil != null && _clock().isBefore(cooldownUntil)) {
      AppLogger.w(
        'Rejected Krita request during failure cooldown: $id',
        _logTag,
      );
      _sendError(
        id,
        KritaBridgeErrorCode.rateLimited,
        'Please wait before retrying after a failed Krita request.',
      );
      return;
    }

    final request = KritaBridgeGenerateRequest(
      id: id,
      params: mapping.params.copyWith(nSamples: 1),
      focusedInpaintEnabled: mapping.focusedInpaintEnabled,
      minimumContextPixels: mapping.minimumContextPixels.toDouble(),
      focusedSelectionRect: _resolveFocusedSelectionRect(mapping),
    );

    _isBridgeGenerating = true;
    _activeRequestId = id;
    _activeRequestReporter?.call(id);
    _cancelled = false;
    AppLogger.i(
      'Accepted Krita request: $id action=${request.params.action.name}',
      _logTag,
    );

    try {
      final artifact = await _generateImage(request);
      if (_cancelled) {
        return;
      }
      if (artifact == null) {
        _startFailureCooldown();
        _sendError(
          id,
          KritaBridgeErrorCode.streamInterrupted,
          'Generation ended without a final image.',
        );
        return;
      }

      final savedPath = await _registerExternalImage(
        artifact.displayImageBytes,
        params: request.params,
        addToDisplay: true,
      );
      _sendResult(
        request,
        artifact.transparentPatchBytes ?? artifact.displayImageBytes,
        savedPath: savedPath,
      );
      AppLogger.i('Completed Krita request: ${request.id}', _logTag);
    } catch (error) {
      if (!_cancelled) {
        final code = _mapErrorCode(error);
        AppLogger.e(
          'Krita request failed: $id code=${code.value}',
          null,
          null,
          _logTag,
        );
        _startFailureCooldown();
        _sendError(id, code, _publicErrorMessage(code));
      }
    } finally {
      _isBridgeGenerating = false;
      _activeRequestId = null;
      _activeRequestReporter?.call(null);
      _cancelled = false;
    }
  }

  Rect? _resolveFocusedSelectionRect(KritaImageParamsMapping mapping) {
    final selection = _toRect(mapping.selectionRect);
    final sourceImage = mapping.params.sourceImage;
    if (!mapping.focusedInpaintEnabled ||
        selection == null ||
        sourceImage == null) {
      return selection;
    }
    img.Image? decoded;
    try {
      decoded = img.decodeImage(sourceImage);
    } catch (_) {
      return selection;
    }
    if (decoded == null) return selection;
    return FocusedInpaintUtils.constrainSelectionRect(
          sourceWidth: decoded.width,
          sourceHeight: decoded.height,
          selectionRect: selection,
          minContextMegaPixels: mapping.minimumContextPixels.toDouble(),
        ) ??
        selection;
  }

  Future<ImageGenerationArtifact?> _generateImage(
    KritaBridgeGenerateRequest request,
  ) async {
    if (_shouldUseDirectFallback(request)) {
      final fallback = await _generateFallback(request);
      return fallback.isEmpty ? null : fallback.first;
    }

    Uint8List? finalImage;
    var streamingUnsupported = false;

    try {
      await for (final chunk in _generateStream(request)) {
        if (_cancelled) {
          return null;
        }

        if (chunk.hasError) {
          if (_isStreamingUnsupported(chunk.error ?? '')) {
            streamingUnsupported = true;
            break;
          }
          throw Exception(chunk.error);
        }

        if (chunk.hasPreview) {
          _sendProgress(request, chunk);
        }

        if (chunk.isComplete && chunk.hasFinalImage) {
          finalImage = chunk.finalImage;
        }
      }
    } catch (error) {
      if (!_isStreamingUnsupported(error.toString())) {
        rethrow;
      }
      streamingUnsupported = true;
    }

    if (_cancelled) {
      return null;
    }

    if (!streamingUnsupported && finalImage != null) {
      return ImageGenerationArtifact(displayImageBytes: finalImage);
    }

    final fallback = await _generateFallback(request);
    if (_cancelled || fallback.isEmpty) {
      if (streamingUnsupported) {
        throw Exception(
          'streaming is not allowed and fallback did not return an image',
        );
      }
      return null;
    }
    AppLogger.i(
      'Used fallback generation for Krita request: ${request.id}',
      _logTag,
    );
    return fallback.first;
  }

  void _startFailureCooldown() {
    if (_failureCooldown <= Duration.zero) {
      _failureCooldownUntil = null;
      return;
    }
    _failureCooldownUntil = _clock().add(_failureCooldown);
  }

  void _sendProgress(
    KritaBridgeGenerateRequest request,
    ImageStreamChunk chunk,
  ) {
    _send({
      'type': 'progress',
      'id': request.id,
      if (chunk.currentStep != null) 'step': chunk.currentStep,
      if (chunk.totalSteps != null) 'total_steps': chunk.totalSteps,
      'progress': chunk.progress.clamp(0.0, 1.0),
      if (chunk.previewImage != null)
        'preview_image': base64Encode(chunk.previewImage!),
    });
  }

  void _sendResult(
    KritaBridgeGenerateRequest request,
    Uint8List image, {
    String? savedPath,
  }) {
    _send({
      'type': 'result',
      'id': request.id,
      'image': base64Encode(image),
      'name': _resultName(request.params.action),
      if (savedPath != null && savedPath.isNotEmpty) 'saved_path': savedPath,
      'params': _paramsMetadata(request.params),
    });
  }

  String _resultName(ImageGenerationAction action) {
    final now = DateTime.now();
    final time =
        '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}';
    return switch (action) {
      ImageGenerationAction.infill => 'NAI Inpaint $time',
      ImageGenerationAction.img2img => 'NAI Img2Img $time',
      ImageGenerationAction.generate => 'NAI Image $time',
    };
  }

  Map<String, dynamic> _paramsMetadata(ImageParams params) {
    return {
      'prompt': params.prompt,
      'negative_prompt': params.negativePrompt,
      'model': params.model,
      'sampler': params.sampler,
      'steps': params.steps,
      'cfg_scale': params.scale,
      'seed': params.seed,
      'width': params.width,
      'height': params.height,
      'strength': params.strength,
      'noise': params.noise,
      'inpaint_strength': params.inpaintStrength,
    };
  }

  void _sendError(String id, KritaBridgeErrorCode code, String message) {
    _send(KritaBridgeError(id: id, code: code, message: message).toJson());
  }

  KritaBridgeErrorCode _mapErrorCode(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('401') ||
        message.contains('unauthorized') ||
        message.contains('token')) {
      return KritaBridgeErrorCode.authFailed;
    }
    if (message.contains('402') ||
        message.contains('anlas') ||
        message.contains('insufficient')) {
      return KritaBridgeErrorCode.insufficientAnlas;
    }
    if (message.contains('429') || message.contains('rate')) {
      return KritaBridgeErrorCode.rateLimited;
    }
    if (message.contains('timeout')) {
      return KritaBridgeErrorCode.timeout;
    }
    if (message.contains('mask') && message.contains('empty')) {
      return KritaBridgeErrorCode.emptyMask;
    }
    if (_isStreamingUnsupported(message)) {
      return KritaBridgeErrorCode.streamingUnsupported;
    }
    return KritaBridgeErrorCode.serverError;
  }

  String _publicErrorMessage(KritaBridgeErrorCode code) {
    return switch (code) {
      KritaBridgeErrorCode.authFailed =>
        'Authentication failed, please re-login in Launcher.',
      KritaBridgeErrorCode.insufficientAnlas =>
        'Insufficient Anlas to complete this request.',
      KritaBridgeErrorCode.rateLimited =>
        'Request was rate limited. Please retry later.',
      KritaBridgeErrorCode.timeout => 'Generation request timed out.',
      KritaBridgeErrorCode.emptyMask => 'Inpaint mask is empty.',
      KritaBridgeErrorCode.streamingUnsupported =>
        'Streaming is not available for this request.',
      KritaBridgeErrorCode.serverError => 'NovelAI server error.',
      _ => 'Krita bridge request failed.',
    };
  }

  bool _isStreamingUnsupported(String message) {
    final lower = message.toLowerCase();
    return lower.contains('streaming is not allowed') ||
        lower.contains('streaming not allowed') ||
        lower.contains('stream is not allowed') ||
        lower.contains('stream not allowed');
  }

  bool _shouldUseDirectFallback(KritaBridgeGenerateRequest request) {
    return request.params.action == ImageGenerationAction.infill;
  }

  Rect? _toRect(KritaSelectionRect? rect) {
    if (rect == null) {
      return null;
    }
    return Rect.fromLTWH(
      rect.x.toDouble(),
      rect.y.toDouble(),
      rect.width.toDouble(),
      rect.height.toDouble(),
    );
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
