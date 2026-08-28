import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/online_gallery/online_gallery_load_coordinator.dart';

void main() {
  test('a newer request cancels and invalidates the previous generation', () {
    final coordinator = OnlineGalleryLoadCoordinator();
    final first = coordinator.begin(cacheKey: 'search:a');
    final second = coordinator.begin(cacheKey: 'search:b');

    expect(first.cancelToken.isCancelled, isTrue);
    expect(coordinator.isCurrent(first, cacheKey: 'search:a'), isFalse);
    expect(coordinator.isCurrent(second, cacheKey: 'search:b'), isTrue);
    expect(coordinator.isCurrent(second, cacheKey: 'search:a'), isFalse);
  });

  test('explicit cancellation makes late responses stale', () {
    final coordinator = OnlineGalleryLoadCoordinator();
    final request = coordinator.begin(cacheKey: 'favorites:danbooru');

    coordinator.cancel('scope changed');

    expect(request.cancelToken.isCancelled, isTrue);
    expect(coordinator.isCurrent(request), isFalse);
    expect(coordinator.activeCancelToken, isNull);
  });
}
