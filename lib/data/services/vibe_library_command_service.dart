import 'vibe_bulk_operation_types.dart';
import 'vibe_library_storage_service.dart';

/// Executes multi-entry library commands outside Riverpod state reduction.
class VibeLibraryCommandService {
  VibeLibraryCommandService(this._storage);

  final VibeLibraryStorageService _storage;

  Future<VibeBulkOperationResult> updateEncodingModel(
    Iterable<String> ids,
    String model,
  ) async {
    var successCount = 0;
    final errors = <VibeBulkOperationError>[];
    for (final id in ids) {
      try {
        if (await _storage.updateEntryEncodingModel(id, model) != null) {
          successCount++;
        } else {
          errors.add(VibeBulkOperationError(itemName: id));
        }
      } catch (error) {
        errors.add(
          VibeBulkOperationError(itemName: id, details: error.toString()),
        );
      }
    }
    return VibeBulkOperationResult(successCount: successCount, errors: errors);
  }
}
