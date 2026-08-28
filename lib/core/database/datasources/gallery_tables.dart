abstract final class GalleryTables {
  static const images = 'gallery_images';
  static const metadata = 'gallery_metadata';
  static const favorites = 'gallery_favorites';
  static const tags = 'gallery_tags';
  static const imageTags = 'gallery_image_tags';
  static const scanLogs = 'gallery_scan_logs';
  static const ftsIndex = 'gallery_fts_index';

  static const all = <String>{
    images,
    metadata,
    favorites,
    tags,
    imageTags,
    scanLogs,
    ftsIndex,
  };
}
