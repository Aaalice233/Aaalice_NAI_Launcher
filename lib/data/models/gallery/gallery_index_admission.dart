/// 新图进入本地图库索引的结果。
enum GalleryIndexAdmission {
  /// 本次新写入索引。
  added,

  /// 已经在索引里：扫描器抢先收录或重复保存同一路径。
  alreadyIndexed,

  /// 底层图库服务尚未就绪，路径已登记，等服务就绪后补收录。
  deferred,

  /// 文件不存在，或单张重试后仍写不进索引；图库要等下次扫描才会出现这张图。
  failed,
}

extension GalleryIndexAdmissionOutcome on GalleryIndexAdmission {
  /// 索引里确实有这张图，图库页面可以直接重取当前页。
  bool get isIndexed =>
      this == GalleryIndexAdmission.added ||
      this == GalleryIndexAdmission.alreadyIndexed;

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
