import 'dart:convert';

import '../../core/utils/novelai_vibe_codec.dart';
import '../models/vibe/vibe_reference.dart';

/// Encodes Vibe documents and performs lossless compatible document merges.
class VibeFileDocumentCodec {
  String buildSingleJson(
    VibeReference vibe, {
    required String displayName,
    required String defaultModel,
  }) {
    return NovelAiVibeCodec.encodeJson(
      NovelAiVibeCodec.buildSingleMap(
        vibe.normalizedForLibraryStorage(),
        name: displayName,
        fallbackModel: defaultModel,
      ),
    );
  }

  String buildBundleJson(
    List<VibeReference> vibes, {
    String defaultModel = NovelAiVibeCodec.defaultModel,
  }) {
    return NovelAiVibeCodec.encodeJson(
      NovelAiVibeCodec.buildBundleMap(vibes, fallbackModel: defaultModel),
    );
  }

  Map<String, dynamic> mergeCompatibleBundleMap(
    Map<String, dynamic>? existing,
    Map<String, dynamic> replacement,
  ) {
    if (existing == null) {
      throw StateError('缺少可安全合并的现有 Vibe Bundle');
    }

    final existingVibes = existing['vibes'];
    final replacementVibes = replacement['vibes'];
    if (existingVibes is! List || replacementVibes is! List) {
      throw StateError('Vibe Bundle 子项结构无效，已取消覆盖');
    }

    final mergedVibes = List<dynamic>.from(existingVibes);
    final usedExistingIndices = <int>{};
    final canUsePositionalFallback =
        existingVibes.length == replacementVibes.length &&
        existingVibes.every(_isValidBundleVibeItem) &&
        replacementVibes.every(_isValidBundleVibeItem);

    for (var i = 0; i < replacementVibes.length; i++) {
      final replacementItem = replacementVibes[i];
      if (replacementItem is! Map) {
        throw StateError('待写入的 Vibe Bundle 子项无效，已取消覆盖');
      }

      final replacementMap = Map<String, dynamic>.from(replacementItem);
      var existingIndex = _findStableVibeIndex(
        existingVibes,
        replacementMap,
        usedExistingIndices,
      );
      if (existingIndex == null &&
          canUsePositionalFallback &&
          !usedExistingIndices.contains(i)) {
        existingIndex = i;
      }
      if (existingIndex == null) {
        throw StateError('无法稳定匹配 Vibe Bundle 子项，已取消覆盖以避免数据丢失');
      }

      final existingItem = existingVibes[existingIndex];
      if (existingItem is! Map) {
        throw StateError('匹配到的 Vibe Bundle 子项无效，已取消覆盖');
      }
      usedExistingIndices.add(existingIndex);
      mergedVibes[existingIndex] = mergeCompatibleVibeMap(
        Map<String, dynamic>.from(existingItem),
        replacementMap,
      );
    }

    final merged = Map<String, dynamic>.from(existing)..addAll(replacement);
    merged['vibes'] = mergedVibes;
    return merged;
  }

  bool _isValidBundleVibeItem(dynamic value) {
    return value is Map &&
        NovelAiVibeCodec.validateSingleMap(Map<String, dynamic>.from(value));
  }

  int? _findStableVibeIndex(
    List<dynamic> existingVibes,
    Map<String, dynamic> replacement,
    Set<int> usedExistingIndices,
  ) {
    final replacementId = replacement['id'];
    if (replacementId is String && replacementId.isNotEmpty) {
      final idMatches = <int>[];
      for (var i = 0; i < existingVibes.length; i++) {
        if (usedExistingIndices.contains(i)) continue;
        final existingItem = existingVibes[i];
        if (existingItem is Map && existingItem['id'] == replacementId) {
          idMatches.add(i);
        }
      }
      if (idMatches.length == 1) return idMatches.single;
      if (idMatches.length > 1) {
        final replacementEncoding = NovelAiVibeCodec.firstEncoding(
          replacement['encodings'],
        );
        if (replacementEncoding == null) return null;
        final encodingMatches = idMatches
            .where((index) {
              final item = existingVibes[index];
              return item is Map &&
                  _containsEncoding(item, replacementEncoding);
            })
            .toList(growable: false);
        return encodingMatches.length == 1 ? encodingMatches.single : null;
      }
    }

    final replacementEncoding = NovelAiVibeCodec.firstEncoding(
      replacement['encodings'],
    );
    if (replacementEncoding == null) return null;

    int? match;
    for (var i = 0; i < existingVibes.length; i++) {
      if (usedExistingIndices.contains(i)) continue;
      final existingItem = existingVibes[i];
      if (existingItem is! Map ||
          !_containsEncoding(existingItem, replacementEncoding)) {
        continue;
      }
      if (match != null) {
        return null;
      }
      match = i;
    }
    return match;
  }

  bool _containsEncoding(Map<dynamic, dynamic> vibe, String encoding) {
    final encodings = vibe['encodings'];
    if (encodings is! Map) return false;
    for (final modelValue in encodings.values) {
      if (modelValue is! Map) continue;
      for (final variantValue in modelValue.values) {
        if (variantValue is Map && variantValue['encoding'] == encoding) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic> mergeCompatibleVibeMap(
    Map<String, dynamic> existing,
    Map<String, dynamic> replacement,
  ) {
    if (!_isCompatibleVibeMap(existing, replacement)) {
      return replacement;
    }

    final merged = Map<String, dynamic>.from(existing)..addAll(replacement);
    final existingCreatedAt = existing['createdAt'];
    if (existingCreatedAt != null) {
      merged['createdAt'] = existingCreatedAt;
    }

    final existingImage = existing['image'];
    if (existingImage is String && existingImage.isNotEmpty) {
      merged['image'] = existingImage;
      merged['type'] = existing['type'] ?? 'image';
      final existingId = existing['id'];
      if (existingId != null) {
        merged['id'] = existingId;
      }
    }

    final existingThumbnail = existing['thumbnail'];
    if (existingThumbnail is String && existingThumbnail.isNotEmpty) {
      merged['thumbnail'] = existingThumbnail;
    }

    final existingImportInfo = existing['importInfo'];
    final replacementImportInfo = replacement['importInfo'];
    if (existingImportInfo is Map && replacementImportInfo is Map) {
      merged['importInfo'] = Map<String, dynamic>.from(existingImportInfo)
        ..addAll(Map<String, dynamic>.from(replacementImportInfo));
    }

    if (_shouldPreserveExistingEncodings(existing, replacement)) {
      _mergeCompatibleEncodings(existing, merged);
    }
    return merged;
  }

  bool _shouldPreserveExistingEncodings(
    Map<String, dynamic> existing,
    Map<String, dynamic> replacement,
  ) {
    final replacementEncodings = replacement['encodings'];
    if (replacementEncodings is Map && replacementEncodings.isNotEmpty) {
      return true;
    }

    final existingImportInfo = existing['importInfo'];
    final replacementImportInfo = replacement['importInfo'];
    if (existingImportInfo is! Map || replacementImportInfo is! Map) {
      return false;
    }
    return existingImportInfo['information_extracted'] ==
        replacementImportInfo['information_extracted'];
  }

  bool _isCompatibleVibeMap(
    Map<String, dynamic> existing,
    Map<String, dynamic> replacement,
  ) {
    final existingId = existing['id'];
    final replacementId = replacement['id'];
    if (existingId is String &&
        existingId.isNotEmpty &&
        existingId == replacementId) {
      return true;
    }

    final replacementEncoding = NovelAiVibeCodec.firstEncoding(
      replacement['encodings'],
    );
    if (replacementEncoding == null) return false;

    final existingEncodings = existing['encodings'];
    if (existingEncodings is! Map) return false;
    for (final modelValue in existingEncodings.values) {
      if (modelValue is! Map) continue;
      for (final variantValue in modelValue.values) {
        if (variantValue is Map &&
            variantValue['encoding'] == replacementEncoding) {
          return true;
        }
      }
    }
    return false;
  }

  void _mergeCompatibleEncodings(
    Map<String, dynamic> existing,
    Map<String, dynamic> replacement,
  ) {
    if (!_isCompatibleVibeMap(existing, replacement)) return;

    final existingEncodings = existing['encodings'];
    final replacementEncodings = replacement['encodings'];
    if (existingEncodings is! Map || replacementEncodings is! Map) {
      return;
    }

    for (final modelEntry in existingEncodings.entries) {
      final oldVariants = modelEntry.value;
      if (oldVariants is! Map) {
        continue;
      }
      final targetVariants = replacementEncodings.putIfAbsent(
        modelEntry.key,
        () => <String, dynamic>{},
      );
      if (targetVariants is! Map) {
        continue;
      }
      for (final variantEntry in oldVariants.entries) {
        final oldIdentity = _encodingVariantIdentity(variantEntry.value);
        final alreadyPresent =
            oldIdentity != null &&
            targetVariants.values.any(
              (value) => _encodingVariantIdentity(value) == oldIdentity,
            );
        if (alreadyPresent) continue;

        var targetKey = variantEntry.key;
        if (targetVariants.containsKey(targetKey)) {
          final preservedKey = _preservedEncodingVariantKey(variantEntry.value);
          targetKey = preservedKey;
          var suffix = 2;
          while (targetVariants.containsKey(targetKey)) {
            targetKey = '$preservedKey-$suffix';
            suffix++;
          }
        }
        targetVariants[targetKey] = variantEntry.value;
      }
    }
  }

  String? _encodingVariantIdentity(dynamic value) {
    if (value is! Map) return null;
    final encoding = value['encoding'];
    if (encoding is! String || encoding.isEmpty) return null;

    final encodingHash = NovelAiVibeCodec.hashString(encoding);
    final params = value['params'];
    if (params is! Map) return encodingHash;
    return '$encodingHash:${NovelAiVibeCodec.encodingParamsKey(Map<String, dynamic>.from(params))}';
  }

  String _preservedEncodingVariantKey(dynamic value) {
    if (value is Map && value['encoding'] is String) {
      return NovelAiVibeCodec.hashString(value['encoding'] as String);
    }
    return NovelAiVibeCodec.hashString(jsonEncode(value));
  }
}
