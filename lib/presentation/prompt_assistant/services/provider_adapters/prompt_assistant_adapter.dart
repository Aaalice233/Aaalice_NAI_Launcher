import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

import '../../models/agent_protocol.dart';
import '../../models/prompt_assistant_models.dart';

const int promptAssistantImageUploadMaxBytes = 5 * 1024 * 1024;
const String promptAssistantCompressedImageMimeType = 'image/jpeg';

class PromptAssistantRequest {
  const PromptAssistantRequest({
    required this.sessionId,
    required this.provider,
    required this.model,
    required this.systemPrompt,
    required this.userParts,
    required this.apiKey,
    this.responseTimeout = const Duration(
      seconds: PromptAssistantConfigState.defaultResponseTimeoutSeconds,
    ),
    this.responseFormat = PromptAssistantResponseFormat.text,
    this.maxOutputTokens,
    this.reasoningMode = PromptAssistantReasoningMode.automatic,
  });

  final Duration responseTimeout;
  final String sessionId;
  final ProviderConfig provider;
  final String model;
  final String systemPrompt;
  final List<PromptAssistantContentPart> userParts;
  final String? apiKey;
  final PromptAssistantResponseFormat responseFormat;
  final int? maxOutputTokens;
  final PromptAssistantReasoningMode reasoningMode;
}

enum PromptAssistantResponseFormat { text, jsonObject }

enum PromptAssistantReasoningMode { automatic, disabled }

abstract class PromptAssistantContentPart {
  const PromptAssistantContentPart();

  factory PromptAssistantContentPart.text(String text) =
      PromptAssistantTextPart;

  factory PromptAssistantContentPart.image({
    required Uint8List bytes,
    required String mimeType,
  }) = PromptAssistantImagePart;
}

class PromptAssistantTextPart extends PromptAssistantContentPart {
  const PromptAssistantTextPart(this.text);

  final String text;
}

class PromptAssistantImagePart extends PromptAssistantContentPart {
  const PromptAssistantImagePart({
    required this.bytes,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String mimeType;
}

class PromptAssistantImageInput {
  const PromptAssistantImageInput({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

abstract class PromptAssistantProviderAdapter {
  const PromptAssistantProviderAdapter();

  Future<List<String>> fetchModels({
    required Dio dio,
    required ProviderConfig provider,
    required String? apiKey,
  });

  Future<String> complete({
    required Dio dio,
    required PromptAssistantRequest request,
    required CancelToken cancelToken,
  });

  /// Agent 模式：多轮消息 + 工具调用，流式输出 [AgentWireEvent]。
  ///
  /// 默认抛出 [UnsupportedError]，由支持工具调用的协议各自覆写。
  Stream<AgentWireEvent> completeAgent({
    required Dio dio,
    required AgentChatRequest request,
    required CancelToken cancelToken,
  }) async* {
    throw UnsupportedError(
      'Provider protocol ${request.provider.protocol.label} does not support '
      'agent tool calling',
    );
  }
}

String normalizedBaseUrl(String baseUrl) {
  return baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
}

String imageDataUri(PromptAssistantImagePart part) {
  return 'data:${part.mimeType};base64,${base64Encode(part.bytes)}';
}

Future<PromptAssistantRequest> optimizePromptAssistantRequestImagesForUpload(
  PromptAssistantRequest request, {
  int maxBytes = promptAssistantImageUploadMaxBytes,
  bool normalizeToJpeg = true,
}) async {
  var changed = false;
  final parts = <PromptAssistantContentPart>[];

  for (final part in request.userParts) {
    if (part is PromptAssistantImagePart) {
      final optimized = await optimizePromptAssistantImagePartForUpload(
        part,
        maxBytes: maxBytes,
        normalizeToJpeg: normalizeToJpeg,
      );
      changed = changed || !identical(optimized, part);
      parts.add(optimized);
    } else {
      parts.add(part);
    }
  }

  if (!changed) return request;
  return PromptAssistantRequest(
    sessionId: request.sessionId,
    provider: request.provider,
    model: request.model,
    systemPrompt: request.systemPrompt,
    userParts: parts,
    apiKey: request.apiKey,
    responseTimeout: request.responseTimeout,
    responseFormat: request.responseFormat,
    maxOutputTokens: request.maxOutputTokens,
    reasoningMode: request.reasoningMode,
  );
}

Future<PromptAssistantImagePart> optimizePromptAssistantImagePartForUpload(
  PromptAssistantImagePart part, {
  int maxBytes = promptAssistantImageUploadMaxBytes,
  bool normalizeToJpeg = false,
}) async {
  final shouldNormalizeMime =
      normalizeToJpeg && part.mimeType.toLowerCase() != 'image/jpeg';
  final shouldOptimizeSize = maxBytes > 0 && part.bytes.length > maxBytes;

  if (!shouldNormalizeMime && !shouldOptimizeSize) {
    return part;
  }

  try {
    final result = await Isolate.run(
      () => _optimizePromptAssistantImageBytes(
        _PromptAssistantImageOptimizationJob(
          bytes: part.bytes,
          maxBytes: maxBytes,
        ),
      ),
    );
    if (result == null || result.bytes.length >= part.bytes.length) {
      if (!shouldNormalizeMime) {
        return part;
      }
    }
    if (result == null) {
      return part;
    }
    return PromptAssistantImagePart(
      bytes: result.bytes,
      mimeType: result.mimeType,
    );
  } catch (_) {
    return part;
  }
}

String contentToText(dynamic content) {
  if (content is String) {
    return content;
  }
  if (content is List) {
    return content.map(contentToText).where((e) => e.isNotEmpty).join();
  }
  if (content is Map) {
    return contentToText(
      content['text'] ??
          content['content'] ??
          content['value'] ??
          content['output_text'],
    );
  }
  return '';
}

String? extractErrorMessage(Map<String, dynamic> obj) {
  final error = obj['error'];
  if (error is String && error.trim().isNotEmpty) {
    return error.trim();
  }
  if (error is Map<String, dynamic>) {
    final message = error['message'] ?? error['error'] ?? error['type'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }
  return null;
}

List<String> extractModelNames(dynamic raw) {
  final names = <String>[];

  void addName(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      final trimmed = value.trim();
      names.add(
        trimmed.startsWith('models/')
            ? trimmed.substring('models/'.length)
            : trimmed,
      );
    }
  }

  if (raw is Map<String, dynamic>) {
    final data = raw['data'];
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          addName(item['id'] ?? item['name'] ?? item['model']);
        } else {
          addName(item);
        }
      }
    }
    final models = raw['models'];
    if (models is List) {
      for (final item in models) {
        if (item is Map<String, dynamic>) {
          final methods = item['supportedGenerationMethods'];
          if (methods is List &&
              methods.isNotEmpty &&
              !methods.contains('generateContent')) {
            continue;
          }
          addName(item['name'] ?? item['model'] ?? item['id']);
        } else {
          addName(item);
        }
      }
    }
  } else if (raw is List) {
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        addName(item['id'] ?? item['name'] ?? item['model']);
      } else {
        addName(item);
      }
    }
  }

  final dedup = <String>{};
  return names.where((name) => dedup.add(name)).toList();
}

String? detectImageMime(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return 'image/gif';
  }
  return null;
}

({Uint8List bytes, String mimeType})? parseDataUriImage(String value) {
  final match = RegExp(r'^data:([^;]+);base64,(.+)$').firstMatch(value);
  if (match == null) return null;
  return (
    bytes: base64Decode(match.group(2)!),
    mimeType: match.group(1)!,
  );
}

_OptimizedPromptAssistantImage? _optimizePromptAssistantImageBytes(
  _PromptAssistantImageOptimizationJob job,
) {
  final source = img.decodeImage(job.bytes);
  if (source == null || source.width <= 0 || source.height <= 0) {
    return null;
  }

  final oversized = job.maxBytes > 0 && job.bytes.length > job.maxBytes;
  final initialScale = oversized
      ? math.min(
          0.95,
          math.sqrt(job.maxBytes / job.bytes.length) * 0.98,
        )
      : 1.0;
  var targetWidth = _scaledImageDimension(source.width, initialScale);
  var targetHeight = _scaledImageDimension(source.height, initialScale);
  _OptimizedPromptAssistantImage? best;

  for (var attempt = 0; attempt < 12; attempt++) {
    final resized = targetWidth == source.width && targetHeight == source.height
        ? _flattenToRgb(source)
        : _resizeLanczos3(source, targetWidth, targetHeight);

    for (final quality in _jpegQualitySteps) {
      final bytes = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality),
      );
      final candidate = _OptimizedPromptAssistantImage(
        bytes: bytes,
        mimeType: promptAssistantCompressedImageMimeType,
      );
      if (best == null || candidate.bytes.length < best.bytes.length) {
        best = candidate;
      }
      if (job.maxBytes <= 0 || bytes.length <= job.maxBytes) {
        return candidate;
      }
    }

    if (targetWidth <= _minimumCompressedSide ||
        targetHeight <= _minimumCompressedSide) {
      break;
    }
    targetWidth = math.max(
      _minimumCompressedSide,
      (targetWidth * _retryResizeScale).round(),
    );
    targetHeight = math.max(
      _minimumCompressedSide,
      (targetHeight * _retryResizeScale).round(),
    );
  }

  return best;
}

int _scaledImageDimension(int sourceDimension, double scale) {
  final scaled = (sourceDimension * scale).round();
  return math.max(
    math.min(sourceDimension, _minimumCompressedSide),
    math.min(sourceDimension, scaled),
  );
}

img.Image _flattenToRgb(img.Image source) {
  final output = img.Image(width: source.width, height: source.height);
  final channelMax = math.max(source.maxChannelValue.toDouble(), 1.0);
  final channelScale = 255.0 / channelMax;

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      final alpha = source.hasAlpha
          ? (pixel.a.toDouble() / channelMax).clamp(0.0, 1.0)
          : 1.0;
      output.setPixelRgb(
        x,
        y,
        _clampByte(
          pixel.r.toDouble() * channelScale * alpha + 255.0 * (1.0 - alpha),
        ),
        _clampByte(
          pixel.g.toDouble() * channelScale * alpha + 255.0 * (1.0 - alpha),
        ),
        _clampByte(
          pixel.b.toDouble() * channelScale * alpha + 255.0 * (1.0 - alpha),
        ),
      );
    }
  }

  return output;
}

img.Image _resizeLanczos3(
  img.Image source,
  int targetWidth,
  int targetHeight,
) {
  final xContributors = _buildLanczosContributors(
    sourceSize: source.width,
    targetSize: targetWidth,
  );
  final yContributors = _buildLanczosContributors(
    sourceSize: source.height,
    targetSize: targetHeight,
  );
  final channelMax = math.max(source.maxChannelValue.toDouble(), 1.0);
  final channelScale = 255.0 / channelMax;
  final horizontal = Float32List(source.height * targetWidth * 3);

  for (var sourceY = 0; sourceY < source.height; sourceY++) {
    for (var targetX = 0; targetX < targetWidth; targetX++) {
      final columnContributors = xContributors[targetX];
      var red = 0.0;
      var green = 0.0;
      var blue = 0.0;

      for (final column in columnContributors) {
        final pixel = source.getPixel(column.index, sourceY);
        final alpha = source.hasAlpha
            ? (pixel.a.toDouble() / channelMax).clamp(0.0, 1.0)
            : 1.0;
        red += (pixel.r.toDouble() * channelScale * alpha +
                255.0 * (1.0 - alpha)) *
            column.weight;
        green += (pixel.g.toDouble() * channelScale * alpha +
                255.0 * (1.0 - alpha)) *
            column.weight;
        blue += (pixel.b.toDouble() * channelScale * alpha +
                255.0 * (1.0 - alpha)) *
            column.weight;
      }

      final offset = (sourceY * targetWidth + targetX) * 3;
      horizontal[offset] = red;
      horizontal[offset + 1] = green;
      horizontal[offset + 2] = blue;
    }
  }

  final output = img.Image(width: targetWidth, height: targetHeight);
  for (var targetY = 0; targetY < targetHeight; targetY++) {
    final rowContributors = yContributors[targetY];
    for (var targetX = 0; targetX < targetWidth; targetX++) {
      var red = 0.0;
      var green = 0.0;
      var blue = 0.0;

      for (final row in rowContributors) {
        final offset = (row.index * targetWidth + targetX) * 3;
        red += horizontal[offset] * row.weight;
        green += horizontal[offset + 1] * row.weight;
        blue += horizontal[offset + 2] * row.weight;
      }

      output.setPixelRgb(
        targetX,
        targetY,
        _clampByte(red),
        _clampByte(green),
        _clampByte(blue),
      );
    }
  }

  return output;
}

List<List<_LanczosContributor>> _buildLanczosContributors({
  required int sourceSize,
  required int targetSize,
}) {
  final scale = targetSize / sourceSize;
  final filterScale = scale < 1.0 ? 1.0 / scale : 1.0;
  final radius = _lanczosRadius * filterScale;
  return List<List<_LanczosContributor>>.generate(targetSize, (targetIndex) {
    final center = (targetIndex + 0.5) / scale - 0.5;
    final left = (center - radius).ceil();
    final right = (center + radius).floor();
    final contributors = <_LanczosContributor>[];
    var totalWeight = 0.0;

    for (var sourceIndex = left; sourceIndex <= right; sourceIndex++) {
      final weight = _lanczos((sourceIndex - center) / filterScale);
      if (weight.abs() < _minimumLanczosWeight) {
        continue;
      }
      contributors.add(
        _LanczosContributor(
          sourceIndex.clamp(0, sourceSize - 1),
          weight,
        ),
      );
      totalWeight += weight;
    }

    if (contributors.isEmpty || totalWeight.abs() < _minimumLanczosWeight) {
      return [
        _LanczosContributor(
          center.round().clamp(0, sourceSize - 1),
          1.0,
        ),
      ];
    }

    return [
      for (final contributor in contributors)
        _LanczosContributor(
          contributor.index,
          contributor.weight / totalWeight,
        ),
    ];
  });
}

double _lanczos(double value) {
  final x = value.abs();
  if (x < _minimumLanczosWeight) {
    return 1.0;
  }
  if (x >= _lanczosRadius) {
    return 0.0;
  }
  return _sinc(x) * _sinc(x / _lanczosRadius);
}

double _sinc(double value) {
  final x = math.pi * value;
  return math.sin(x) / x;
}

int _clampByte(double value) => value.round().clamp(0, 255);

const double _lanczosRadius = 3.0;
const double _minimumLanczosWeight = 1e-7;
const double _retryResizeScale = 0.84;
const int _minimumCompressedSide = 64;
const List<int> _jpegQualitySteps = [92, 88, 84, 80, 76, 72, 68, 64];

class _PromptAssistantImageOptimizationJob {
  const _PromptAssistantImageOptimizationJob({
    required this.bytes,
    required this.maxBytes,
  });

  final Uint8List bytes;
  final int maxBytes;
}

class _OptimizedPromptAssistantImage {
  const _OptimizedPromptAssistantImage({
    required this.bytes,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String mimeType;
}

class _LanczosContributor {
  const _LanczosContributor(this.index, this.weight);

  final int index;
  final double weight;
}
