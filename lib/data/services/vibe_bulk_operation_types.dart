enum VibeBulkOperationType {
  delete,
  move,
  toggleFavorite,
  addTags,
  removeTags,
  export,
  import,
}

enum VibeBulkOperationErrorCode {
  entryNotFoundOrDeleteFailed,
  deleteFailed,
  entryNotFound,
  moveFailed,
  favoriteFailed,
  addTagsFailed,
  removeTagsFailed,
  exportNoFile,
  exportFailed,
  fileNotFound,
  noVibeData,
  importFailed,
  processFileFailed,
}

class VibeBulkOperationError {
  const VibeBulkOperationError(this.code, {this.itemName, this.details});

  final VibeBulkOperationErrorCode code;
  final String? itemName;
  final String? details;
}

class VibeBulkOperationResult {
  const VibeBulkOperationResult({
    required this.successCount,
    required this.failedCount,
    required this.errors,
    this.exportedFilePath,
  });

  factory VibeBulkOperationResult.success() => const VibeBulkOperationResult(
    successCount: 0,
    failedCount: 0,
    errors: [],
  );

  factory VibeBulkOperationResult.fromResult({
    required int success,
    required int failed,
    required List<VibeBulkOperationError> errors,
    String? exportedFilePath,
  }) => VibeBulkOperationResult(
    successCount: success,
    failedCount: failed,
    errors: errors,
    exportedFilePath: exportedFilePath,
  );

  final int successCount;
  final int failedCount;
  final List<VibeBulkOperationError> errors;
  final String? exportedFilePath;
  int get totalCount => successCount + failedCount;
  bool get isAllSuccess => failedCount == 0;
  bool get isAllFailed => successCount == 0;
  bool get hasErrors => errors.isNotEmpty;
}

typedef VibeBulkProgressCallback =
    void Function({
      required int current,
      required int total,
      required String currentItem,
      required VibeBulkOperationType operationType,
      required bool isComplete,
    });

class BulkOperationConfig {
  const BulkOperationConfig({
    required this.type,
    required this.entryIds,
    this.targetCategoryId,
    this.boolValue,
    this.tags,
  });

  factory BulkOperationConfig.delete(List<String> ids) =>
      BulkOperationConfig(type: VibeBulkOperationType.delete, entryIds: ids);
  factory BulkOperationConfig.move(
    List<String> ids, {
    required String? targetCategoryId,
  }) => BulkOperationConfig(
    type: VibeBulkOperationType.move,
    entryIds: ids,
    targetCategoryId: targetCategoryId,
  );
  factory BulkOperationConfig.toggleFavorite(
    List<String> ids, {
    required bool isFavorite,
  }) => BulkOperationConfig(
    type: VibeBulkOperationType.toggleFavorite,
    entryIds: ids,
    boolValue: isFavorite,
  );
  factory BulkOperationConfig.addTags(
    List<String> ids, {
    required List<String> tags,
  }) => BulkOperationConfig(
    type: VibeBulkOperationType.addTags,
    entryIds: ids,
    tags: tags,
  );
  factory BulkOperationConfig.removeTags(
    List<String> ids, {
    required List<String> tags,
  }) => BulkOperationConfig(
    type: VibeBulkOperationType.removeTags,
    entryIds: ids,
    tags: tags,
  );

  final VibeBulkOperationType type;
  final List<String> entryIds;
  final String? targetCategoryId;
  final bool? boolValue;
  final List<String>? tags;
}
