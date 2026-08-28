import '../models/vibe/vibe_export_format.dart';
import '../models/vibe/vibe_library_entry.dart';
import 'vibe_bulk_operation_types.dart';
import 'vibe_export_service.dart';

/// Adapts format-specific export operations to the shared bulk result contract.
class VibeBulkExportService {
  VibeBulkExportService(this._export);

  final VibeExportService _export;

  Future<VibeBulkOperationResult> export(
    List<VibeLibraryEntry> entries, {
    required VibeExportOptions options,
    VibeBulkProgressCallback? onProgress,
  }) async {
    try {
      void progress({
        required int current,
        required int total,
        required String currentItem,
      }) => onProgress?.call(
        current: current,
        total: total,
        currentItem: currentItem,
        operationType: VibeBulkOperationType.export,
        isComplete: false,
      );
      final path = switch (options.format) {
        VibeExportFormat.bundle => await _export.exportAsBundle(
          entries,
          options: options,
          onProgress: progress,
        ),
        VibeExportFormat.embeddedImage =>
          entries.isEmpty
              ? null
              : await _export.exportAsEmbeddedImage(
                  entries.first,
                  options: options,
                ),
        VibeExportFormat.encoding => await _export.exportAsEncoding(
          entries,
          options: options,
          onProgress: progress,
        ),
      };
      onProgress?.call(
        current: entries.length,
        total: entries.length,
        currentItem: '',
        operationType: VibeBulkOperationType.export,
        isComplete: true,
      );
      return VibeBulkOperationResult.fromResult(
        success: path == null ? 0 : entries.length,
        failed: path == null ? entries.length : 0,
        errors: path == null
            ? const [
                VibeBulkOperationError(VibeBulkOperationErrorCode.exportNoFile),
              ]
            : const [],
        exportedFilePath: path,
      );
    } catch (error) {
      return VibeBulkOperationResult.fromResult(
        success: 0,
        failed: entries.length,
        errors: [
          VibeBulkOperationError(
            VibeBulkOperationErrorCode.exportFailed,
            details: error.toString(),
          ),
        ],
      );
    }
  }
}
