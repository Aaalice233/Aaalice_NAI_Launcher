import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'vibe_bulk_operation_types.dart';
import 'vibe_import_service.dart';
import 'vibe_library_import_repository_impl.dart';
import 'vibe_library_storage_service.dart';

/// Executes file-based batch imports through the canonical import pipeline.
class VibeBulkImportService {
  VibeBulkImportService(VibeLibraryStorageService storage)
    : _import = VibeImportService(
        repository: VibeLibraryStorageImportRepository(storage),
      );

  final VibeImportService _import;

  Future<VibeBulkOperationResult> importPaths(
    List<String> paths, {
    String? categoryId,
    List<String>? tags,
    VibeBulkProgressCallback? onProgress,
  }) => importFiles(
    [
      for (final path in paths)
        PlatformFile(
          name: p.basename(path),
          path: path,
          size: File(path).existsSync() ? File(path).lengthSync() : 0,
        ),
    ],
    categoryId: categoryId,
    tags: tags,
    onProgress: onProgress,
  );

  Future<VibeBulkOperationResult> importFiles(
    List<PlatformFile> files, {
    String? categoryId,
    List<String>? tags,
    VibeBulkProgressCallback? onProgress,
  }) async {
    var innerCompleted = false;
    final result = await _import.importFromFile(
      files: files,
      categoryId: categoryId,
      tags: tags,
      onProgress: (current, total, message) {
        final isComplete = current == total;
        innerCompleted = innerCompleted || isComplete;
        onProgress?.call(
          current: current,
          total: total,
          currentItem: message,
          operationType: VibeBulkOperationType.import,
          isComplete: isComplete,
        );
      },
    );
    if (!innerCompleted) {
      onProgress?.call(
        current: result.totalCount,
        total: result.totalCount,
        currentItem: '',
        operationType: VibeBulkOperationType.import,
        isComplete: true,
      );
    }
    return VibeBulkOperationResult.fromResult(
      success: result.successCount,
      failed: result.failCount,
      errors: [
        for (final error in result.errors)
          VibeBulkOperationError(
            VibeBulkOperationErrorCode.importFailed,
            itemName: error.source,
            details: error.details?.toString() ?? error.error,
          ),
      ],
    );
  }
}
