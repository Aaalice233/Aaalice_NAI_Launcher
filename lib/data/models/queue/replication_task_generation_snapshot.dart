import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/isolate_pool.dart';
import '../../../core/utils/json_utf8_stream.dart';
import '../image/image_params.dart';
import '../vibe/vibe_reference.dart';

/// 队列任务确认时的聚焦重绘状态；它属于任务自带的源图，执行时不能借用生成页当前状态
class QueuedFocusedInpaint {
  const QueuedFocusedInpaint({
    required this.enabled,
    required this.contextPadding,
    this.selectionRect,
    this.contextCrop,
  });

  const QueuedFocusedInpaint.disabled()
    : enabled = false,
      contextPadding = FocusedInpaintUtils.defaultContextPadding,
      selectionRect = null,
      contextCrop = null;

  final bool enabled;
  final double contextPadding;
  final Rect? selectionRect;

  /// 聚焦外扩的固定裁切区
  final Rect? contextCrop;
}

/// Durable, path-free snapshot of the exact generation request confirmed for a
/// queue task. Binary inputs are owned by the persisted task instead of being
/// resolved again from mutable application libraries at execution time.
///
/// Image payloads are stored as base64 text; conversions carrying a large
/// payload run on a [ComputeGate] isolate instead of the caller's isolate.
abstract final class ReplicationTaskGenerationSnapshot {
  static const int schemaVersion = 1;

  // 低于此长度的 base64 转换不足 0.1ms，不值得启动 isolate 和排队等闸门
  static const int _inlinePayloadLimit = 64 * 1024;

  static Future<Map<String, dynamic>> clone(Map<String, dynamic> snapshot) =>
      _convert(
        _storedPayloadLength(snapshot),
        () => _clone(snapshot),
        debugName: 'ReplicationSnapshot.clone',
      );

  static Future<Map<String, dynamic>> withTaskText(
    Map<String, dynamic> snapshot, {
    required String prompt,
    required String negativePrompt,
  }) => _convert(
    _storedPayloadLength(snapshot),
    () =>
        _withTaskText(snapshot, prompt: prompt, negativePrompt: negativePrompt),
    debugName: 'ReplicationSnapshot.withTaskText',
  );

  /// [focused] 为空时不写入聚焦段，执行端沿用旧快照的行为
  static Future<Map<String, dynamic>> encode(
    ImageParams params, {
    int? batchSize,
    QueuedFocusedInpaint? focused,
    ComputeGate? gate,
  }) => _convert(
    _paramsPayloadLength(params),
    () => _encode(params, batchSize: batchSize, focused: focused),
    gate: gate,
    debugName: 'ReplicationSnapshot.encode',
  );

  static Future<ImageParams> decode(Map<String, dynamic> snapshot) => _convert(
    _storedPayloadLength(snapshot),
    () => _decodeChecked(snapshot),
    debugName: 'ReplicationSnapshot.decode',
  );

  /// 每个快照按 `utf8.encode(jsonEncode(snapshot)).length` 计的持久化字节数，顺序与入参一致
  static Future<List<int>> measurePersistedBytes(
    List<Map<String, dynamic>> snapshots,
  ) => ComputeGate().runIsolate(
    () => [
      for (final snapshot in snapshots) JsonUtf8Stream.byteLength(snapshot),
    ],
    debugName: 'ReplicationSnapshot.measure',
  );

  static Future<T> _convert<T>(
    int payloadLength,
    T Function() conversion, {
    required String debugName,
    ComputeGate? gate,
  }) => payloadLength < _inlinePayloadLimit
      ? Future.sync(conversion)
      : (gate ?? ComputeGate()).runIsolate(conversion, debugName: debugName);

  static int _paramsPayloadLength(ImageParams params) {
    var length =
        _base64Length(params.sourceImage) + _base64Length(params.maskImage);
    for (final reference in params.vibeReferencesV4) {
      length += _base64Length(reference.rawImageData);
    }
    for (final reference in params.preciseReferences) {
      length += _base64Length(reference.image);
    }
    return length;
  }

  static int _base64Length(Uint8List? bytes) =>
      bytes == null ? 0 : (bytes.length + 2) ~/ 3 * 4;

  // 只做长度估算，结构非法时交给解码抛 FormatException
  static int _storedPayloadLength(Map<String, dynamic> snapshot) {
    int textLength(Object? value) => value is String ? value.length : 0;
    int itemsLength(Object? items, String key) => items is List
        ? items.fold(
            0,
            (total, item) => total + (item is Map ? textLength(item[key]) : 0),
          )
        : 0;
    return textLength(snapshot['sourceImage']) +
        textLength(snapshot['maskImage']) +
        itemsLength(snapshot['vibeReferences'], 'rawImageData') +
        itemsLength(snapshot['preciseReferences'], 'image');
  }

  static Map<String, dynamic> _clone(Map<String, dynamic> snapshot) => _encode(
    _decodeChecked(snapshot),
    batchSize: decodeBatchSize(snapshot),
    focused: decodeFocused(snapshot),
  );

  static Map<String, dynamic> _withTaskText(
    Map<String, dynamic> snapshot, {
    required String prompt,
    required String negativePrompt,
  }) => _encode(
    _decodeChecked(
      snapshot,
    ).copyWith(prompt: prompt, negativePrompt: negativePrompt),
    batchSize: decodeBatchSize(snapshot),
    focused: decodeFocused(snapshot),
  );

  static Map<String, dynamic> _encode(
    ImageParams params, {
    int? batchSize,
    QueuedFocusedInpaint? focused,
  }) => {
    'schemaVersion': schemaVersion,
    if (batchSize != null) 'batchSize': batchSize,
    if (focused != null) 'focused': _encodeFocused(focused),
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

  /// 旧快照没有聚焦段时返回 null
  static QueuedFocusedInpaint? decodeFocused(Map<String, dynamic> snapshot) {
    final value = snapshot['focused'];
    if (value == null) return null;
    if (value is! Map ||
        value['enabled'] is! bool ||
        value['contextPadding'] is! num) {
      throw const FormatException('Invalid queued focused inpaint');
    }
    return QueuedFocusedInpaint(
      enabled: value['enabled'] as bool,
      contextPadding: (value['contextPadding'] as num).toDouble(),
      selectionRect: _decodeRect(value['selectionRect']),
      contextCrop: _decodeRect(value['contextCrop']),
    );
  }

  static Map<String, dynamic> _encodeFocused(QueuedFocusedInpaint focused) => {
    'enabled': focused.enabled,
    'contextPadding': focused.contextPadding,
    if (focused.selectionRect != null)
      'selectionRect': _encodeRect(focused.selectionRect!),
    if (focused.contextCrop != null)
      'contextCrop': _encodeRect(focused.contextCrop!),
  };

  static List<double> _encodeRect(Rect rect) => [
    rect.left,
    rect.top,
    rect.width,
    rect.height,
  ];

  static Rect? _decodeRect(Object? value) {
    if (value == null) return null;
    if (value is! List || value.length != 4 || value.any((v) => v is! num)) {
      throw const FormatException('Invalid queued focused rectangle');
    }
    final numbers = value.cast<num>();
    return Rect.fromLTWH(
      numbers[0].toDouble(),
      numbers[1].toDouble(),
      numbers[2].toDouble(),
      numbers[3].toDouble(),
    );
  }

  static ImageParams _decodeChecked(Map<String, dynamic> snapshot) {
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
