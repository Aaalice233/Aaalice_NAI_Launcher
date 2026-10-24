import 'dart:convert';
import 'dart:typed_data';

import '../utils/constant_time_equals.dart';
import 'krita_bridge_models.dart';

class KritaBridgeProtocol {
  KritaBridgeProtocol._();

  static const int version = 1;
  static const int defaultMaxTextFrameBytes = 64 * 1024 * 1024;
  static const int defaultMaxDecodedImageBytes = 48 * 1024 * 1024;
  static const int minV1CanvasEdge = 64;
  static const int maxV1CanvasEdge = 4096;

  static KritaBridgeDecodeResult decodeIncoming(
    String text, {
    required String? sessionSecret,
    required bool authenticated,
    int maxTextFrameBytes = defaultMaxTextFrameBytes,
    int maxDecodedImageBytes = defaultMaxDecodedImageBytes,
  }) {
    if (utf8.encode(text).length > maxTextFrameBytes) {
      return KritaBridgeDecodeResult.error(
        const KritaBridgeError(
          code: KritaBridgeErrorCode.payloadTooLarge,
          message: 'Payload is too large',
        ),
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return KritaBridgeDecodeResult.error(
        const KritaBridgeError(
          code: KritaBridgeErrorCode.invalidRequest,
          message: 'Message is not valid JSON',
        ),
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return KritaBridgeDecodeResult.error(
        const KritaBridgeError(
          code: KritaBridgeErrorCode.invalidRequest,
          message: 'Message must be a JSON object',
        ),
      );
    }

    final type = _optionalString(decoded, 'type');
    final id = _optionalString(decoded, 'id');
    if (type == null || type.isEmpty) {
      return KritaBridgeDecodeResult.error(
        KritaBridgeError(
          code: KritaBridgeErrorCode.invalidRequest,
          id: id,
          message: 'Missing message type',
        ),
      );
    }

    if (type == 'ping') {
      return _decodePing(decoded, sessionSecret: sessionSecret);
    }

    if (!authenticated) {
      return KritaBridgeDecodeResult.error(
        KritaBridgeError(
          code: KritaBridgeErrorCode.unauthorizedBridgeClient,
          id: id,
          message: 'Bridge client is not authenticated',
        ),
      );
    }

    final payload = _payload(decoded);
    switch (type) {
      case 'get_params':
        return _decodeGetParams(id);
      case 'cancel':
        return _decodeCancel(id);
      case 'inpaint':
        return _decodeInpaint(id, payload, maxDecodedImageBytes);
      case 'img2img':
        return _decodeImg2Img(id, payload, maxDecodedImageBytes);
      default:
        return KritaBridgeDecodeResult.error(
          KritaBridgeError(
            code: KritaBridgeErrorCode.unsupportedMessage,
            id: id,
            message: 'Unsupported message type: $type',
          ),
        );
    }
  }

  static Map<String, dynamic> encodePong({
    List<int> supportedVersions = const [],
  }) =>
      {
        'type': 'pong',
        'version': version,
        if (supportedVersions.isNotEmpty)
          'supported_versions': supportedVersions,
      };

  static Map<String, dynamic> encodeError(KritaBridgeError error) {
    return error.toJson();
  }

  static KritaBridgeDecodeResult _decodePing(
    Map<String, dynamic> data, {
    required String? sessionSecret,
  }) {
    final requestVersion = _optionalInt(data, 'version') ?? 0;
    final secret = _optionalString(data, 'secret');
    if (secret == null || !secretsMatch(sessionSecret, secret)) {
      return KritaBridgeDecodeResult.error(
        const KritaBridgeError(
          code: KritaBridgeErrorCode.authFailed,
          message: 'Bridge authentication failed',
        ),
      );
    }

    if (requestVersion != version) {
      return KritaBridgeDecodeResult.message(
        KritaUnsupportedPingVersionMessage(
          requestedVersion: requestVersion,
          supportedVersions: const [version],
        ),
      );
    }

    return KritaBridgeDecodeResult.message(
      KritaPingMessage(version: requestVersion, secret: secret),
    );
  }

  static KritaBridgeDecodeResult _decodeGetParams(String? id) {
    if (id == null || id.isEmpty) {
      return _invalid(id, 'Missing request id');
    }

    return KritaBridgeDecodeResult.message(KritaGetParamsMessage(id: id));
  }

  static KritaBridgeDecodeResult _decodeCancel(String? id) {
    if (id == null || id.isEmpty) {
      return _invalid(id, 'Missing request id');
    }

    return KritaBridgeDecodeResult.message(KritaCancelMessage(id: id));
  }

  static KritaBridgeDecodeResult _decodeInpaint(
    String? id,
    Map<String, dynamic> payload,
    int maxDecodedImageBytes,
  ) {
    if (id == null || id.isEmpty) {
      return _invalid(id, 'Missing request id');
    }

    try {
      _rejectUnsupportedScaleMetadata(payload);
      final image = _requiredBase64(
        payload,
        'image',
        maxDecodedImageBytes,
      );
      final imageDimensions = _requiredPngDimensions(image, 'image');
      final mask = _requiredBase64(
        payload,
        'mask',
        maxDecodedImageBytes,
      );
      final maskDimensions = _requiredPngDimensions(mask, 'mask');
      if (imageDimensions != maskDimensions) {
        throw const _ProtocolException(
          'image and mask PNG dimensions must match',
        );
      }
      final focusedInpaint = _optionalBool(payload, 'focused_inpaint') ?? false;
      final selectionRect = _selectionRect(payload['selection_rect']);
      if (focusedInpaint && selectionRect == null) {
        throw const _ProtocolException(
          'focused_inpaint requires selection_rect',
        );
      }
      if (selectionRect != null &&
          !_rectFitsWithin(selectionRect, imageDimensions)) {
        throw const _ProtocolException(
          'selection_rect must fit within image bounds',
        );
      }

      return KritaBridgeDecodeResult.message(
        KritaInpaintMessage(
          id: id,
          image: image,
          mask: mask,
          selectionRect: selectionRect,
          prompt: _optionalString(payload, 'prompt') ?? '',
          negativePrompt: _optionalString(payload, 'negative_prompt') ?? '',
          strength: _optionalDouble(payload, 'strength') ?? 0.7,
          noise: _optionalDouble(payload, 'noise') ?? 0.0,
          inpaintStrength: _optionalDouble(payload, 'inpaint_strength') ?? 1.0,
          minimumContextPixels:
              _optionalInt(payload, 'minimum_context_pixels') ?? 88,
          maskClosingIterations:
              _optionalInt(payload, 'mask_closing_iterations') ?? 0,
          maskExpansionIterations:
              _optionalInt(payload, 'mask_expansion_iterations') ?? 0,
          focusedInpaint: focusedInpaint,
        ),
      );
    } on _PayloadTooLargeException catch (error) {
      return _tooLarge(id, error.message);
    } on _ProtocolException catch (error) {
      return _invalid(id, error.message);
    }
  }

  static KritaBridgeDecodeResult _decodeImg2Img(
    String? id,
    Map<String, dynamic> payload,
    int maxDecodedImageBytes,
  ) {
    if (id == null || id.isEmpty) {
      return _invalid(id, 'Missing request id');
    }

    try {
      _rejectUnsupportedScaleMetadata(payload);
      return KritaBridgeDecodeResult.message(
        KritaImg2ImgMessage(
          id: id,
          image: _requiredPng(
            payload,
            'image',
            maxDecodedImageBytes,
          ),
          prompt: _optionalString(payload, 'prompt') ?? '',
          negativePrompt: _optionalString(payload, 'negative_prompt') ?? '',
          strength: _optionalDouble(payload, 'strength') ?? 0.5,
          noise: _optionalDouble(payload, 'noise') ?? 0.0,
        ),
      );
    } on _PayloadTooLargeException catch (error) {
      return _tooLarge(id, error.message);
    } on _ProtocolException catch (error) {
      return _invalid(id, error.message);
    }
  }

  static void _rejectUnsupportedScaleMetadata(Map<String, dynamic> data) {
    const scaledPayloadKeys = {
      'image_scale',
      'original_width',
      'original_height',
      'sent_width',
      'sent_height',
      'scale_x',
      'scale_y',
    };
    for (final key in scaledPayloadKeys) {
      if (data.containsKey(key)) {
        throw const _ProtocolException(
          'Scaled payload metadata is not supported in bridge V1',
        );
      }
    }
  }

  static Uint8List _requiredPng(
    Map<String, dynamic> data,
    String key,
    int maxDecodedImageBytes,
  ) {
    final bytes = _requiredBase64(data, key, maxDecodedImageBytes);
    _requiredPngDimensions(bytes, key);
    return bytes;
  }

  static Map<String, dynamic> _payload(Map<String, dynamic> data) {
    final payload = data['payload'];
    if (payload is Map<String, dynamic>) {
      return payload;
    }

    final inline = Map<String, dynamic>.from(data);
    inline.remove('type');
    inline.remove('id');
    inline.remove('version');
    inline.remove('payload');
    return inline;
  }

  static Uint8List _requiredBase64(
    Map<String, dynamic> data,
    String key,
    int maxDecodedImageBytes,
  ) {
    final value = _optionalString(data, key);
    if (value == null || value.isEmpty) {
      throw _ProtocolException('Missing required field: $key');
    }

    try {
      _checkEstimatedDecodedSize(value, key, maxDecodedImageBytes);
      final decoded = Uint8List.fromList(base64Decode(value));
      if (decoded.length > maxDecodedImageBytes) {
        throw _PayloadTooLargeException('Decoded image is too large: $key');
      }
      return decoded;
    } catch (error) {
      if (error is _PayloadTooLargeException) {
        rethrow;
      }
      throw _ProtocolException('Invalid base64 field: $key');
    }
  }

  static _PngDimensions _requiredPngDimensions(Uint8List bytes, String key) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 24) {
      throw _ProtocolException('$key must be a PNG image');
    }
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) {
        throw _ProtocolException('$key must be a PNG image');
      }
    }

    final data = ByteData.sublistView(bytes);
    final ihdrLength = data.getUint32(8);
    final hasIhdrType = bytes[12] == 0x49 &&
        bytes[13] == 0x48 &&
        bytes[14] == 0x44 &&
        bytes[15] == 0x52;
    if (ihdrLength != 13 || !hasIhdrType) {
      throw _ProtocolException('$key must start with a PNG IHDR chunk');
    }

    final width = data.getUint32(16);
    final height = data.getUint32(20);
    if (width <= 0 || height <= 0) {
      throw _ProtocolException('$key PNG dimensions must be positive');
    }
    if (width < minV1CanvasEdge ||
        height < minV1CanvasEdge ||
        width > maxV1CanvasEdge ||
        height > maxV1CanvasEdge) {
      throw _ProtocolException(
        '$key PNG dimensions must be between '
        '${minV1CanvasEdge}x$minV1CanvasEdge and '
        '${maxV1CanvasEdge}x$maxV1CanvasEdge',
      );
    }
    return _PngDimensions(width: width, height: height);
  }

  static void _checkEstimatedDecodedSize(
    String value,
    String key,
    int maxDecodedImageBytes,
  ) {
    final compact = value.replaceAll(RegExp(r'\s'), '');
    final padding = compact.endsWith('==')
        ? 2
        : compact.endsWith('=')
            ? 1
            : 0;
    final estimatedDecodedBytes = (compact.length * 3 ~/ 4) - padding;
    if (estimatedDecodedBytes > maxDecodedImageBytes) {
      throw _PayloadTooLargeException('Decoded image is too large: $key');
    }
  }

  static KritaSelectionRect? _selectionRect(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! Map<String, dynamic>) {
      throw const _ProtocolException('selection_rect must be an object');
    }

    final x = _requiredInt(value, 'x');
    final y = _requiredInt(value, 'y');
    final width = _requiredInt(value, 'w');
    final height = _requiredInt(value, 'h');
    if (x < 0 || y < 0 || width <= 0 || height <= 0) {
      throw const _ProtocolException(
        'selection_rect must use non-negative x/y and positive w/h',
      );
    }

    return KritaSelectionRect(x: x, y: y, width: width, height: height);
  }

  static bool _rectFitsWithin(
    KritaSelectionRect rect,
    _PngDimensions dimensions,
  ) {
    return rect.x + rect.width <= dimensions.width &&
        rect.y + rect.height <= dimensions.height;
  }

  static int _requiredInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! int) {
      throw _ProtocolException('Missing integer field: $key');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? value : null;
  }

  static bool? _optionalBool(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is bool ? value : null;
  }

  static int? _optionalInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite) {
      return value.toInt();
    }
    return null;
  }

  static double? _optionalDouble(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    return null;
  }

  static KritaBridgeDecodeResult _invalid(String? id, String message) {
    return KritaBridgeDecodeResult.error(
      KritaBridgeError(
        code: KritaBridgeErrorCode.invalidRequest,
        id: id,
        message: message,
      ),
    );
  }

  static KritaBridgeDecodeResult _tooLarge(String? id, String message) {
    return KritaBridgeDecodeResult.error(
      KritaBridgeError(
        code: KritaBridgeErrorCode.payloadTooLarge,
        id: id,
        message: message,
      ),
    );
  }
}

class _ProtocolException implements Exception {
  const _ProtocolException(this.message);

  final String message;
}

class _PayloadTooLargeException implements Exception {
  const _PayloadTooLargeException(this.message);

  final String message;
}

class _PngDimensions {
  const _PngDimensions({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;

  @override
  bool operator ==(Object other) {
    return other is _PngDimensions &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);
}
