import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/model_capabilities.dart';
import '../../../core/enums/precise_ref_type.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_api_utils.dart';
import '../../../core/utils/vibe_performance_diagnostics.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../../data/services/vibe_library_storage_service.dart';

const _generationStateSchemaVersion = 2;
const _advancedOptionsExpandedKey = 'generation_advanced_options_expanded';

final class GenerationParamsPersistenceService {
  GenerationParamsPersistenceService({
    required LocalStorageService localStorage,
    required VibeLibraryStorageService referenceStorage,
  }) : _localStorage = localStorage,
       _referenceStorage = referenceStorage;

  final LocalStorageService _localStorage;
  final VibeLibraryStorageService _referenceStorage;

  Timer? _saveDebounceTimer;
  Future<void>? _saveInFlight;
  Future<GenerationStateRestoreResult>? _restoreInFlight;
  GenerationStateSnapshot? _queuedSnapshot;
  bool _isRestoring = false;
  bool _hasRestored = false;
  bool _isDisposed = false;

  ImageParams buildDefaults() {
    final model = ImageModels.migrateLegacyModel(
      _localStorage.getDefaultModel(),
    );
    final capabilities = ModelCapabilityRegistry.of(model);
    return ImageParams(
      prompt: _localStorage.getLastPrompt(),
      negativePrompt: _localStorage.getLastNegativePrompt(),
      model: model,
      sampler: _localStorage.getDefaultSampler(),
      steps: _localStorage.getDefaultSteps(),
      scale: _localStorage.getDefaultScale(),
      width: _localStorage.getDefaultWidth(),
      height: _localStorage.getDefaultHeight(),
      smea: _localStorage.getLastSmea(),
      smeaDyn: _localStorage.getLastSmeaDyn(),
      cfgRescale: _localStorage.getLastCfgRescale(),
      noiseSchedule: NoiseSchedules.resolve(
        _localStorage.getLastNoiseSchedule(),
        allowNative: capabilities.allowsNativeNoiseSchedule,
      ),
      varietyPlus:
          capabilities.retainsVarietyPlus && _localStorage.getLastVarietyPlus(),
      straightAlpha: _localStorage.getImageStraightAlpha(),
      transparentBackground: _localStorage.getLastTransparentBackground(),
      qualityTier: _localStorage.getQualityPresetNaiTier(),
      e2eUpscale: _localStorage.getLastE2eUpscale(),
      seed:
          _localStorage.getSeedLocked() &&
              _localStorage.getLockedSeedValue() != null
          ? _localStorage.getLockedSeedValue()!
          : -1,
    );
  }

  void scheduleSave(
    GenerationStateSnapshot snapshot, {
    bool immediate = false,
  }) {
    if (_isRestoring || _isDisposed) return;
    _queuedSnapshot = snapshot;
    _saveDebounceTimer?.cancel();
    if (immediate) {
      unawaited(save(snapshot));
      return;
    }
    _saveDebounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(save(snapshot)),
    );
  }

  Future<void> save(GenerationStateSnapshot snapshot) {
    if (_isRestoring || _isDisposed) return Future<void>.value();
    _queuedSnapshot = snapshot;
    final active = _saveInFlight;
    if (active != null) return active;

    late final Future<void> operation;
    operation = _runSaveLoop().whenComplete(() {
      if (identical(_saveInFlight, operation)) _saveInFlight = null;
    });
    _saveInFlight = operation;
    return operation;
  }

  Future<void> _runSaveLoop() async {
    final span = VibePerformanceDiagnostics.start(
      'generation.runStateSaveLoop',
    );
    var iterations = 0;
    try {
      while (!_isDisposed && !_isRestoring) {
        await Future<void>.delayed(Duration.zero);
        final snapshot = _queuedSnapshot;
        _queuedSnapshot = null;
        if (snapshot == null) return;
        iterations++;
        await _saveSnapshot(snapshot);
        if (_queuedSnapshot == null) return;
      }
    } finally {
      span.finish(
        details: {
          'iterations': iterations,
          'queuedAgain': _queuedSnapshot != null,
        },
      );
    }
  }

  Future<void> _saveSnapshot(GenerationStateSnapshot snapshot) async {
    final span = VibePerformanceDiagnostics.start(
      'generation.saveStateSnapshot',
      details: {
        'vibes': snapshot.vibeReferences.length,
        'preciseRefs': snapshot.preciseReferences.length,
      },
    );
    var jsonChars = 0;
    try {
      final input = snapshot.toIsolateInput();
      final stateJson = await Isolate.run(() => _encodeStateJson(input));
      jsonChars = stateJson.length;
      await _referenceStorage.saveGenerationStateJson(stateJson);
      AppLogger.d('Generation state saved', 'GenerationParams');
    } catch (error, stackTrace) {
      AppLogger.e('Failed to save generation state', error, stackTrace);
    } finally {
      span.finish(details: {'jsonChars': jsonChars});
    }
  }

  Future<GenerationStateRestoreResult> restore() {
    if (_hasRestored) {
      return Future.value(const GenerationStateRestoreResult.empty());
    }
    final active = _restoreInFlight;
    if (active != null) return active;

    late final Future<GenerationStateRestoreResult> operation;
    operation = _restore().whenComplete(() {
      if (identical(_restoreInFlight, operation)) _restoreInFlight = null;
    });
    _restoreInFlight = operation;
    return operation;
  }

  Future<GenerationStateRestoreResult> _restore() async {
    final span = VibePerformanceDiagnostics.start('generation.restoreState');
    _isRestoring = true;
    var jsonChars = 0;
    try {
      final stateJson = await _referenceStorage.loadGenerationStateJson();
      if (stateJson == null || stateJson.isEmpty) {
        _hasRestored = true;
        return const GenerationStateRestoreResult.empty();
      }
      jsonChars = stateJson.length;
      final decoded = await Isolate.run(() => _decodeStateJson(stateJson));
      final result = GenerationStateRestoreResult.fromDecoded(decoded);
      _hasRestored = true;
      return result;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to restore generation state', error, stackTrace);
      return const GenerationStateRestoreResult.failed();
    } finally {
      _isRestoring = false;
      span.finish(details: {'jsonChars': jsonChars});
    }
  }

  Future<bool?> loadAdvancedOptionsExpanded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_advancedOptionsExpandedKey);
    } catch (error, stackTrace) {
      AppLogger.e('Failed to load panel states', error, stackTrace);
      return null;
    }
  }

  Future<void> saveAdvancedOptionsExpanded(bool expanded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_advancedOptionsExpandedKey, expanded);
    } catch (error, stackTrace) {
      AppLogger.e('Failed to save panel states', error, stackTrace);
    }
  }

  void dispose() {
    _isDisposed = true;
    _saveDebounceTimer?.cancel();
  }
}

final class GenerationStateSnapshot {
  GenerationStateSnapshot({
    required List<VibeReference> vibeReferences,
    required List<PreciseReference> preciseReferences,
    required this.normalizeVibeStrength,
  }) : vibeReferences = List.unmodifiable(vibeReferences),
       preciseReferences = List.unmodifiable(preciseReferences);

  final List<VibeReference> vibeReferences;
  final List<PreciseReference> preciseReferences;
  final bool normalizeVibeStrength;

  Map<String, Object?> toIsolateInput() => {
    'schemaVersion': _generationStateSchemaVersion,
    'vibeReferences': vibeReferences
        .map(
          (vibe) => <String, Object?>{
            'displayName': vibe.displayName,
            'vibeEncoding': vibe.vibeEncoding,
            'strength': vibe.strength,
            'infoExtracted': vibe.infoExtracted,
            'encodingModel': vibe.encodingModel,
            'sourceType': vibe.sourceType.name,
            'enabled': vibe.enabled,
            'bundleSource': vibe.bundleSource,
            'thumbnail': vibe.thumbnail,
            'rawImageData': vibe.rawImageData,
          },
        )
        .toList(growable: false),
    'preciseReferences': preciseReferences
        .map(
          (reference) => <String, Object?>{
            'type': reference.type.toApiString(),
            'strength': reference.strength,
            'fidelity': reference.fidelity,
            'enabled': reference.enabled,
            'image': reference.image,
            'isNormalizedPng': NAIApiUtils.isKnownNormalizedPreciseReferencePng(
              reference.image,
            ),
          },
        )
        .toList(growable: false),
    'normalizeVibeStrength': normalizeVibeStrength,
    'savedAt': DateTime.now().toIso8601String(),
  };
}

final class GenerationStateRestoreResult {
  const GenerationStateRestoreResult({
    required this.vibeReferences,
    required this.preciseReferences,
    required this.normalizeVibeStrength,
    required this.shouldApply,
    required this.shouldRewrite,
    required this.isTerminal,
  });

  const GenerationStateRestoreResult.empty()
    : vibeReferences = const [],
      preciseReferences = const [],
      normalizeVibeStrength = true,
      shouldApply = false,
      shouldRewrite = false,
      isTerminal = true;

  const GenerationStateRestoreResult.failed()
    : vibeReferences = const [],
      preciseReferences = const [],
      normalizeVibeStrength = true,
      shouldApply = false,
      shouldRewrite = false,
      isTerminal = false;

  factory GenerationStateRestoreResult.fromDecoded(Map<String, Object?> data) {
    final vibes = <VibeReference>[];
    final rawVibes = data['vibeReferences'] as List? ?? const [];
    for (var index = 0; index < rawVibes.length; index++) {
      final raw = rawVibes[index];
      if (raw is! Map) continue;
      final value = Map<String, Object?>.from(raw);
      final sourceName = value['sourceType'] as String?;
      vibes.add(
        VibeReference(
          displayName: value['displayName'] as String? ?? 'Vibe ${index + 1}',
          vibeEncoding: value['vibeEncoding'] as String? ?? '',
          thumbnail:
              value['thumbnail'] as Uint8List? ??
              value['rawImageData'] as Uint8List?,
          rawImageData: value['rawImageData'] as Uint8List?,
          strength: (value['strength'] as num?)?.toDouble() ?? 0.6,
          infoExtracted: (value['infoExtracted'] as num?)?.toDouble() ?? 0.7,
          encodingModel: value['encodingModel'] as String?,
          sourceType: VibeSourceType.values.firstWhere(
            (item) => item.name == sourceName,
            orElse: () => VibeSourceType.rawImage,
          ),
          enabled: value['enabled'] as bool? ?? true,
          bundleSource: value['bundleSource'] as String?,
        ),
      );
    }

    final precise = <PreciseReference>[];
    for (final raw in data['preciseReferences'] as List? ?? const []) {
      if (raw is! Map) continue;
      final value = Map<String, Object?>.from(raw);
      final image = value['image'] as Uint8List?;
      if (image == null || image.isEmpty) continue;
      final typeName = value['type'] as String?;
      precise.add(
        PreciseReference(
          image: value['isNormalizedPng'] as bool? ?? false
              ? NAIApiUtils.markNormalizedPreciseReferencePng(image)
              : image,
          type: PreciseRefType.values.firstWhere(
            (item) => item.toApiString() == typeName,
            orElse: () => PreciseRefType.character,
          ),
          strength: (value['strength'] as num?)?.toDouble() ?? 1.0,
          fidelity: (value['fidelity'] as num?)?.toDouble() ?? 1.0,
          enabled: value['enabled'] as bool? ?? true,
        ),
      );
    }

    return GenerationStateRestoreResult(
      vibeReferences: List.unmodifiable(vibes.take(16)),
      preciseReferences: List.unmodifiable(precise),
      normalizeVibeStrength: data['normalizeVibeStrength'] as bool? ?? true,
      shouldApply: true,
      shouldRewrite: true,
      isTerminal: true,
    );
  }

  final List<VibeReference> vibeReferences;
  final List<PreciseReference> preciseReferences;
  final bool normalizeVibeStrength;
  final bool shouldApply;
  final bool shouldRewrite;
  final bool isTerminal;
}

String _encodeStateJson(Map<String, Object?> input) {
  final vibes = (input['vibeReferences'] as List? ?? const [])
      .whereType<Map>()
      .map((raw) {
        final thumbnail = raw['thumbnail'] as Uint8List?;
        final rawImage = raw['rawImageData'] as Uint8List?;
        final preview = thumbnail ?? rawImage;
        return <String, Object?>{
          'displayName': raw['displayName'],
          'vibeEncoding': raw['vibeEncoding'],
          'strength': raw['strength'],
          'infoExtracted': raw['infoExtracted'],
          'encodingModel': raw['encodingModel'],
          'sourceType': raw['sourceType'],
          'enabled': raw['enabled'] as bool? ?? true,
          'bundleSource': raw['bundleSource'],
          'thumbnailBase64':
              preview != null &&
                  (rawImage == null || !_bytesEqual(preview, rawImage))
              ? base64Encode(preview)
              : null,
          'rawImageDataBase64': rawImage == null
              ? null
              : base64Encode(rawImage),
        };
      })
      .toList(growable: false);
  final precise = (input['preciseReferences'] as List? ?? const [])
      .whereType<Map>()
      .map((raw) {
        final image = raw['image'] as Uint8List?;
        return <String, Object?>{
          'type': raw['type'],
          'strength': raw['strength'],
          'fidelity': raw['fidelity'],
          'enabled': raw['enabled'] as bool? ?? true,
          'imageBase64': image == null ? null : base64Encode(image),
          'isNormalizedPng': raw['isNormalizedPng'] as bool? ?? false,
        };
      })
      .toList(growable: false);
  return jsonEncode({
    'schemaVersion': input['schemaVersion'],
    'vibeReferences': vibes,
    'preciseReferences': precise,
    'normalizeVibeStrength': input['normalizeVibeStrength'] as bool? ?? true,
    'savedAt': input['savedAt'],
  });
}

Map<String, Object?> _decodeStateJson(String source) {
  final raw = jsonDecode(source) as Map<String, dynamic>;
  final vibes = <Map<String, Object?>>[];
  final rawVibes = raw['vibeReferences'] as List?;
  if (rawVibes != null) {
    for (var index = 0; index < rawVibes.length; index++) {
      final item = rawVibes[index];
      if (item is! Map) continue;
      final value = Map<String, dynamic>.from(item);
      final thumbnail = _decodeBase64(value['thumbnailBase64'] as String?);
      final rawImage = _decodeBase64(value['rawImageDataBase64'] as String?);
      vibes.add({
        'displayName': value['displayName'] as String? ?? 'Vibe ${index + 1}',
        'vibeEncoding': value['vibeEncoding'] as String? ?? '',
        'thumbnail': thumbnail ?? rawImage,
        'rawImageData': rawImage,
        'strength': (value['strength'] as num?)?.toDouble() ?? 0.6,
        'infoExtracted': (value['infoExtracted'] as num?)?.toDouble() ?? 0.7,
        'encodingModel': value['encodingModel'] as String?,
        'sourceType': value['sourceType'] as String?,
        'enabled': value['enabled'] as bool? ?? true,
        'bundleSource': value['bundleSource'] as String?,
      });
    }
  } else {
    // Version 0 stored only encoded references under vibeEntryIds.
    for (final encoding
        in (raw['vibeEntryIds'] as List?)?.whereType<String>() ??
            const <String>[]) {
      if (encoding.isEmpty) continue;
      vibes.add({
        'displayName': 'Vibe ${vibes.length + 1}',
        'vibeEncoding': encoding,
        'sourceType': VibeSourceType.naiv4vibe.name,
        'enabled': true,
      });
    }
  }

  final precise = <Map<String, Object?>>[];
  for (final item in raw['preciseReferences'] as List? ?? const []) {
    if (item is! Map) continue;
    final value = Map<String, dynamic>.from(item);
    final image = _decodeBase64(value['imageBase64'] as String?);
    if (image == null || image.isEmpty) continue;
    precise.add({
      'type':
          value['type'] as String? ?? PreciseRefType.character.toApiString(),
      'strength': (value['strength'] as num?)?.toDouble() ?? 1.0,
      'fidelity': (value['fidelity'] as num?)?.toDouble() ?? 1.0,
      'enabled': value['enabled'] as bool? ?? true,
      'image': image,
      'isNormalizedPng': value['isNormalizedPng'] as bool? ?? false,
    });
  }
  return {
    'vibeReferences': vibes,
    'preciseReferences': precise,
    'normalizeVibeStrength': raw['normalizeVibeStrength'] as bool? ?? true,
  };
}

Uint8List? _decodeBase64(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

bool _bytesEqual(Uint8List left, Uint8List right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
