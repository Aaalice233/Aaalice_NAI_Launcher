class VibeFolderSyncResult {
  const VibeFolderSyncResult({
    required this.scannedCount,
    required this.upsertedCount,
    required this.deletedCount,
    required this.errors,
  });

  final int scannedCount;
  final int upsertedCount;
  final int deletedCount;

  /// 每个失败的文件或条目一条。
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
