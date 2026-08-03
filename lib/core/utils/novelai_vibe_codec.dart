import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../data/models/vibe/vibe_reference.dart';
import '../constants/api_constants.dart';

/// Serializes Vibes using the format consumed by NovelAI's web importer.
class NovelAiVibeCodec {
  NovelAiVibeCodec._();

  static const String singleIdentifier = 'novelai-vibe-transfer';
  static const String bundleIdentifier = 'novelai-vibe-transfer-bundle';
  static const int version = 1;
  static const String defaultModel = ImageModels.animeDiffusionV4Full;

  static Map<String, dynamic> buildSingleMap(
    VibeReference vibe, {
    String? name,
    String fallbackModel = defaultModel,
    bool includeThumbnail = true,
    bool includeEncoding = true,
    DateTime? createdAt,
  }) {
    final encoding = includeEncoding ? vibe.vibeEncoding.trim() : '';
    final rawImage = _nonEmptyBytes(vibe.rawImageData);
    final thumbnail = _nonEmptyBytes(vibe.thumbnail);
    final imageBytes = rawImage ?? (encoding.isEmpty ? thumbnail : null);
    final isImageType = imageBytes != null;

    if (!isImageType && encoding.isEmpty) {
      throw StateError('Vibe has no image or encoding data');
    }

    final model = normalizeModel(vibe.encodingModel ?? fallbackModel);
    final modelKey = encodingKeyForModel(model);
    final params = <String, dynamic>{
      'information_extracted': VibeReference.sanitizeInfoExtracted(
        vibe.infoExtracted,
      ),
    };

    final encodings = <String, dynamic>{};
    if (encoding.isNotEmpty) {
      final variantKey = isImageType ? encodingParamsKey(params) : 'unknown';
      encodings[modelKey] = <String, dynamic>{
        variantKey: <String, dynamic>{'encoding': encoding, 'params': params},
      };
    }

    final String type;
    final String id;
    final String? image;
    if (isImageType) {
      type = 'image';
      image = base64Encode(imageBytes);
      id = hashString(image);
    } else {
      type = 'encoding';
      image = null;
      id = hashString(encoding);
    }

    return <String, dynamic>{
      'identifier': singleIdentifier,
      'version': version,
      'type': type,
      if (image != null) 'image': image,
      'id': id,
      'encodings': encodings,
      'name': name ?? vibe.displayName,
      if (includeThumbnail && thumbnail != null)
        'thumbnail': imageDataUri(thumbnail),
      'createdAt': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
      'importInfo': <String, dynamic>{
        'model': model,
        'information_extracted': VibeReference.sanitizeInfoExtracted(
          vibe.infoExtracted,
        ),
        'strength': VibeReference.sanitizeStrength(vibe.strength),
      },
    };
  }

  static Map<String, dynamic> buildBundleMap(
    Iterable<VibeReference> vibes, {
    String fallbackModel = defaultModel,
    bool includeThumbnails = true,
    bool includeEncoding = true,
  }) {
    final entries = <Map<String, dynamic>>[];
    for (final vibe in vibes) {
      entries.add(
        buildSingleMap(
          vibe,
          fallbackModel: fallbackModel,
          includeThumbnail: includeThumbnails,
          includeEncoding: includeEncoding,
        ),
      );
    }
    if (entries.isEmpty) {
      throw ArgumentError.value(vibes, 'vibes', 'must not be empty');
    }

    return <String, dynamic>{
      'identifier': bundleIdentifier,
      'version': version,
      'vibes': entries,
    };
  }

  static String encodeJson(Map<String, dynamic> value) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  static bool validateSingleMap(Map<String, dynamic> value) {
    if (value['identifier'] != singleIdentifier ||
        value['version'] != version) {
      return false;
    }

    final id = value['id'];
    if (id is! String || !RegExp(r'^[\da-f]{64}$').hasMatch(id)) {
      return false;
    }

    final type = value['type'];
    if (type == 'image') {
      final image = value['image'];
      if (image is! String || image.isEmpty || hashString(image) != id) {
        return false;
      }
    } else if (type == 'encoding') {
      final encoding = firstEncoding(value['encodings']);
      if (encoding == null || hashString(encoding) != id) {
        return false;
      }
    } else {
      return false;
    }

    final thumbnail = value['thumbnail'];
    if (thumbnail != null &&
        (thumbnail is! String ||
            !RegExp(r'^data:image/[^;]+;base64,').hasMatch(thumbnail))) {
      return false;
    }

    final importInfo = value['importInfo'];
    if (importInfo is! Map ||
        importInfo['model'] is! String ||
        importInfo['information_extracted'] is! num ||
        importInfo['strength'] is! num) {
      return false;
    }

    return true;
  }

  static bool validateBundleMap(Map<String, dynamic> value) {
    if (value['identifier'] != bundleIdentifier ||
        value['version'] != version) {
      return false;
    }
    final vibes = value['vibes'];
    if (vibes is! List || vibes.isEmpty) {
      return false;
    }
    return vibes.every(
      (entry) =>
          entry is Map && validateSingleMap(Map<String, dynamic>.from(entry)),
    );
  }

  static String? firstEncoding(Object? encodingsValue) {
    if (encodingsValue is! Map) {
      return null;
    }
    for (final modelValue in encodingsValue.values) {
      if (modelValue is! Map) {
        continue;
      }
      for (final variantValue in modelValue.values) {
        if (variantValue is Map) {
          final encoding = variantValue['encoding'];
          if (encoding is String && encoding.isNotEmpty) {
            return encoding;
          }
        }
      }
    }
    return null;
  }

  static String normalizeModel(String model) {
    return normalizeModelOrNull(model) ?? defaultModel;
  }

  static String? normalizeModelOrNull(String? model) {
    return switch (model?.trim()) {
      ImageModels.animeDiffusionV4Curated ||
      ImageModels.animeDiffusionV4CuratedInpainting =>
        ImageModels.animeDiffusionV4Curated,
      ImageModels.animeDiffusionV4Full ||
      ImageModels.animeDiffusionV4FullInpainting =>
        ImageModels.animeDiffusionV4Full,
      ImageModels.animeDiffusionV45Curated ||
      ImageModels.animeDiffusionV45CuratedInpainting =>
        ImageModels.animeDiffusionV45Curated,
      ImageModels.animeDiffusionV45Full ||
      ImageModels.animeDiffusionV45FullInpainting =>
        ImageModels.animeDiffusionV45Full,
      _ => null,
    };
  }

  static String encodingKeyForModel(String model) {
    return switch (normalizeModel(model)) {
      ImageModels.animeDiffusionV4Curated => 'v4curated',
      ImageModels.animeDiffusionV4Full => 'v4full',
      ImageModels.animeDiffusionV45Curated => 'v4-5curated',
      ImageModels.animeDiffusionV45Full => 'v4-5full',
      _ => 'v4full',
    };
  }

  static String? modelForEncodingKey(String key) {
    return switch (key) {
      'v4curated' => ImageModels.animeDiffusionV4Curated,
      'v4full' => ImageModels.animeDiffusionV4Full,
      'v4-5curated' => ImageModels.animeDiffusionV45Curated,
      'v4-5full' => ImageModels.animeDiffusionV45Full,
      _ => null,
    };
  }

  static String encodingParamsKey(Map<String, dynamic> params) {
    final entries =
        params.entries
            .where((entry) => entry.value != null)
            .toList(growable: false)
          ..sort((left, right) => left.key.compareTo(right.key));
    final canonical = entries
        .map((entry) {
          final value = entry.value;
          final encoded = value is Map || value is List
              ? jsonEncode(value)
              : _javascriptPrimitiveString(value);
          return '${entry.key}:$encoded';
        })
        .join(',');
    return hashString(canonical);
  }

  static String hashString(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  static String imageDataUri(Uint8List bytes) {
    return 'data:${_imageMimeType(bytes)};base64,${base64Encode(bytes)}';
  }

  static Uint8List? _nonEmptyBytes(Uint8List? bytes) {
    return bytes == null || bytes.isEmpty ? null : bytes;
  }

  static String _javascriptPrimitiveString(Object? value) {
    if (value is double && value.isFinite && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return '$value';
  }

  static String _imageMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    if (bytes.length >= 6) {
      final signature = ascii.decode(bytes.sublist(0, 6), allowInvalid: true);
      if (signature == 'GIF87a' || signature == 'GIF89a') {
        return 'image/gif';
      }
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4d) {
      return 'image/bmp';
    }
    return 'image/png';
  }
}
