import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_image_request.dart';
import 'package:nai_launcher/core/cache/online_gallery_prefetch_coordinator.dart';

GalleryImageRequest _request(
  int id, {
  GalleryImageTier tier = GalleryImageTier.thumbnail,
}) => GalleryImageRequest(
  sourceId: 'danbooru',
  url: 'https://example.com/$id.jpg',
  tier: tier,
  targetDecodeWidth: 320,
);

void main() {
  test('limits active preloads to four', () async {
    var active = 0;
    var maxActive = 0;
    final gates = <Completer<void>>[];
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (_) {
        active++;
        if (active > maxActive) maxActive = active;
        final gate = Completer<void>();
        gates.add(gate);
        return gate.future.whenComplete(() => active--);
      },
    );

    final futures = [
      for (var index = 0; index < 6; index++)
        coordinator.submit(
          _request(index),
          priority: GalleryImagePriority.lookahead,
        ),
    ];
    expect(coordinator.activeCount, 4);
    expect(maxActive, 4);

    for (var index = 0; index < gates.length; index++) {
      if (!gates[index].isCompleted) gates[index].complete();
      await Future<void>.delayed(Duration.zero);
    }
    while (gates.any((gate) => !gate.isCompleted)) {
      for (final gate in gates.where((gate) => !gate.isCompleted).toList()) {
        gate.complete();
      }
      await Future<void>.delayed(Duration.zero);
    }
    expect(await Future.wait(futures), everyElement(isTrue));
    expect(maxActive, 4);
  });

  test('hover work overtakes queued lookahead work', () async {
    final started = <String>[];
    final gates = <Completer<void>>[];
    final coordinator = OnlineGalleryPrefetchCoordinator(
      maxConcurrent: 1,
      preloader: (request) {
        started.add(request.url);
        final gate = Completer<void>();
        gates.add(gate);
        return gate.future;
      },
    );

    final first = coordinator.submit(
      _request(0),
      priority: GalleryImagePriority.lookahead,
    );
    final low = coordinator.submit(
      _request(1),
      priority: GalleryImagePriority.lookahead,
    );
    final hover = coordinator.submit(
      _request(2, tier: GalleryImageTier.sample),
      priority: GalleryImagePriority.hover,
    );

    gates[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, ['https://example.com/0.jpg', 'https://example.com/2.jpg']);
    gates[1].complete();
    await Future<void>.delayed(Duration.zero);
    gates[2].complete();

    expect(await first, isTrue);
    expect(await hover, isTrue);
    expect(await low, isTrue);
  });

  test(
    'deduplicates identical requests and upgrades pending priority',
    () async {
      final gate = Completer<void>();
      final coordinator = OnlineGalleryPrefetchCoordinator(
        maxConcurrent: 1,
        preloader: (_) => gate.future,
      );
      final request = _request(1, tier: GalleryImageTier.sample);

      final first = coordinator.submit(
        request,
        priority: GalleryImagePriority.lookahead,
      );
      final duplicate = coordinator.submit(
        request,
        priority: GalleryImagePriority.hover,
      );

      expect(identical(first, duplicate), isTrue);
      expect(coordinator.debugRequestCount, 1);
      expect(coordinator.debugDeduplicatedCount, 1);
      gate.complete();
      expect(await duplicate, isTrue);
    },
  );

  test(
    'generation rotation rejects old queued and in-flight results',
    () async {
      final gate = Completer<void>();
      final coordinator = OnlineGalleryPrefetchCoordinator(
        maxConcurrent: 1,
        preloader: (_) => gate.future,
      );
      final running = coordinator.submit(
        _request(1),
        priority: GalleryImagePriority.visible,
      );
      final queued = coordinator.submit(
        _request(2),
        priority: GalleryImagePriority.visible,
      );

      coordinator.rotateGeneration();
      expect(await queued, isFalse);
      gate.complete();
      expect(await running, isFalse);
    },
  );

  test(
    'scrolling pauses low priority work but still starts hover work',
    () async {
      final started = <String>[];
      final coordinator = OnlineGalleryPrefetchCoordinator(
        preloader: (request) async => started.add(request.url),
      );
      coordinator.setScrolling(true);

      final low = coordinator.submit(
        _request(1),
        priority: GalleryImagePriority.lookahead,
      );
      final hover = coordinator.submit(
        _request(2, tier: GalleryImageTier.sample),
        priority: GalleryImagePriority.hover,
      );
      await Future<void>.delayed(Duration.zero);

      expect(started, ['https://example.com/2.jpg']);
      expect(await hover, isTrue);
      coordinator.setScrolling(false);
      expect(await low, isTrue);
    },
  );

  test(
    'completed sample LRU retains only the latest sixteen requests',
    () async {
      final coordinator = OnlineGalleryPrefetchCoordinator(
        preloader: (_) async {},
      );

      for (var index = 0; index < 17; index++) {
        await coordinator.submit(
          _request(index, tier: GalleryImageTier.sample),
          priority: GalleryImagePriority.hover,
        );
      }

      expect(
        coordinator.isSampleReady(_request(0, tier: GalleryImageTier.sample)),
        isFalse,
      );
      expect(
        coordinator.isSampleReady(_request(16, tier: GalleryImageTier.sample)),
        isTrue,
      );
    },
  );

  test('new generation can reuse an old in-flight disk download', () async {
    final gates = <Completer<void>>[];
    var starts = 0;
    final request = _request(1);
    final coordinator = OnlineGalleryPrefetchCoordinator(
      maxConcurrent: 1,
      preloader: (_) {
        starts++;
        final gate = Completer<void>();
        gates.add(gate);
        return gate.future;
      },
    );

    final old = coordinator.submit(
      request,
      priority: GalleryImagePriority.visible,
    );
    coordinator.rotateGeneration();
    final current = coordinator.submit(
      request,
      priority: GalleryImagePriority.visible,
    );
    gates.first.complete();
    expect(await old, isFalse);
    expect(await current, isTrue);
    expect(starts, 1);
  });

  test(
    'negative cache lasts 15 seconds and explicit retry clears it',
    () async {
      var now = DateTime(2026);
      var attempts = 0;
      final request = _request(1, tier: GalleryImageTier.sample);
      final coordinator = OnlineGalleryPrefetchCoordinator(
        now: () => now,
        preloader: (_) async {
          attempts++;
          throw StateError('failed');
        },
      );

      expect(
        await coordinator.submit(request, priority: GalleryImagePriority.hover),
        isFalse,
      );
      expect(
        await coordinator.submit(request, priority: GalleryImagePriority.hover),
        isFalse,
      );
      expect(attempts, 1);

      expect(
        await coordinator.submit(
          request,
          priority: GalleryImagePriority.hover,
          retry: true,
        ),
        isFalse,
      );
      expect(attempts, 2);

      now = now.add(const Duration(seconds: 15));
      expect(coordinator.isNegativelyCached(request), isFalse);
    },
  );
}
