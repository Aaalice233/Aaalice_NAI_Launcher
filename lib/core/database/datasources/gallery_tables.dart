abstract final class GalleryTables {
  static const images = 'gallery_images';
  static const metadata = 'gallery_metadata';
  static const favorites = 'gallery_favorites';
  static const tags = 'gallery_tags';
  static const imageTags = 'gallery_image_tags';
  static const scanLogs = 'gallery_scan_logs';
  static const ftsIndex = 'gallery_prompt_fts';
  static const albums = 'gallery_albums';

  // 旧版全文索引按 UNINDEXED 的 image_id 定位，覆盖一行要扫全表
  static const legacyFtsIndex = 'gallery_fts_index';

  // 存在即表示全文索引尚未从元数据回填完，记录下一批的起点
  static const ftsRebuild = 'gallery_fts_rebuild';
  static const albumImages = 'gallery_album_images';

  static const all = <String>{
    images,
    metadata,
    favorites,
    tags,
    imageTags,
    scanLogs,
    ftsIndex,
    albums,
    albumImages,
  };
}
