import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../core/constants/storage_keys.dart';
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
      ),
    );

/// Durable backing store for the bounded generation history.
///
/// Records are stored independently so adding one result does not rewrite the
/// PNG bytes of every older result. The order index is committed last; an
/// interrupted write can therefore leave only an orphan record, which is
/// removed during the next load without losing an indexed image.
class GenerationHistoryStorageService {
  GenerationHistoryStorageService({this.enabled = true});

  static const _orderKey = 'generation_history_v1_order';
  static const _recordPrefix = 'generation_history_v1_record_';
  static const maxEntries = 50;

  final bool enabled;
  Future<void> _pendingWrite = Future<void>.value();

  Box<dynamic>? get _box {
    if (!enabled || !Hive.isBoxOpen(StorageKeys.historyBox)) {
      return null;
    }
    return Hive.box<dynamic>(StorageKeys.historyBox);
  }

  Future<List<GeneratedImage>> load() async {
    final box = _box;
    if (box == null) return const [];

    final rawOrder = box.get(_orderKey);
    final order = rawOrder is List
        ? rawOrder.whereType<String>().take(maxEntries).toList()
        : <String>[];
    final images = <GeneratedImage>[];
    final validIds = <String>[];

    for (final id in order) {
      try {
        final raw = box.get('$_recordPrefix$id');
        if (raw is! Map) continue;
        final image = _decodeRecord(id, Map<dynamic, dynamic>.from(raw));
        if (image == null) continue;
        images.add(image);
        validIds.add(id);
      } catch (error, stackTrace) {
        AppLogger.w(
          'Skipping invalid persisted generation image $id: $error',
          'GenerationHistory',
        );
        AppLogger.d(stackTrace.toString(), 'GenerationHistory');
      }
    }

    final indexedKeys = validIds.map((id) => '$_recordPrefix$id').toSet();
    final staleKeys = box.keys
        .whereType<String>()
        .where(
          (key) => key.startsWith(_recordPrefix) && !indexedKeys.contains(key),
        )
        .toList();
    if (staleKeys.isNotEmpty || validIds.length != order.length) {
      await box.put(_orderKey, validIds);
      await box.deleteAll(staleKeys);
    }

    return images;
  }

  Future<void> persistImages({
    required Iterable<GeneratedImage> changedImages,
    required List<String> order,
  }) {
    final records = <String, Map<String, dynamic>>{
      for (final image in changedImages)
        '$_recordPrefix${image.id}': _encodeRecord(image),
    };
    final boundedOrder = List<String>.unmodifiable(
      order.toSet().take(maxEntries),
    );

    return _enqueue(() async {
      final box = _box;
      if (box == null) return;

      final previousOrder =
          (box.get(_orderKey) as List?)?.whereType<String>().toSet() ??
          const <String>{};
      if (records.isNotEmpty) {
        await box.putAll(records);
      }
      await box.put(_orderKey, boundedOrder);

      final retained = boundedOrder.toSet();
      final evictedKeys = previousOrder
          .difference(retained)
          .map((id) => '$_recordPrefix$id')
          .toList();
      if (evictedKeys.isNotEmpty) {
        await box.deleteAll(evictedKeys);
      }
    });
  }

  Future<void> clear() {
    return _enqueue(() async {
      final box = _box;
      if (box == null) return;
      final recordKeys = box.keys
          .whereType<String>()
          .where((key) => key.startsWith(_recordPrefix))
          .toList();
      await box.delete(_orderKey);
      if (recordKeys.isNotEmpty) {
        await box.deleteAll(recordKeys);
      }
    });
  }

  Future<void> flush() => _pendingWrite;

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _pendingWrite.then((_) => operation());
    _pendingWrite = next.catchError((Object error, StackTrace stackTrace) {
      AppLogger.e('Failed to persist generation history', error, stackTrace);
    });
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

    NaiImageMetadata? metadata;
    final metadataJson = raw['metadata'];
    if (metadataJson is String && metadataJson.isNotEmpty) {
      final decoded = jsonDecode(metadataJson);
      if (decoded is Map<String, dynamic>) {
        metadata = NaiImageMetadata.fromJson(decoded);
      } else if (decoded is Map) {
        metadata = NaiImageMetadata.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    }

    FixedTagUsageSnapshot? fixedTagUsageSnapshot;
    final fixedTagUsageJson = raw['fixedTagUsageSnapshot'];
    if (fixedTagUsageJson is String && fixedTagUsageJson.isNotEmpty) {
      final decoded = jsonDecode(fixedTagUsageJson);
      if (decoded is Map) {
        fixedTagUsageSnapshot = FixedTagUsageSnapshot.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    }

    return GeneratedImage(
      id: id,
      bytes: bytes,
      width: width,
      height: height,
      createdAt: createdAt,
      kind: kind,
      metadata: metadata,
      fixedTagUsageSnapshot: fixedTagUsageSnapshot,
      preserveOriginalBytesOnSave:
          raw['preserveOriginalBytesOnSave'] as bool? ?? false,
      filePath: raw['filePath'] as String?,
    );
  }
}
