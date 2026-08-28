import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:nai_launcher/data/services/gelbooru_auth_service.dart';
import 'package:nai_launcher/data/services/online_gallery/online_gallery_auth_scope_coordinator.dart';

void main() {
  const coordinator = OnlineGalleryAuthScopeCoordinator();

  test(
    'anonymous scopes are stable and source-specific caches are identified',
    () {
      expect(coordinator.danbooruScope(const DanbooruAuthState()), 'anonymous');
      expect(
        coordinator.gelbooruScope(
          const GelbooruAuthState(status: GelbooruAuthStatus.unconfigured),
        ),
        'anonymous:unconfigured',
      );
      expect(
        coordinator.ownsAuthenticatedCache(
          'search:danbooru:cat|auth:alice',
          GallerySourceId.danbooru,
        ),
        isTrue,
      );
      expect(
        coordinator.ownsAuthenticatedCache(
          'search:gelbooru:cat|auth:12',
          GallerySourceId.danbooru,
        ),
        isFalse,
      );
    },
  );

  test('public-only sources never load remote favorites', () {
    expect(
      coordinator.canLoadRemoteFavorites(
        sourceId: GallerySourceId.aiTag,
        danbooru: const DanbooruAuthState(),
        gelbooru: const GelbooruAuthState(
          status: GelbooruAuthStatus.unconfigured,
        ),
      ),
      isFalse,
    );
  });
}
