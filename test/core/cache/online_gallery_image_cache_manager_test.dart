import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_image_cache_manager.dart';

void main() {
  group('onlineGalleryImageHeadersForUrl', () {
    test('adds required Gelbooru request headers', () {
      final headers = onlineGalleryImageHeadersForUrl(
        'https://img4.gelbooru.com/thumbnails/51/d1/thumbnail_image.jpg',
      );

      expect(headers['Referer'], 'https://gelbooru.com/');
      expect(headers['Accept'], contains('image/'));
      expect(headers['User-Agent'], contains('Mozilla/5.0'));
      expect(headers['Cookie'], 'fringeBenefits=yup');
    });

    test('does not add Gelbooru headers for other or invalid URLs', () {
      expect(
        onlineGalleryImageHeadersForUrl(
          'https://cdn.donmai.us/sample/test.jpg',
        ),
        isEmpty,
      );
      expect(onlineGalleryImageHeadersForUrl('not a url'), isEmpty);
    });
  });

  group('onlineGalleryImageCacheKeyForUrl', () {
    test('uses a versioned key for Gelbooru media', () {
      const url =
          'https://img4.gelbooru.com/thumbnails/51/d1/thumbnail_image.jpg';

      final key = onlineGalleryImageCacheKeyForUrl(url);

      expect(key, contains('gelbooru-image-v2'));
      expect(key, contains(url));
    });

    test('keeps the default cache key for other sites', () {
      expect(
        onlineGalleryImageCacheKeyForUrl(
          'https://cdn.donmai.us/sample/test.jpg',
        ),
        isNull,
      );
      expect(onlineGalleryImageCacheKeyForUrl('not a url'), isNull);
    });
  });

  test('keeps the existing shared disk cache key', () {
    expect(OnlineGalleryImageCacheManager.key, 'danbooruImageCache');
  });
}
