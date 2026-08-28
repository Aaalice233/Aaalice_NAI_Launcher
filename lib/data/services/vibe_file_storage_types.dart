class VibeFolderSyncResult {
  const VibeFolderSyncResult({
    required this.scannedCount,
    required this.upsertedCount,
    required this.deletedCount,
    required this.failedCount,
    required this.errors,
  });

  final int scannedCount;
  final int upsertedCount;
  final int deletedCount;
  final int failedCount;
  final List<String> errors;
}

class VibeStoredImportParams {
  const VibeStoredImportParams({
    required this.strength,
    required this.infoExtracted,
  });

  final double strength;
  final double infoExtracted;
}
