import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_scan_progress_panel.dart';

void main() {
  group('gallery progress segment layout', () {
    test('keeps a one-file segment valid in a large gallery', () {
      expect(galleryProgressSegmentFlex(1 / 3590), 1);
    });

    test('rejects ratios that cannot produce a visible segment', () {
      expect(galleryProgressSegmentFlex(0), 0);
      expect(galleryProgressSegmentFlex(-1), 0);
      expect(galleryProgressSegmentFlex(double.nan), 0);
      expect(galleryProgressSegmentFlex(double.infinity), 0);
    });
  });

  group('gallery progress stripe bounds', () {
    test('does no paint work for invalid dimensions', () {
      expect(galleryProgressStripeCountForWidth(0), 0);
      expect(galleryProgressStripeCountForWidth(-1), 0);
      expect(galleryProgressStripeCountForWidth(double.nan), 0);
      expect(galleryProgressStripeCountForWidth(double.infinity), 0);
    });

    test('keeps finite dimensions bounded', () {
      expect(galleryProgressStripeCountForWidth(320), 21);
      expect(galleryProgressStripeCountForWidth(double.maxFinite), 4096);
    });
  });
}
