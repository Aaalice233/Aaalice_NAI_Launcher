class VibeBulkOperationError {
  const VibeBulkOperationError({this.itemName, this.details});

  final String? itemName;
  final String? details;
}

class VibeBulkOperationResult {
  const VibeBulkOperationResult({
    required this.successCount,
    required this.errors,
  });

  final int successCount;
  final List<VibeBulkOperationError> errors;
}
