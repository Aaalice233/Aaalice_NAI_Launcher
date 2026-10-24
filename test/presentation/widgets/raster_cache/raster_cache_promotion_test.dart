import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/raster_cache/raster_cache_promotion.dart';

void main() {
  test('backs off when a snapshot is evicted before paying off', () {
    final policy = RasterCachePromotionPolicy(
      baseStableFrames: 4,
      maxStableFrames: 16,
    );

    policy.recordEviction(displayedFrames: 1);
    expect(policy.stableFramesRequired, 8);
    policy.recordEviction(displayedFrames: 2);
    expect(policy.stableFramesRequired, 16);
    policy.recordEviction(displayedFrames: 0);
    expect(policy.stableFramesRequired, 16);
  });

  test('keeps the threshold for snapshots that lived long enough', () {
    final policy = RasterCachePromotionPolicy(baseStableFrames: 4)
      ..recordEviction(displayedFrames: 1);

    policy.recordEviction(displayedFrames: 20);

    expect(policy.stableFramesRequired, 8);
  });

  test('returns to the base threshold after a proven snapshot', () {
    final policy = RasterCachePromotionPolicy(
      baseStableFrames: 4,
      provenDisplayedFrames: 100,
    )..recordRejectedAttempt();
    expect(policy.stableFramesRequired, 8);

    policy.recordEviction(displayedFrames: 100);

    expect(policy.stableFramesRequired, 4);
  });
}
