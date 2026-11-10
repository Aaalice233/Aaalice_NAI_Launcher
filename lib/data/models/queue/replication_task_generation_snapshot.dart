import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import '../../../core/enums/precise_ref_type.dart';
import '../../../core/storage/replication_queue_blob_store.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../image/image_params.dart';
import '../vibe/vibe_reference.dart';
import 'replication_task_snapshot_blobs.dart';

export 'replication_task_snapshot_blobs.dart' show PendingSnapshotBlob;

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

/// [ReplicationTaskGenerationSnapshot.intern] 的结果；释放前其中的图片不会被清扫。
class InternedSnapshots {
  const InternedSnapshots(this.snapshots, this._lease);

  final List<Map<String, dynamic>?> snapshots;
  final QueueBlobLease? _lease;

  Iterable<String> get digests =>
      _lease?.refs.map((ref) => ref.sha256) ?? const <String>[];

  void release() => _lease?.release();
}

/// 队列任务确认时完整生成请求的快照，执行时不再从可变的库中重新解析输入。
///
/// 快照有两种形态：[encode] 返回的待落盘形态在图片槽位放 [PendingSnapshotBlob]；
/// 入队时经 [intern] 写入 [ReplicationQueueBlobStore] 后变成引用形态，槽位只存
/// `{sha256, length}`。任务状态与持久化索引里只允许出现引用形态。
abstract final class ReplicationTaskGenerationSnapshot {
  // 4.3.1 及更早版本只认 1，读到其他取值会把任务按无效快照结算而不是误读
  static const int schemaVersion = 2;

  /// [focused] 为空时不写入聚焦段，执行端沿用旧快照的行为
  static Future<Map<String, dynamic>> encode(
    ImageParams params, {
    int? batchSize,
    QueuedFocusedInpaint? focused,
  }) async => _encode(params, batchSize: batchSize, focused: focused);

  /// 状态与索引只允许引用形态，写入前遇到待落盘快照直接拒绝。
  static void checkPersistable(Iterable<Map<String, dynamic>?> snapshots) {
    if (snapshots.any((snapshot) => snapshot != null && isPending(snapshot))) {
      throw StateError('Queue snapshot images must be stored before saving');
    }
  }

  static bool isPending(Map<String, dynamic> snapshot) =>
      SnapshotBlobSlots.values(
        snapshot,
      ).any((value) => value is PendingSnapshotBlob);

  /// 本版本认识的快照版本：1 的图片内联在索引里，2 的图片是引用。
  static const Set<int> knownSchemaVersions = {1, schemaVersion};

  static bool isKnownVersion(Map<String, dynamic> snapshot) =>
      knownSchemaVersions.contains(snapshot['schemaVersion']);

  /// 快照中所有形如 `{sha256, length}` 的引用的摘要，不限于本版本已知的槽位。
  static Iterable<String> blobDigests(Object? value) sync* {
    if (value is Map) {
      final ref = QueueBlobRef.tryParse(value);
      if (ref != null) {
        yield ref.sha256;
        return;
      }
      for (final child in value.values) {
        yield* blobDigests(child);
      }
    } else if (value is List) {
      for (final child in value) {
        yield* blobDigests(child);
      }
    }
  }

  /// 把待落盘快照的图片写入 [store] 并换成引用形态，其余快照原样返回。
  ///
  /// 同一份字节只哈希一次；调用方在快照进入状态后释放结果。
  static Future<InternedSnapshots> intern(
    List<Map<String, dynamic>?> snapshots,
    ReplicationQueueBlobStore store,
  ) async {
    final indexes = Map<Uint8List, int>.identity();
    final blobs = <Uint8List>[];
    for (final snapshot in snapshots) {
      if (snapshot == null) continue;
      for (final value in SnapshotBlobSlots.values(snapshot)) {
        if (value is PendingSnapshotBlob) {
          indexes.putIfAbsent(value.bytes, () {
            blobs.add(value.bytes);
            return blobs.length - 1;
          });
        }
      }
    }
    if (blobs.isEmpty) return InternedSnapshots(snapshots, null);
    final lease = await store.put(blobs);
    Object reference(Object value, String _) => value is PendingSnapshotBlob
        ? lease.refs[indexes[value.bytes]!].toJson()
        : value;
    return InternedSnapshots([
      for (final snapshot in snapshots)
        snapshot != null && isPending(snapshot)
            ? SnapshotBlobSlots.map(snapshot, reference)
            : snapshot,
    ], lease);
  }

  /// 复制任务用：引用同一组图片文件，不读写任何文件。
  static Map<String, dynamic> clone(Map<String, dynamic> snapshot) {
    _checkVersion(snapshot);
    return _deepCopy(snapshot) as Map<String, dynamic>;
  }

  /// 只改写提示词，图片槽位保持不变。
  static Map<String, dynamic> withTaskText(
    Map<String, dynamic> snapshot, {
    required String prompt,
    required String negativePrompt,
  }) {
    _checkVersion(snapshot);
    final ImageParams params;
    try {
      params = ImageParams.fromJson(
        Map<String, dynamic>.from(snapshot['params'] as Map),
      );
    } catch (error) {
      throw FormatException('Invalid queue generation snapshot', error);
    }
    return Map<String, dynamic>.of(snapshot)
      ..['params'] = params
          .copyWith(prompt: prompt, negativePrompt: negativePrompt)
          .toJson();
  }

  /// 读取引用的图片并按 [verify] 校验后还原请求参数；图片缺失或损坏时抛出 [FormatException] 子类。
  static Future<ImageParams> decode(
    Map<String, dynamic> snapshot,
    ReplicationQueueBlobStore store, {
    QueueBlobVerification verify = QueueBlobVerification.full,
  }) async {
    _checkVersion(snapshot);
    final refs = <QueueBlobRef>[
      for (final value in SnapshotBlobSlots.values(snapshot))
        if (value is! PendingSnapshotBlob) QueueBlobRef.parse(value),
    ];
    final bytes = await store.read(refs, verify: verify);
    final loaded = <QueueBlobRef, Uint8List>{
      for (var index = 0; index < refs.length; index++)
        refs[index]: bytes[index],
    };
    return _decodeChecked(
      SnapshotBlobSlots.map(
        snapshot,
        (value, _) => value is PendingSnapshotBlob
            ? value.bytes
            : loaded[QueueBlobRef.parse(value)]!,
      ),
    );
  }

  /// 只看索引给出摘要，不读图片文件，图片已被回收的已完成任务同样可用；
  /// `index_valid` 只说明索引结构，引用的图片要到估价或执行时才校验。
  static Map<String, dynamic> describe(Map<String, dynamic> snapshot) {
    try {
      _checkVersion(snapshot);
      for (final value in SnapshotBlobSlots.values(snapshot)) {
        if (value is! PendingSnapshotBlob) QueueBlobRef.parse(value);
      }
      final params = ImageParams.fromJson(
        Map<String, dynamic>.from(snapshot['params'] as Map),
      );
      int count(String key) =>
          snapshot[key] is List ? (snapshot[key] as List).length : 0;
      return {
        'schema_version': snapshot['schemaVersion'],
        'index_valid': true,
        'images_verified': false,
        'action': params.action.name,
        'model': params.model,
        'width': params.width,
        'height': params.height,
        'steps': params.effectiveSteps,
        'sampler': params.effectiveSampler,
        'scale': params.scale,
        'seed': params.seed,
        'has_source_image': snapshot[SnapshotBlobSlots.sourceImage] != null,
        'has_mask_image': snapshot[SnapshotBlobSlots.maskImage] != null,
        'vibe_reference_count': count(SnapshotBlobSlots.vibeReferences),
        'precise_reference_count': count(SnapshotBlobSlots.preciseReferences),
        'character_count': count('characters'),
      };
    } catch (error) {
      return {
        'schema_version': snapshot['schemaVersion'],
        'index_valid': false,
        'images_verified': false,
        'error': error is FormatException
            ? 'FormatException: ${error.message}'
            : 'FormatException: Invalid queue generation snapshot',
      };
    }
  }

  static void _checkVersion(Map<String, dynamic> snapshot) {
    if (snapshot['schemaVersion'] != schemaVersion ||
        snapshot['params'] is! Map) {
      throw const FormatException('Unsupported queue generation snapshot');
    }
  }

  static Object? _deepCopy(Object? value) => switch (value) {
    final Map<dynamic, dynamic> map => <String, dynamic>{
      for (final MapEntry(:key, :value) in map.entries)
        key as String: _deepCopy(value),
    },
    final List<dynamic> list => [for (final item in list) _deepCopy(item)],
    _ => value,
  };

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
      SnapshotBlobSlots.sourceImage: PendingSnapshotBlob(params.sourceImage!),
    if (params.maskImage != null)
      SnapshotBlobSlots.maskImage: PendingSnapshotBlob(params.maskImage!),
    SnapshotBlobSlots.vibeReferences: [
      for (final reference in params.vibeReferencesV4) _encodeVibe(reference),
    ],
    SnapshotBlobSlots.preciseReferences: [
      for (final reference in params.preciseReferences)
        {
          SnapshotBlobSlots.preciseImage: PendingSnapshotBlob(reference.image),
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

  // 编码文本按原文字节外置，读取时原样还原，不做 base64 转换
  static Map<String, dynamic> _encodeVibe(VibeReference reference) {
    final external = reference.vibeEncoding.isNotEmpty;
    return {
      'value': {
        ...reference.toJson(),
        if (external) vibeReferenceEncodingField: '',
      },
      if (reference.rawImageData != null)
        SnapshotBlobSlots.vibeRawImage: PendingSnapshotBlob(
          reference.rawImageData!,
        ),
      if (external)
        SnapshotBlobSlots.vibeEncoding: PendingSnapshotBlob(
          utf8.encode(reference.vibeEncoding),
        ),
    };
  }

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
      sourceImage: _bytes(snapshot[SnapshotBlobSlots.sourceImage]),
      maskImage: _bytes(snapshot[SnapshotBlobSlots.maskImage]),
      inpaintMaskClosingIterations:
          transient['inpaintMaskClosingIterations'] as int? ?? 0,
      inpaintMaskExpansionIterations:
          transient['inpaintMaskExpansionIterations'] as int? ?? 0,
      isOutpaint: transient['isOutpaint'] == true,
      vibeReferencesV4: [
        for (final item
            in snapshot[SnapshotBlobSlots.vibeReferences] as List? ?? const [])
          _decodeVibe(item),
      ],
      preciseReferences: [
        for (final item
            in snapshot[SnapshotBlobSlots.preciseReferences] as List? ??
                const [])
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
    final value = Map<String, dynamic>.from(item['value'] as Map);
    final encoding = _bytes(item[SnapshotBlobSlots.vibeEncoding]);
    if (encoding != null) {
      if (value[vibeReferenceEncodingField] != '') {
        throw const FormatException('Invalid queued Vibe reference');
      }
      value[vibeReferenceEncodingField] = utf8.decode(encoding);
    }
    return VibeReference.fromJson(
      value,
    ).copyWith(rawImageData: _bytes(item[SnapshotBlobSlots.vibeRawImage]));
  }

  static PreciseReference _decodePrecise(Object? item) {
    if (item is! Map ||
        item[SnapshotBlobSlots.preciseImage] == null ||
        item['type'] is! String) {
      throw const FormatException('Invalid queued precise reference');
    }
    final type = PreciseRefType.values
        .where((value) => value.name == item['type'])
        .firstOrNull;
    if (type == null) {
      throw const FormatException('Invalid queued precise reference type');
    }
    return PreciseReference(
      image: _bytes(item[SnapshotBlobSlots.preciseImage])!,
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

  static Uint8List? _bytes(Object? value) {
    if (value == null || value is Uint8List) return value as Uint8List?;
    throw const FormatException('Invalid image data');
  }
}
