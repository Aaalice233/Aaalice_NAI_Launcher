import '../../models/online_gallery/gallery_source.dart';
import '../danbooru_auth_service.dart';
import '../gelbooru_auth_service.dart';

class OnlineGalleryAuthScopeCoordinator {
  const OnlineGalleryAuthScopeCoordinator();

  String danbooruScope(DanbooruAuthState auth) {
    final identity = auth.user?.name ?? auth.credentials?.username;
    if (identity == null) return 'anonymous';
    final status = auth.isLoggedIn ? 'authenticated' : 'pending';
    return '$identity:${auth.user?.level ?? 0}:$status';
  }

  String gelbooruScope(GelbooruAuthState auth) {
    final userId = auth.credentials?.userId;
    return '${userId ?? 'anonymous'}:${auth.status.name}';
  }

  bool ownsAuthenticatedCache(String key, GallerySourceId sourceId) {
    return key.startsWith('search:${sourceId.key}:') ||
        key.startsWith('popular:${sourceId.key}:') ||
        key.startsWith('favorites:${sourceId.key}|');
  }

  bool canLoadRemoteFavorites({
    required GallerySourceId sourceId,
    required DanbooruAuthState danbooru,
    required GelbooruAuthState gelbooru,
  }) {
    if (gallerySourceCapabilities[sourceId]!.remoteFavorites ==
        GalleryRemoteFavoritesCapability.none) {
      return false;
    }
    return switch (sourceId) {
      GallerySourceId.danbooru => danbooru.isLoggedIn && danbooru.user != null,
      GallerySourceId.gelbooru =>
        gelbooru.isAuthenticated && gelbooru.credentials != null,
      _ => false,
    };
  }
}
