enum VibeBulkOperationErrorCode { processFileFailed }

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
  });

  factory VibeBulkOperationResult.fromResult({
    required int success,
    required int failed,
    required List<VibeBulkOperationError> errors,
  }) => VibeBulkOperationResult(
    successCount: success,
    failedCount: failed,
    errors: errors,
  );

  final int successCount;
  final int failedCount;
  final List<VibeBulkOperationError> errors;
}
