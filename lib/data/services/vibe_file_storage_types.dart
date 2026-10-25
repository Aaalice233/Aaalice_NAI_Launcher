class VibeFolderSyncResult {
  const VibeFolderSyncResult({
    required this.scannedCount,
    required this.upsertedCount,
    required this.deletedCount,
    required this.errors,
    this.unchangedCount = 0,
  });

  final int scannedCount;

  /// 实际写入的条目数；与已存条目完全相同的文件计入 [unchangedCount]。
  final int upsertedCount;
  final int unchangedCount;
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
