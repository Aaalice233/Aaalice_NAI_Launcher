import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_preload_policy.dart';

void main() {
  group('online gallery preload window', () {
    test('starts pagination before reaching the end of the current page', () {
      expect(OnlineGalleryPreloadPolicy.loadAheadDistance(600), 900);
      expect(OnlineGalleryPreloadPolicy.loadAheadDistance(800), 1000);
    });

    test('keeps three quarters of a viewport built ahead', () {
      expect(OnlineGalleryPreloadPolicy.cacheExtent(800), 600);
      expect(OnlineGalleryPreloadPolicy.cacheExtent(-1), 0);
    });

    test('scales thumbnail lookahead for phone and desktop columns', () {
      expect(
        OnlineGalleryPreloadPolicy.lookaheadItemCount(
          viewportHeight: 800,
          itemWidth: 165,
          columnCount: 2,
        ),
        12,
      );
      expect(
        OnlineGalleryPreloadPolicy.lookaheadItemCount(
          viewportHeight: 900,
          itemWidth: 160,
          columnCount: 7,
        ),
        32,
      );
      expect(
        OnlineGalleryPreloadPolicy.lookaheadItemCount(
          viewportHeight: 0,
          itemWidth: 200,
          columnCount: 4,
        ),
        12,
      );
    });
  });
}
