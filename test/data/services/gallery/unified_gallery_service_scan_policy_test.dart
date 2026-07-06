import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/gallery/unified_gallery_service.dart';

void main() {
  group('LocalGalleryService scan policy', () {
    test('skips startup scan when database and file system counts match', () {
      expect(
        chooseStartupIndexAction(
          databaseImageCount: 43568,
          fileSystemImageCount: 43568,
        ),
        GalleryStartupIndexAction.none,
      );
    });

    test('runs startup scan when database has not indexed the gallery', () {
      expect(
        chooseStartupIndexAction(
          databaseImageCount: 0,
          fileSystemImageCount: 17,
        ),
        GalleryStartupIndexAction.fullScan,
      );
    });

    test('runs startup scan when file system count changed', () {
      expect(
        chooseStartupIndexAction(
          databaseImageCount: 16,
          fileSystemImageCount: 17,
        ),
        GalleryStartupIndexAction.fullScan,
      );
    });

    test('does not start another scan during background scanning refresh', () {
      expect(
        shouldRunRefreshIndexScan(
          scanRequested: true,
          isBackgroundScanning: true,
        ),
        isFalse,
      );
    });

    test(
      'allows metadata scan for explicit refresh when no scan is active',
      () {
        expect(
          shouldRunRefreshIndexScan(
            scanRequested: true,
            isBackgroundScanning: false,
          ),
          isTrue,
        );
      },
    );
  });
}
