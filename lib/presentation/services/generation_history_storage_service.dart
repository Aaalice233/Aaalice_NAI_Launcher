import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/generation_history_box_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../../data/services/metadata/metadata_error_summary.dart';
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
/// PNG bytes of every older result. The order index is committed last; an
/// interrupted write can therefore leave only an orphan record, which is
/// removed during the next load without losing an indexed image.
class GenerationHistoryStorageService {
  GenerationHistoryStorageService({
    this.enabled = true,
    GenerationHistoryBoxStorage boxStorage =
        const GenerationHistoryBoxStorage(),
  }) : _boxStorage = boxStorage;

  static const _orderKey = 'generation_history_v1_order';
  static const _recordPrefix = 'generation_history_v1_record_';
  static const maxEntries = 50;

  final bool enabled;
  final GenerationHistoryBoxStorage _boxStorage;
  Future<void> _pendingWrite = Future<void>.value();

  bool get _canAccessBox => enabled && _boxStorage.isOpen;

  Future<List<GeneratedImage>> load() async {
    if (!_canAccessBox) return const [];

    final rawOrder = _boxStorage.read(_orderKey);
    final order = rawOrder is List
        ? rawOrder.whereType<String>().take(maxEntries).toList()
        : <String>[];
    final images = <GeneratedImage>[];
    final validIds = <String>[];

    for (final id in order) {
      try {
        final raw = _boxStorage.read('$_recordPrefix$id');
        if (raw is! Map) continue;
        final image = _decodeRecord(id, Map<dynamic, dynamic>.from(raw));
        if (image == null) continue;
        images.add(image);
        validIds.add(id);
      } catch (error, stackTrace) {
        AppLogger.w(
          'Skipping invalid persisted generation image $id: '
              '${metadataErrorSummary(error)}',
          'GenerationHistory',
        );
        AppLogger.d(stackTrace.toString(), 'GenerationHistory');
      }
    }

    final indexedKeys = validIds.map((id) => '$_recordPrefix$id').toSet();
    final staleKeys = _boxStorage
        .keysWithPrefix(_recordPrefix)
        .where((key) => !indexedKeys.contains(key))
        .toList();
    if (staleKeys.isNotEmpty || validIds.length != order.length) {
      await _boxStorage.put(_orderKey, validIds);
      await _boxStorage.deleteAll(staleKeys);
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
      if (!_canAccessBox) return;

      final previousOrder =
          (_boxStorage.read(_orderKey) as List?)?.whereType<String>().toSet() ??
          const <String>{};
      if (records.isNotEmpty) {
        await _boxStorage.putAll(records);
      }
      await _boxStorage.put(_orderKey, boundedOrder);

      final retained = boundedOrder.toSet();
      final evictedKeys = previousOrder
          .difference(retained)
          .map((id) => '$_recordPrefix$id')
          .toList();
      if (evictedKeys.isNotEmpty) {
        await _boxStorage.deleteAll(evictedKeys);
      }
    });
  }

  Future<void> clear() {
    return _enqueue(() async {
      if (!_canAccessBox) return;
      final recordKeys = _boxStorage.keysWithPrefix(_recordPrefix);
      await _boxStorage.delete(_orderKey);
      if (recordKeys.isNotEmpty) {
        await _boxStorage.deleteAll(recordKeys);
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
      fileNameSuffix: raw['fileNameSuffix'] as String? ?? '',
      filePath: raw['filePath'] as String?,
    );
  }
}
