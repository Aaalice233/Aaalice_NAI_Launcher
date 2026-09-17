/// 新图进入本地图库索引的结果。
enum GalleryIndexAdmission {
  /// 本次新写入索引。
  added,

  /// 已经在索引里：扫描器抢先收录或重复保存同一路径。
  alreadyIndexed,

  /// 图库本次会话尚未初始化，留给首次打开图库时的文件系统枚举收录。
  deferred,

  /// 文件不存在或写索引失败，索引与磁盘已经不一致。
  failed,
}

extension GalleryIndexAdmissionOutcome on GalleryIndexAdmission {
  /// 索引里确实有这张图，图库页面可以直接重取当前页。
  bool get isIndexed =>
      this == GalleryIndexAdmission.added ||
      this == GalleryIndexAdmission.alreadyIndexed;

  /// 只有索引与磁盘对不上才值得付全量扫盘的代价。
  bool get requiresFullRescan => this == GalleryIndexAdmission.failed;

  /// 批量结果取最坏的一项：失败 > 延后 > 新增 > 已存在。
  GalleryIndexAdmission merge(GalleryIndexAdmission other) {
    for (final severity in const [
      GalleryIndexAdmission.failed,
      GalleryIndexAdmission.deferred,
      GalleryIndexAdmission.added,
    ]) {
      if (this == severity || other == severity) return severity;
    }
    return GalleryIndexAdmission.alreadyIndexed;
  }
}
