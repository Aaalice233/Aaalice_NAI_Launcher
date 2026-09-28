export 'gallery_item.dart';
export 'gallery_source.dart';

import 'gallery_item.dart';

/// Backward-compatible name for callers outside the online gallery module.
/// New gallery code should use [GalleryItem].
typedef DanbooruPost = GalleryItem;
