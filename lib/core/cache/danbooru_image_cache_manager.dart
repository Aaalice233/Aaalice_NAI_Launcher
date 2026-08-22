import 'online_gallery_image_cache_manager.dart';

export 'online_gallery_image_cache_manager.dart';

/// Compatibility alias. New code should import
/// `online_gallery_image_cache_manager.dart` directly.
@Deprecated('Use OnlineGalleryImageCacheManager instead')
typedef DanbooruImageCacheManager = OnlineGalleryImageCacheManager;

@Deprecated('All supported gallery images can be prefetched')
bool shouldPrefetchOnlineGalleryImage(String url) => true;
