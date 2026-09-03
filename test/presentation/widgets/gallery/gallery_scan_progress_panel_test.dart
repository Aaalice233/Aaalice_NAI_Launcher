import 'package:flutter/material.dart';
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
      expect(galleryProgressSegmentFlex(double.negativeInfinity), 0);
    });
  });

  group('gallery progress stripes animation', () {
    Widget buildSubject({required bool disableAnimations}) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: SizedBox(
          width: 320,
          height: 8,
          child: buildGalleryAnimatedStripesForTesting(),
        ),
      );
    }

    double progressOf(WidgetTester tester) {
      final painter = tester
          .widget<CustomPaint>(find.byType(CustomPaint))
          .painter;
      return ((painter as dynamic).progress as Animation<double>).value;
    }

    testWidgets('uses a stable terminal frame when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(disableAnimations: true));

      expect(progressOf(tester), 1);
      await tester.pumpAndSettle();
      expect(progressOf(tester), 1);
    });

    testWidgets('keeps animating when animations are enabled', (tester) async {
      await tester.pumpWidget(buildSubject(disableAnimations: false));
      final initialProgress = progressOf(tester);

      await tester.pump(const Duration(milliseconds: 250));

      expect(progressOf(tester), isNot(initialProgress));
    });
  });

  group('gallery progress stripe bounds', () {
    test('does no paint work for invalid widths', () {
      expect(galleryProgressStripeCountForWidth(0), 0);
      expect(galleryProgressStripeCountForWidth(-1), 0);
      expect(galleryProgressStripeCountForWidth(double.nan), 0);
      expect(galleryProgressStripeCountForWidth(double.infinity), 0);
    });

    test('rejects non-finite and non-positive canvas sizes', () {
      expect(
        galleryProgressStripeCountForSize(const Size(double.infinity, 8)),
        0,
      );
      expect(
        galleryProgressStripeCountForSize(const Size(320, double.infinity)),
        0,
      );
      expect(galleryProgressStripeCountForSize(const Size(double.nan, 8)), 0);
      expect(galleryProgressStripeCountForSize(const Size(320, double.nan)), 0);
      expect(galleryProgressStripeCountForSize(const Size(0, 8)), 0);
      expect(galleryProgressStripeCountForSize(const Size(320, 0)), 0);
      expect(galleryProgressStripeCountForSize(const Size(-1, 8)), 0);
      expect(galleryProgressStripeCountForSize(const Size(320, -1)), 0);
    });

    test('keeps normal and huge canvases bounded', () {
      expect(galleryProgressStripeCountForSize(const Size(320, 8)), 21);
      expect(
        galleryProgressStripeCountForSize(const Size(double.maxFinite, 8)),
        4096,
      );
    });
  });
}
