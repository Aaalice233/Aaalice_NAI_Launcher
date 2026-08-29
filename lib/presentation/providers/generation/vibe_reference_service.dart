import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/constants/model_capabilities.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_api_utils.dart';
import '../../../core/utils/vibe_performance_diagnostics.dart';
import '../../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_library_storage_service.dart';

final class VibeReferenceService {
  VibeReferenceService({
    required VibeLibraryStorageService libraryStorage,
    required NAIImageEnhancementApiService enhancementApi,
    required bool Function() requestEncodingAuthentication,
    required void Function() preparePostBillingRefresh,
    required void Function() schedulePostBillingRefresh,
  }) : _libraryStorage = libraryStorage,
       _enhancementApi = enhancementApi,
       _requestEncodingAuthentication = requestEncodingAuthentication,
       _preparePostBillingRefresh = preparePostBillingRefresh,
       _schedulePostBillingRefresh = schedulePostBillingRefresh;

  final VibeLibraryStorageService _libraryStorage;
  final NAIImageEnhancementApiService _enhancementApi;
  final bool Function() _requestEncodingAuthentication;
  final void Function() _preparePostBillingRefresh;
  final void Function() _schedulePostBillingRefresh;
  final Map<String, String> _encodingCache = {};
  final Expando<String> _imageHashes = Expando<String>('vibeImageHash');
  List<VibeLibraryEntry> _recentVibes = const [];

  List<VibeLibraryEntry> get recentVibes =>
      List.unmodifiable(_recentVibes.take(5));
  int get cacheSize => _encodingCache.length;

  String imageHash(Uint8List imageData) {
    final cached = _imageHashes[imageData];
    if (cached != null) return cached;
    final hash = base64Encode(sha256.convert(imageData).bytes);
    _imageHashes[imageData] = hash;
    return hash;
  }

  String cacheKey(
    Uint8List imageData, {
    required String model,
    required double informationExtracted,
  }) =>
      '${imageHash(imageData)}|$model|${VibeReference.sanitizeInfoExtracted(informationExtracted)}';

  String? getCached(
    Uint8List imageData, {
    required String model,
    required double informationExtracted,
  }) =>
      _encodingCache[cacheKey(
        imageData,
        model: model,
        informationExtracted: informationExtracted,
      )];

  bool hasCached(
    Uint8List imageData, {
    required String model,
    required double informationExtracted,
  }) =>
      getCached(
        imageData,
        model: model,
        informationExtracted: informationExtracted,
      ) !=
      null;

  void storeCached(
    Uint8List imageData,
    String encoding, {
    required String model,
    required double informationExtracted,
  }) {
    _encodingCache[cacheKey(
          imageData,
          model: model,
          informationExtracted: informationExtracted,
        )] =
        encoding;
  }

  void clearCache() => _encodingCache.clear();

  List<VibeReference> normalize(
    Iterable<VibeReference> references, {
    required String currentModel,
  }) {
    final result = <VibeReference>[];
    for (final reference in references) {
      final raw = reference.rawImageData;
      if (raw != null && raw.isNotEmpty && reference.vibeEncoding.isNotEmpty) {
        final encodingModel = reference.encodingModel ?? currentModel;
        if (getCached(
              raw,
              model: encodingModel,
              informationExtracted: reference.infoExtracted,
            ) ==
            null) {
          storeCached(
            raw,
            reference.vibeEncoding,
            model: encodingModel,
            informationExtracted: reference.infoExtracted,
          );
        }
      }
      if (reference.hasVibeEncoding &&
          reference.canReencodeFromRawSource &&
          reference.encodingModel == null) {
        result.add(reference.copyWith(encodingModel: currentModel));
      } else {
        result.add(reference);
      }
    }
    return List.unmodifiable(result.take(16));
  }

  bool sameSource(VibeReference left, VibeReference right) {
    if (left.vibeEncoding.isNotEmpty && right.vibeEncoding.isNotEmpty) {
      return left.vibeEncoding == right.vibeEncoding;
    }
    if (left.rawImageData != null && right.rawImageData != null) {
      return imageHash(left.rawImageData!) == imageHash(right.rawImageData!);
    }
    return left.displayName == right.displayName &&
        left.bundleSource == right.bundleSource;
  }

  bool sameList(List<VibeReference> left, List<VibeReference> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!sameSource(left[index], right[index])) return false;
    }
    return true;
  }

  int findIndex(List<VibeReference> references, VibeReference target) {
    for (var index = 0; index < references.length; index++) {
      final reference = references[index];
      if (target.vibeEncoding.isNotEmpty && reference.vibeEncoding.isNotEmpty) {
        if (reference.vibeEncoding == target.vibeEncoding) return index;
      } else if (target.rawImageData != null &&
          reference.rawImageData != null) {
        if (imageHash(reference.rawImageData!) ==
            imageHash(target.rawImageData!)) {
          return index;
        }
      } else if (reference.displayName == target.displayName) {
        return index;
      }
    }
    return -1;
  }

  List<VibeReference> mergeReferences(
    List<VibeReference> current,
    List<VibeReference> incoming,
  ) {
    final reordered = <VibeReference>[];
    final added = <VibeReference>[];
    for (final reference in incoming) {
      (findIndex(current, reference) >= 0 ? reordered : added).add(reference);
    }
    if (reordered.isEmpty && added.isEmpty) return current;
    final result = [...current];
    for (final reference in reordered) {
      final index = findIndex(result, reference);
      if (index >= 0) result.removeAt(index);
    }
    final available = 16 - result.length;
    result.addAll(added.take(available));
    result.addAll(reordered);
    return List.unmodifiable(
      result.length <= 16 ? result : result.sublist(result.length - 16),
    );
  }

  VibeReference updateReference(
    VibeReference current, {
    required String model,
    double? strength,
    double? informationExtracted,
    String? vibeEncoding,
    bool? enabled,
  }) {
    final nextInfo = informationExtracted == null
        ? current.infoExtracted
        : VibeReference.sanitizeInfoExtracted(informationExtracted);
    final infoChanged = nextInfo != current.infoExtracted;
    String encoding;
    String? encodingModel = current.encodingModel;
    if (vibeEncoding != null) {
      encoding = vibeEncoding;
      encodingModel = encoding.isEmpty ? null : model;
    } else if (infoChanged && current.canReencodeFromRawSource) {
      final raw = current.rawImageData;
      final cached =
          raw == null ||
              !ModelCapabilityRegistry.of(model).supportsEncodedVibeTransfer
          ? null
          : getCached(raw, model: model, informationExtracted: nextInfo);
      encoding = cached ?? '';
      encodingModel = cached == null ? null : model;
    } else {
      encoding = current.vibeEncoding;
    }
    final updated = current.copyWith(
      strength: strength == null
          ? current.strength
          : VibeReference.sanitizeStrength(strength),
      infoExtracted: nextInfo,
      vibeEncoding: encoding,
      encodingModel: encodingModel,
      enabled: enabled ?? current.enabled,
    );
    return encoding.isEmpty ? updated : updated.normalizedForLibraryStorage();
  }

  Future<VibeEncodingResult> encode(
    Uint8List imageData, {
    required String model,
    required double informationExtracted,
    String? vibeName,
  }) async {
    if (!ModelCapabilityRegistry.of(model).supportsEncodedVibeTransfer) {
      return const VibeEncodingResult.unsupportedModel();
    }
    final cached = getCached(
      imageData,
      model: model,
      informationExtracted: informationExtracted,
    );
    if (cached != null) return VibeEncodingResult.cacheHit(cached);
    if (!_requestEncodingAuthentication()) {
      return const VibeEncodingResult.authenticationRequired();
    }
    _preparePostBillingRefresh();
    try {
      final encoding = await _enhancementApi.encodeVibe(
        imageData,
        model: model,
        informationExtracted: informationExtracted,
      );
      storeCached(
        imageData,
        encoding,
        model: model,
        informationExtracted: informationExtracted,
      );
      return VibeEncodingResult.encoded(encoding);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Vibe 编码失败: ${vibeName ?? 'unknown'}',
        error,
        stackTrace,
        'VibeCache',
      );
      return VibeEncodingResult.failed(error);
    } finally {
      _schedulePostBillingRefresh();
    }
  }

  Future<VibeRecentResult> loadRecent({int limit = 20}) async {
    final span = VibePerformanceDiagnostics.start('generation.loadRecentVibes');
    try {
      final entries = await _libraryStorage.getRecentDisplayEntries(
        limit: limit,
      );
      _recentVibes = List.unmodifiable(entries);
      return VibeRecentResult.success(_recentVibes);
    } catch (error, stackTrace) {
      AppLogger.e('Failed to load recent vibes', error, stackTrace);
      return VibeRecentResult.failed(error, _recentVibes);
    } finally {
      span.finish(details: {'entries': _recentVibes.length});
    }
  }

  Future<VibeUsageResult> recordUsage(VibeReference vibe) async {
    try {
      final existing = await _libraryStorage.findMatchingEntry(vibe);
      if (existing != null) {
        await _libraryStorage.incrementUsedCount(existing.id);
      } else if (vibe.vibeEncoding.isNotEmpty) {
        final entry = VibeLibraryEntry.fromVibeReference(
          name: vibe.displayName,
          vibeData: vibe,
        );
        await _libraryStorage.saveEntry(entry);
        await _libraryStorage.incrementUsedCount(entry.id);
      }
      await loadRecent();
      return const VibeUsageResult.success();
    } catch (error, stackTrace) {
      AppLogger.e('Failed to record vibe usage', error, stackTrace);
      return VibeUsageResult.failed(error);
    }
  }

  Future<VibeLibraryEntry?> getLibraryEntry(String id) =>
      _libraryStorage.getEntry(id);

  Future<void> incrementLibraryUsage(String id) =>
      _libraryStorage.incrementUsedCount(id);

  Future<VibeLibrarySaveResult> saveLibraryEntry(
    VibeReference vibe, {
    required String name,
  }) async {
    try {
      final entry = VibeLibraryEntry.fromVibeReference(
        name: name,
        vibeData: vibe.normalizedForLibraryStorage(),
      );
      final saved = await _libraryStorage.saveEntry(entry);
      return VibeLibrarySaveResult.success(saved.id);
    } catch (error, stackTrace) {
      AppLogger.e('Failed to save vibe library entry', error, stackTrace);
      return VibeLibrarySaveResult.failed(error);
    }
  }

  Future<List<VibeReference>> ensureEncoded(
    List<VibeReference> references, {
    required String model,
  }) async {
    if (references.isEmpty ||
        !ModelCapabilityRegistry.of(model).supportsEncodedVibeTransfer) {
      return references;
    }
    var changed = false;
    final result = <VibeReference>[];
    for (final reference in references) {
      final raw = reference.rawImageData;
      if (!reference.enabled ||
          !reference.needsEncodingForModel(model) ||
          raw == null) {
        result.add(reference);
        continue;
      }
      final encoding =
          getCached(
            raw,
            model: model,
            informationExtracted: reference.infoExtracted,
          ) ??
          (await encode(
            raw,
            model: model,
            informationExtracted: reference.infoExtracted,
            vibeName: reference.displayName,
          )).encoding;
      if (encoding == null || encoding.isEmpty) {
        result.add(reference);
      } else {
        result.add(reference.withEncodedVibe(encoding, model: model));
        changed = true;
      }
    }
    return changed ? List.unmodifiable(result) : references;
  }

  Future<VibeReference?> prepareForLibrarySave(
    VibeReference reference, {
    required String model,
    required double strength,
    required double informationExtracted,
  }) async {
    final next = reference.copyWith(
      strength: VibeReference.sanitizeStrength(strength),
      infoExtracted: VibeReference.sanitizeInfoExtracted(informationExtracted),
    );
    if (!ModelCapabilityRegistry.of(model).supportsEncodedVibeTransfer) {
      return next.infoExtracted != reference.infoExtracted &&
              next.canReencodeFromRawSource
          ? next.copyWith(vibeEncoding: '', encodingModel: null)
          : next;
    }
    final shouldEncode =
        next.needsEncodingForModel(model) ||
        (next.canReencodeFromRawSource &&
            next.infoExtracted != reference.infoExtracted);
    if (!shouldEncode) return next.normalizedForLibraryStorage();
    final raw = next.rawImageData;
    if (raw == null || raw.isEmpty) return next;
    final encoding =
        getCached(
          raw,
          model: model,
          informationExtracted: next.infoExtracted,
        ) ??
        (await encode(
          raw,
          model: model,
          informationExtracted: next.infoExtracted,
          vibeName: next.displayName,
        )).encoding;
    return encoding == null || encoding.isEmpty
        ? null
        : next.withEncodedVibe(encoding, model: model);
  }

  Future<String?> saveReferencesToLibrary(
    List<VibeReference> references, {
    required String model,
    required String name,
  }) async {
    if (references.isEmpty) return null;
    try {
      final savedIds = <String>[];
      for (final reference in references) {
        final prepared = await prepareForLibrarySave(
          reference,
          model: model,
          strength: reference.strength,
          informationExtracted: reference.infoExtracted,
        );
        if (prepared == null) return null;
        final saved = await saveLibraryEntry(
          prepared,
          name: references.length == 1
              ? name
              : '$name (${reference.displayName})',
        );
        if (saved.id == null) return null;
        savedIds.add(saved.id!);
      }
      await loadRecent();
      return savedIds.first;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to save vibes to library', error, stackTrace);
      return null;
    }
  }

  Future<VibeReference?> useLibraryEntry(String id) async {
    try {
      final entry = await getLibraryEntry(id);
      if (entry == null) return null;
      await incrementLibraryUsage(id);
      await loadRecent();
      return entry.toVibeReference();
    } catch (error, stackTrace) {
      AppLogger.e('Failed to use vibe library entry', error, stackTrace);
      return null;
    }
  }

  Future<PreciseReferenceNormalizationResult> normalizePrecisePng(
    Uint8List image,
  ) async {
    try {
      final normalized = await NAIApiUtils.ensurePngFormatAsync(image);
      NAIApiUtils.markNormalizedPreciseReferencePng(normalized);
      return PreciseReferenceNormalizationResult.success(normalized);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to normalize precise reference image',
        error,
        stackTrace,
        'GenerationParams',
      );
      return PreciseReferenceNormalizationResult.failed(error);
    }
  }
}

enum VibeEncodingStatus {
  encoded,
  cacheHit,
  unsupportedModel,
  authenticationRequired,
  failed,
}

final class VibeEncodingResult {
  const VibeEncodingResult._(this.status, this.encoding, this.error);
  const VibeEncodingResult.encoded(String encoding)
    : this._(VibeEncodingStatus.encoded, encoding, null);
  const VibeEncodingResult.cacheHit(String encoding)
    : this._(VibeEncodingStatus.cacheHit, encoding, null);
  const VibeEncodingResult.unsupportedModel()
    : this._(VibeEncodingStatus.unsupportedModel, null, null);
  const VibeEncodingResult.authenticationRequired()
    : this._(VibeEncodingStatus.authenticationRequired, null, null);
  const VibeEncodingResult.failed(Object error)
    : this._(VibeEncodingStatus.failed, null, error);

  final VibeEncodingStatus status;
  final String? encoding;
  final Object? error;
  bool get isCacheHit => status == VibeEncodingStatus.cacheHit;
}

final class VibeRecentResult {
  VibeRecentResult._(this.entries, this.error);
  VibeRecentResult.success(List<VibeLibraryEntry> entries)
    : this._(List.unmodifiable(entries), null);
  VibeRecentResult.failed(Object error, List<VibeLibraryEntry> current)
    : this._(List.unmodifiable(current), error);

  final List<VibeLibraryEntry> entries;
  final Object? error;
}

final class VibeUsageResult {
  const VibeUsageResult._(this.error);
  const VibeUsageResult.success() : this._(null);
  const VibeUsageResult.failed(Object error) : this._(error);
  final Object? error;
}

final class VibeLibrarySaveResult {
  const VibeLibrarySaveResult._(this.id, this.error);
  const VibeLibrarySaveResult.success(String id) : this._(id, null);
  const VibeLibrarySaveResult.failed(Object error) : this._(null, error);
  final String? id;
  final Object? error;
}

final class PreciseReferenceNormalizationResult {
  const PreciseReferenceNormalizationResult._(this.image, this.error);
  const PreciseReferenceNormalizationResult.success(Uint8List image)
    : this._(image, null);
  const PreciseReferenceNormalizationResult.failed(Object error)
    : this._(null, error);
  final Uint8List? image;
  final Object? error;
}
