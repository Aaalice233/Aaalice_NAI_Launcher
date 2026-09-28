import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel.dart';

void main() {
  group('resolveHistoryPreviewAspectRatio', () {
    test('preserves extreme aspect ratios without clamping', () {
      expect(resolveHistoryPreviewAspectRatio(4.8), equals(4.8));
      expect(resolveHistoryPreviewAspectRatio(0.18), equals(0.18));
    });

    test('falls back when aspect ratio is invalid', () {
      expect(
        resolveHistoryPreviewAspectRatio(double.nan, fallback: 1.5),
        equals(1.5),
      );
      expect(resolveHistoryPreviewAspectRatio(0, fallback: 0.75), equals(0.75));
    });
  });

  group('resolveCurrentHistoryPreviewAspectRatio', () {
    test(
      'uses the completed image ratio instead of the previous batch ratio',
      () {
        expect(
          resolveCurrentHistoryPreviewAspectRatio(
            832 / 1216,
            completedImageAspectRatio: 1536 / 1024,
          ),
          equals(1.5),
        );
      },
    );

    test('uses the batch ratio for an unfinished stream slot', () {
      expect(
        resolveCurrentHistoryPreviewAspectRatio(832 / 1216),
        equals(832 / 1216),
      );
    });

    test('falls back to the batch ratio for an invalid image ratio', () {
      expect(
        resolveCurrentHistoryPreviewAspectRatio(
          832 / 1216,
          completedImageAspectRatio: double.nan,
        ),
        equals(832 / 1216),
      );
    });
  });
}
