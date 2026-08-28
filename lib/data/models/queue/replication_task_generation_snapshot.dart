import 'dart:convert';
import 'dart:typed_data';

import '../../../core/enums/precise_ref_type.dart';
import '../image/image_params.dart';
import '../vibe/vibe_reference.dart';

/// Durable, path-free snapshot of the exact generation request confirmed for a
/// queue task. Binary inputs are owned by the persisted task instead of being
/// resolved again from mutable application libraries at execution time.
abstract final class ReplicationTaskGenerationSnapshot {
  static const int schemaVersion = 1;

  static Map<String, dynamic> clone(Map<String, dynamic> snapshot) =>
      encode(decode(snapshot), batchSize: decodeBatchSize(snapshot));

  static Map<String, dynamic> withTaskText(
    Map<String, dynamic> snapshot, {
    required String prompt,
    required String negativePrompt,
  }) => encode(
    decode(snapshot).copyWith(prompt: prompt, negativePrompt: negativePrompt),
    batchSize: decodeBatchSize(snapshot),
  );

  static Map<String, dynamic> encode(ImageParams params, {int? batchSize}) => {
    'schemaVersion': schemaVersion,
    if (batchSize != null) 'batchSize': batchSize,
    'params': params.toJson(),
    'transient': {
      'omitQualityTagHint': params.omitQualityTagHint,
      'omitUcPresetTagHint': params.omitUcPresetTagHint,
      'upscaledEnhance': params.upscaledEnhance,
      'isEnhanceRequest': params.isEnhanceRequest,
      'inpaintMaskClosingIterations': params.inpaintMaskClosingIterations,
      'inpaintMaskExpansionIterations': params.inpaintMaskExpansionIterations,
      'isOutpaint': params.isOutpaint,
    },
    if (params.sourceImage != null)
      'sourceImage': base64Encode(params.sourceImage!),
    if (params.maskImage != null) 'maskImage': base64Encode(params.maskImage!),
    'vibeReferences': [
      for (final reference in params.vibeReferencesV4)
        {
          'value': reference.toJson(),
          if (reference.rawImageData != null)
            'rawImageData': base64Encode(reference.rawImageData!),
        },
    ],
    'preciseReferences': [
      for (final reference in params.preciseReferences)
        {
          'image': base64Encode(reference.image),
          'type': reference.type.name,
          'strength': reference.strength,
          'fidelity': reference.fidelity,
          'enabled': reference.enabled,
        },
    ],
    'characters': [
      for (final character in params.characters)
        {
          'prompt': character.prompt,
          'negativePrompt': character.negativePrompt,
          'positionX': character.positionX,
          'positionY': character.positionY,
          'position': character.position,
        },
    ],
  };

  static int? decodeBatchSize(Map<String, dynamic> snapshot) {
    final value = snapshot['batchSize'];
    if (value == null) return null;
    if (value is! int || value < 1) {
      throw const FormatException('Invalid queue generation batch size');
    }
    return value;
  }

  static ImageParams decode(Map<String, dynamic> snapshot) {
    try {
      return _decode(snapshot);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid queue generation snapshot', error);
    }
  }

  static ImageParams _decode(Map<String, dynamic> snapshot) {
    if (snapshot['schemaVersion'] != schemaVersion ||
        snapshot['params'] is! Map) {
      throw const FormatException('Unsupported queue generation snapshot');
    }
    final params = ImageParams.fromJson(
      Map<String, dynamic>.from(snapshot['params'] as Map),
    );
    final transient = snapshot['transient'] is Map
        ? Map<String, dynamic>.from(snapshot['transient'] as Map)
        : const <String, dynamic>{};
    return params.copyWith(
      omitQualityTagHint: transient['omitQualityTagHint'] == true,
      omitUcPresetTagHint: transient['omitUcPresetTagHint'] == true,
      upscaledEnhance: transient['upscaledEnhance'] == true,
      isEnhanceRequest: transient['isEnhanceRequest'] == true,
      sourceImage: _bytes(snapshot['sourceImage']),
      maskImage: _bytes(snapshot['maskImage']),
      inpaintMaskClosingIterations:
          transient['inpaintMaskClosingIterations'] as int? ?? 0,
      inpaintMaskExpansionIterations:
          transient['inpaintMaskExpansionIterations'] as int? ?? 0,
      isOutpaint: transient['isOutpaint'] == true,
      vibeReferencesV4: [
        for (final item in snapshot['vibeReferences'] as List? ?? const [])
          _decodeVibe(item),
      ],
      preciseReferences: [
        for (final item in snapshot['preciseReferences'] as List? ?? const [])
          _decodePrecise(item),
      ],
      characters: [
        for (final item in snapshot['characters'] as List? ?? const [])
          _decodeCharacter(item),
      ],
    );
  }

  static VibeReference _decodeVibe(Object? item) {
    if (item is! Map || item['value'] is! Map) {
      throw const FormatException('Invalid queued Vibe reference');
    }
    return VibeReference.fromJson(
      Map<String, dynamic>.from(item['value'] as Map),
    ).copyWith(rawImageData: _bytes(item['rawImageData']));
  }

  static PreciseReference _decodePrecise(Object? item) {
    if (item is! Map || item['image'] is! String || item['type'] is! String) {
      throw const FormatException('Invalid queued precise reference');
    }
    final type = PreciseRefType.values
        .where((value) => value.name == item['type'])
        .firstOrNull;
    if (type == null) {
      throw const FormatException('Invalid queued precise reference type');
    }
    return PreciseReference(
      image: _bytes(item['image'])!,
      type: type,
      strength: (item['strength'] as num?)?.toDouble() ?? 1,
      fidelity: (item['fidelity'] as num?)?.toDouble() ?? 1,
      enabled: item['enabled'] != false,
    );
  }

  static CharacterPrompt _decodeCharacter(Object? item) {
    if (item is! Map || item['prompt'] is! String) {
      throw const FormatException('Invalid queued character');
    }
    return CharacterPrompt(
      prompt: item['prompt'] as String,
      negativePrompt: item['negativePrompt'] as String? ?? '',
      positionX: (item['positionX'] as num?)?.toDouble(),
      positionY: (item['positionY'] as num?)?.toDouble(),
      position: item['position'] as String?,
    );
  }

  static Uint8List? _bytes(Object? encoded) {
    if (encoded == null) return null;
    if (encoded is! String) throw const FormatException('Invalid image data');
    try {
      return base64Decode(encoded);
    } on FormatException {
      throw const FormatException('Invalid image data');
    }
  }
}
