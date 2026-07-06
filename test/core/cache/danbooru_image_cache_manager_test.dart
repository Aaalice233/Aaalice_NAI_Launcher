import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/danbooru_image_cache_manager.dart';

void main() {
  group('onlineGalleryImageHeadersForUrl', () {
    test('adds browser image headers for Gelbooru CDN images', () {
      final headers = onlineGalleryImageHeadersForUrl(
        'https://img4.gelbooru.com/thumbnails/51/d1/thumbnail_image.jpg',
      );

      expect(headers['Referer'], 'https://gelbooru.com/');
      expect(headers['Accept'], contains('image/'));
      expect(headers['User-Agent'], contains('Mozilla/5.0'));
    });

    test('adds browser image headers for Gelbooru origin images', () {
      final headers = onlineGalleryImageHeadersForUrl(
        'https://gelbooru.com/images/51/d1/source.jpg',
      );

      expect(headers['Referer'], 'https://gelbooru.com/');
      expect(headers['Accept'], contains('image/'));
      expect(headers['User-Agent'], contains('Mozilla/5.0'));
    });

    test('adds the Gelbooru fringe benefits cookie for Gelbooru requests', () {
      final headers = onlineGalleryImageHeadersForUrl(
        'https://gelbooru.com/index.php',
      );

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

      expect(key, isNotNull);
      expect(key, isNot(url));
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
}
