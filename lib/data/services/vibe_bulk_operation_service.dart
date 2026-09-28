import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/vibe/vibe_export_format.dart';
import '../models/vibe/vibe_library_entry.dart';
import 'vibe_bulk_entry_service.dart';
import 'vibe_bulk_export_service.dart';
import 'vibe_bulk_import_service.dart';
import 'vibe_bulk_operation_types.dart';
import 'vibe_export_service.dart';
import 'vibe_library_storage_service.dart';

export 'vibe_bulk_operation_types.dart';
export 'vibe_export_service.dart' show vibeExportServiceProvider;

part 'vibe_bulk_operation_service.g.dart';

/// Compatibility facade that dispatches each operation category to its
/// dedicated batch service.
class VibeBulkOperationService {
  VibeBulkOperationService({
    VibeLibraryStorageService? storageService,
    VibeExportService? exportService,
  }) : _storage = storageService ?? VibeLibraryStorageService(),
       _export = exportService ?? VibeExportService() {
    _entries = VibeBulkEntryService(_storage);
    _imports = VibeBulkImportService(_storage);
    _exports = VibeBulkExportService(_export);
  }

  final VibeLibraryStorageService _storage;
  final VibeExportService _export;
  late final VibeBulkEntryService _entries;
  late final VibeBulkImportService _imports;
  late final VibeBulkExportService _exports;

  Future<VibeBulkOperationResult> bulkDelete(
    List<String> ids, {
    VibeBulkProgressCallback? onProgress,
  }) => _entries.delete(ids, onProgress: onProgress);

  Future<VibeBulkOperationResult> bulkMoveToCategory(
    List<String> ids, {
    required String? targetCategoryId,
    VibeBulkProgressCallback? onProgress,
  }) => _entries.move(ids, targetCategoryId, onProgress: onProgress);

  Future<VibeBulkOperationResult> bulkToggleFavorite(
    List<String> ids, {
    required bool isFavorite,
    VibeBulkProgressCallback? onProgress,
  }) => _entries.setFavorite(ids, isFavorite, onProgress: onProgress);

  Future<VibeBulkOperationResult> bulkAddTags(
    List<String> ids, {
    required List<String> tags,
    VibeBulkProgressCallback? onProgress,
  }) => _entries.addTags(ids, tags, onProgress: onProgress);

  Future<VibeBulkOperationResult> bulkRemoveTags(
    List<String> ids, {
    required List<String> tags,
    VibeBulkProgressCallback? onProgress,
  }) => _entries.removeTags(ids, tags, onProgress: onProgress);

  Future<VibeBulkOperationResult> bulkExport(
    List<VibeLibraryEntry> entries, {
    required VibeExportOptions options,
    VibeBulkProgressCallback? onProgress,
  }) => _exports.export(entries, options: options, onProgress: onProgress);

  Future<VibeBulkOperationResult> bulkImport(
    List<String> paths, {
    String? targetCategoryId,
    List<String>? tags,
    VibeBulkProgressCallback? onProgress,
  }) => _imports.importPaths(
    paths,
    categoryId: targetCategoryId,
    tags: tags,
    onProgress: onProgress,
  );

  Future<VibeBulkOperationResult> bulkImportFromPlatformFiles(
    List<PlatformFile> files, {
    String? targetCategoryId,
    List<String>? tags,
    VibeBulkProgressCallback? onProgress,
  }) => _imports.importFiles(
    files,
    categoryId: targetCategoryId,
    tags: tags,
    onProgress: onProgress,
  );

  Future<List<VibeBulkOperationResult>> executeMultiple(
    List<BulkOperationConfig> operations, {
    void Function(int current, int total, VibeBulkOperationType type)?
    onOperationStart,
  }) async {
    final results = <VibeBulkOperationResult>[];
    for (var index = 0; index < operations.length; index++) {
      final config = operations[index];
      onOperationStart?.call(index, operations.length, config.type);
      results.add(await switch (config.type) {
        VibeBulkOperationType.delete => bulkDelete(config.entryIds),
        VibeBulkOperationType.move => bulkMoveToCategory(
          config.entryIds,
          targetCategoryId: config.targetCategoryId,
        ),
        VibeBulkOperationType.toggleFavorite => bulkToggleFavorite(
          config.entryIds,
          isFavorite: config.boolValue ?? true,
        ),
        VibeBulkOperationType.addTags => bulkAddTags(
          config.entryIds,
          tags: config.tags ?? const [],
        ),
        VibeBulkOperationType.removeTags => bulkRemoveTags(
          config.entryIds,
          tags: config.tags ?? const [],
        ),
        VibeBulkOperationType.export => throw UnsupportedError(
          'Use bulkExport for export operations',
        ),
        VibeBulkOperationType.import => throw UnsupportedError(
          'Use bulkImport for import operations',
        ),
      });
    }
    return results;
  }
}

@riverpod
VibeBulkOperationService vibeBulkOperationService(Ref ref) =>
    VibeBulkOperationService(
      storageService: ref.watch(vibeLibraryStorageServiceProvider),
      exportService: ref.watch(vibeExportServiceProvider),
    );
