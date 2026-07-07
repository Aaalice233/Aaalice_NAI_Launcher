import 'dart:typed_data';

import '../constants/api_constants.dart';
import '../../data/models/image/image_params.dart';

enum KritaBridgeErrorCode {
  invalidRequest('invalid_request'),
  unsupportedMessage('unsupported_message'),
  payloadTooLarge('payload_too_large'),
  authFailed('auth_failed'),
  unauthorizedBridgeClient('unauthorized_bridge_client'),
  busy('busy'),
  emptyMask('empty_mask'),
  timeout('timeout'),
  rateLimited('rate_limited'),
  insufficientAnlas('insufficient_anlas'),
  serverError('server_error'),
  streamInterrupted('stream_interrupted'),
  streamingUnsupported('streaming_unsupported'),
  unsupportedDocumentFormat('unsupported_document_format');

  const KritaBridgeErrorCode(this.value);

  final String value;
}

class KritaBridgeError {
  const KritaBridgeError({
    required this.code,
    required this.message,
    this.id,
  });

  final KritaBridgeErrorCode code;
  final String message;
  final String? id;

  Map<String, dynamic> toJson() => {
        'type': 'error',
        if (id != null) 'id': id,
        'code': code.value,
        'message': message,
      };
}

class KritaBridgeDecodeResult {
  const KritaBridgeDecodeResult._({
    this.message,
    this.error,
  });

  factory KritaBridgeDecodeResult.message(KritaBridgeMessage message) {
    return KritaBridgeDecodeResult._(message: message);
  }

  factory KritaBridgeDecodeResult.error(KritaBridgeError error) {
    return KritaBridgeDecodeResult._(error: error);
  }

  final KritaBridgeMessage? message;
  final KritaBridgeError? error;
}

abstract class KritaBridgeMessage {
  const KritaBridgeMessage();

  String get type;
  String? get id;
}

class KritaPingMessage extends KritaBridgeMessage {
  const KritaPingMessage({
    required this.version,
    required this.secret,
  });

  @override
  String get type => 'ping';

  @override
  String? get id => null;

  final int version;
  final String secret;
}

class KritaUnsupportedPingVersionMessage extends KritaBridgeMessage {
  const KritaUnsupportedPingVersionMessage({
    required this.requestedVersion,
    required this.supportedVersions,
  });

  @override
  String get type => 'ping_version_mismatch';

  @override
  String? get id => null;

  final int requestedVersion;
  final List<int> supportedVersions;
}

class KritaGetParamsMessage extends KritaBridgeMessage {
  const KritaGetParamsMessage({
    required this.id,
  });

  @override
  String get type => 'get_params';

  @override
  final String id;
}

class KritaCancelMessage extends KritaBridgeMessage {
  const KritaCancelMessage({
    required this.id,
  });

  @override
  String get type => 'cancel';

  @override
  final String id;
}

class KritaSelectionRect {
  const KritaSelectionRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;
}

class KritaImageParamsMapping {
  const KritaImageParamsMapping({
    required this.params,
    required this.focusedInpaintEnabled,
    required this.minimumContextPixels,
    this.selectionRect,
  });

  final ImageParams params;
  final bool focusedInpaintEnabled;
  final int minimumContextPixels;
  final KritaSelectionRect? selectionRect;
}

class KritaInpaintMessage extends KritaBridgeMessage {
  const KritaInpaintMessage({
    required this.id,
    required this.image,
    required this.mask,
    required this.prompt,
    required this.negativePrompt,
    required this.strength,
    required this.noise,
    required this.inpaintStrength,
    required this.minimumContextPixels,
    required this.maskClosingIterations,
    required this.maskExpansionIterations,
    required this.focusedInpaint,
    this.selectionRect,
  });

  @override
  String get type => 'inpaint';

  @override
  final String id;
  final Uint8List image;
  final Uint8List mask;
  final KritaSelectionRect? selectionRect;
  final String prompt;
  final String negativePrompt;
  final double strength;
  final double noise;
  final double inpaintStrength;
  final int minimumContextPixels;
  final int maskClosingIterations;
  final int maskExpansionIterations;
  final bool focusedInpaint;

  KritaImageParamsMapping toImageParams(ImageParams baseParams) {
    final clampedContext = minimumContextPixels.clamp(16, 192).toInt();
    final hasFocusedRect = focusedInpaint && selectionRect != null;

    return KritaImageParamsMapping(
      params: baseParams.copyWith(
        action: ImageGenerationAction.infill,
        model: _resolveInpaintModel(baseParams.model),
        sourceImage: image,
        maskImage: mask,
        prompt: prompt,
        negativePrompt: negativePrompt,
        strength: strength,
        noise: noise,
        inpaintStrength: inpaintStrength,
        inpaintMaskClosingIterations: maskClosingIterations,
        inpaintMaskExpansionIterations: maskExpansionIterations,
      ),
      focusedInpaintEnabled: hasFocusedRect,
      minimumContextPixels: clampedContext,
      selectionRect: selectionRect,
    );
  }

  String _resolveInpaintModel(String model) {
    if (ImageModels.isInpaintingModel(model)) {
      return model;
    }

    switch (model) {
      case ImageModels.animeDiffusionV45Full:
        return ImageModels.animeDiffusionV45FullInpainting;
      case ImageModels.animeDiffusionV45Curated:
        return ImageModels.animeDiffusionV45CuratedInpainting;
      case ImageModels.animeDiffusionV4Full:
        return ImageModels.animeDiffusionV4FullInpainting;
      case ImageModels.animeDiffusionV4Curated:
        return ImageModels.animeDiffusionV4CuratedInpainting;
      case ImageModels.furryDiffusion:
      case ImageModels.furryDiffusionV3:
        return ImageModels.furryDiffusionV3Inpainting;
      case ImageModels.animeDiffusionV3:
      default:
        return ImageModels.animeDiffusionV3Inpainting;
    }
  }
}

class KritaImg2ImgMessage extends KritaBridgeMessage {
  const KritaImg2ImgMessage({
    required this.id,
    required this.image,
    required this.prompt,
    required this.negativePrompt,
    required this.strength,
    required this.noise,
  });

  @override
  String get type => 'img2img';

  @override
  final String id;
  final Uint8List image;
  final String prompt;
  final String negativePrompt;
  final double strength;
  final double noise;

  KritaImageParamsMapping toImageParams(ImageParams baseParams) {
    return KritaImageParamsMapping(
      params: baseParams.copyWith(
        action: ImageGenerationAction.img2img,
        sourceImage: image,
        prompt: prompt,
        negativePrompt: negativePrompt,
        strength: strength,
        noise: noise,
      ),
      focusedInpaintEnabled: false,
      minimumContextPixels: 0,
    );
  }
}
