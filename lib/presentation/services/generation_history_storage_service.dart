import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/generation_history_box_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../providers/generation/generation_models.dart';

/// Tests and embedders opt in explicitly so independently-created provider
/// containers cannot leak history into one another through a shared Hive box.
final generationSessionPersistenceEnabledProvider = Provider<bool>(
  (ref) => false,
);

final generationHistoryStorageServiceProvider =
    Provider<GenerationHistoryStorageService>(
      (ref) => GenerationHistoryStorageService(
        enabled: ref.watch(generationSessionPersistenceEnabledProvider),
        boxStorage: ref.watch(generationHistoryBoxStorageProvider),
      ),
    );

/// Durable backing store for the bounded generation history.
///
/// Records are stored independently so adding one result does not rewrite the
/// PNG bytes of every older result. A save writes the order after its records.
/// An unusable index is rebuilt from stored records before cleanup.
///
/// The box is lazy: restored images already hold their bytes, and a regular
/// box would read the whole file, dead frames included, into memory on open.
class GenerationHistoryStorageService {
  GenerationHistoryStorageService({
    this.enabled = true,
    GenerationHistoryBoxStorage boxStorage =
        const GenerationHistoryBoxStorage(),
  }) : _boxStorage = boxStorage;

  static const _orderKey = 'generation_history_v1_order';
  static const _recordPrefix = 'generation_history_v1_record_';
  static const _tag = 'GenerationHistory';
  static const maxEntries = 50;

  final bool enabled;
  final GenerationHistoryBoxStorage _boxStorage;
  Future<void> _pending = Future<void>.value();

  final Set<String> _knownIds = <String>{};
  final Set<List<String>> _pendingSaveOrders = {};

  bool get _canAccessBox => enabled && _boxStorage.isOpen;

  // Unindexed records can belong to an in-progress save.
  Future<List<GeneratedImage>> load() => _serialized(_load).then((images) {
    _knownIds.addAll(images.map((image) => image.id));
    return images;
  });

  Future<List<GeneratedImage>> _load() async {
    if (!_canAccessBox) return const [];

    final order = await _readOrRebuildOrder();
    final images = <GeneratedImage>[];

    for (final id in order.take(maxEntries)) {
      try {
        final raw = await _boxStorage.read('$_recordPrefix$id');
        if (raw is! Map) continue;
        final image = _decodeRecord(id, raw);
        if (image != null) images.add(image);
      } catch (_) {
        AppLogger.w('Skipping invalid persisted generation image', _tag);
      }
    }

    final indexedKeys = order.map((id) => '$_recordPrefix$id').toSet();
    final staleKeys = _boxStorage
        .keysWithPrefix(_recordPrefix)
        .where((key) => !indexedKeys.contains(key))
        .toList();
    if (staleKeys.isNotEmpty) {
      await _boxStorage.deleteAll(staleKeys);
    }

    return images;
  }

  Future<List<String>> _readOrRebuildOrder() async {
    final Object? raw;
    try {
      raw = await _boxStorage.read(_orderKey);
    } catch (_) {
      return _rebuildOrder(_boxStorage.keysWithPrefix(_recordPrefix));
    }
    if (raw is List) return raw.whereType<String>().toList(growable: false);
    final recordKeys = _boxStorage.keysWithPrefix(_recordPrefix);
    if (raw == null && recordKeys.isEmpty) return const [];
    return _rebuildOrder(recordKeys);
  }

  Future<List<String>> _rebuildOrder(List<String> recordKeys) async {
    final datedRecords = <({String id, DateTime createdAt})>[];
    final undatedIds = <String>[];
    for (final key in recordKeys) {
      final id = key.substring(_recordPrefix.length);
      final createdAt = await _readRecordCreatedAt(key);
      if (createdAt == null) {
        undatedIds.add(id);
      } else {
        datedRecords.add((id: id, createdAt: createdAt));
      }
    }
    datedRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final order = [for (final record in datedRecords) record.id, ...undatedIds];
    await _boxStorage.put(_orderKey, order);
    AppLogger.e('Invalid persisted generation history order', null, null, _tag);
    return order;
  }

  Future<DateTime?> _readRecordCreatedAt(String key) async {
    try {
      final raw = await _boxStorage.read(key);
      final createdAt = raw is Map ? raw['createdAt'] : null;
      return createdAt is String ? DateTime.tryParse(createdAt) : null;
    } catch (_) {
      AppLogger.w('Skipping unreadable generation history record date', _tag);
      return null;
    }
  }

  Future<void> persistImages({
    required Iterable<GeneratedImage> changedImages,
    required List<String> order,
  }) {
    final records = <String, Map<String, dynamic>>{
      for (final image in changedImages)
        '$_recordPrefix${image.id}': _encodeRecord(image),
    };
    final requestedOrder = List<String>.unmodifiable(order.toSet());
    // Capture what the caller could see before a queued restore finishes.
    final knownIdsAtSubmission = <String>{
      ..._knownIds,
      for (final pendingOrder in _pendingSaveOrders) ...pendingOrder,
    };
    _pendingSaveOrders.add(requestedOrder);

    return _enqueue(() async {
      if (!_canAccessBox) return;

      final previousOrder = await _readOrRebuildOrder();
      final boundedOrder = <String>{
        ...requestedOrder,
        ...previousOrder.where((id) => !knownIdsAtSubmission.contains(id)),
      }.take(maxEntries).toList(growable: false);
      if (records.isNotEmpty) {
        await _boxStorage.putAll(records);
      }
      await _boxStorage.put(_orderKey, boundedOrder);

      final retained = boundedOrder.toSet();
      _knownIds
        ..addAll(requestedOrder)
        ..retainAll(retained);
      final evictedKeys = previousOrder
          .toSet()
          .difference(retained)
          .map((id) => '$_recordPrefix$id')
          .toList();
      if (evictedKeys.isNotEmpty) {
        await _boxStorage.deleteAll(evictedKeys);
      }
    }).whenComplete(() {
      _pendingSaveOrders.remove(requestedOrder);
    });
  }

  Future<void> clear() => _enqueue(() async {
    if (!_canAccessBox) return;
    await _boxStorage.put(_orderKey, const <String>[]);
    _knownIds.clear();
    final recordKeys = _boxStorage.keysWithPrefix(_recordPrefix);
    if (recordKeys.isNotEmpty) await _boxStorage.deleteAll(recordKeys);
  });

  /// 用 [remap] 改写已保存记录里的 `filePath`，返回被改写的条数。
  ///
  /// 只更新路径发生变化的记录，不触碰其余记录的图片字节。
  Future<int> remapFilePaths(String Function(String filePath) remap) {
    var changed = 0;
    return _serialized(() async {
      if (!_canAccessBox) return;
      final updates = <String, Object?>{};
      for (final key in _boxStorage.keysWithPrefix(_recordPrefix)) {
        final raw = await _boxStorage.read(key);
        if (raw is! Map) continue;
        final filePath = raw['filePath'];
        if (filePath is! String || filePath.isEmpty) continue;
        final remapped = remap(filePath);
        if (remapped == filePath) continue;
        updates[key] = <dynamic, dynamic>{...raw, 'filePath': remapped};
      }
      if (updates.isNotEmpty) await _boxStorage.putAll(updates);
      changed = updates.length;
    }).then((_) => changed);
  }

  Future<void> flush() => _pending;

  Future<void> _enqueue(Future<void> Function() operation) => _serialized(
    operation,
    onError: (error, _) => AppLogger.e(
      'Failed to persist generation history (${error.runtimeType})',
      null,
      null,
      _tag,
    ),
  );

  Future<T> _serialized<T>(
    Future<T> Function() operation, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    final next = _pending.then((_) => operation());
    _pending = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        onError?.call(error, stackTrace);
      },
    );
    return next;
  }

  static Map<String, dynamic> _encodeRecord(GeneratedImage image) {
    return <String, dynamic>{
      'bytes': image.bytes,
      'width': image.width,
      'height': image.height,
      'createdAt': image.createdAt.toIso8601String(),
      'kind': image.kind.name,
      'metadata': image.metadata == null
          ? null
          : jsonEncode(image.metadata!.toJson()),
      'fixedTagUsageSnapshot': image.fixedTagUsageSnapshot == null
          ? null
          : jsonEncode(image.fixedTagUsageSnapshot!.toJson()),
      'preserveOriginalBytesOnSave': image.preserveOriginalBytesOnSave,
      'fileNameSuffix': image.fileNameSuffix,
      'filePath': image.filePath,
    };
  }

  static GeneratedImage? _decodeRecord(String id, Map<dynamic, dynamic> raw) {
    final rawBytes = raw['bytes'];
    final bytes = rawBytes is Uint8List
        ? rawBytes
        : rawBytes is List<int>
        ? Uint8List.fromList(rawBytes)
        : null;
    if (bytes == null || bytes.isEmpty) return null;

    final width = raw['width'];
    final height = raw['height'];
    if (width is! int || width <= 0 || height is! int || height <= 0) {
      return null;
    }

    final createdAt =
        DateTime.tryParse(raw['createdAt'] as String? ?? '') ?? DateTime.now();
    final kindName = raw['kind'] as String?;
    final kind = GeneratedImageKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => GeneratedImageKind.completed,
    );

    return GeneratedImage(
      id: id,
      bytes: bytes,
      width: width,
      height: height,
      createdAt: createdAt,
      kind: kind,
      metadata: _decodeOptionalJson(raw, 'metadata', NaiImageMetadata.fromJson),
      fixedTagUsageSnapshot: _decodeOptionalJson(
        raw,
        'fixedTagUsageSnapshot',
        FixedTagUsageSnapshot.fromJson,
      ),
      preserveOriginalBytesOnSave:
          raw['preserveOriginalBytesOnSave'] as bool? ?? false,
      fileNameSuffix: raw['fileNameSuffix'] as String? ?? '',
      filePath: raw['filePath'] as String?,
    );
  }

  static T? _decodeOptionalJson<T>(
    Map<dynamic, dynamic> raw,
    String field,
    T Function(Map<String, dynamic>) decode,
  ) {
    final value = raw[field];
    if (value is! String || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decode(decoded) : null;
    } catch (_) {
      AppLogger.w('Invalid optional generation history field $field', _tag);
      return null;
    }
  }
}
