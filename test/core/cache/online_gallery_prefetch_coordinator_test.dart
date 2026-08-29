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

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected queued preload was not started');
}

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

    for (var index = 0; index < futures.length; index++) {
      await _waitUntil(() => gates.length > index);
      gates[index].complete();
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
    'scrolling keeps visible work moving but pauses lookahead work',
    () async {
      final started = <String>[];
      final coordinator = OnlineGalleryPrefetchCoordinator(
        maxConcurrent: 1,
        preloader: (request) async => started.add(request.url),
      );
      coordinator.setScrolling(true);

      final lookahead = coordinator.submit(
        _request(1),
        priority: GalleryImagePriority.lookahead,
      );
      final visible = coordinator.submit(
        _request(2),
        priority: GalleryImagePriority.visible,
      );
      await Future<void>.delayed(Duration.zero);

      expect(started, ['https://example.com/2.jpg']);
      expect(await visible, isTrue);
      coordinator.setScrolling(false);
      expect(await lookahead, isTrue);
    },
  );

  test('moving thumbnail window cancels stale queued requests', () async {
    final gate = Completer<void>();
    final coordinator = OnlineGalleryPrefetchCoordinator(
      maxConcurrent: 1,
      preloader: (request) =>
          request.url.endsWith('/0.jpg') ? gate.future : Future<void>.value(),
    );
    final active = coordinator.submit(
      _request(0),
      priority: GalleryImagePriority.visible,
    );
    final stale = coordinator.submit(
      _request(1),
      priority: GalleryImagePriority.lookahead,
    );
    final retained = coordinator.submit(
      _request(2),
      priority: GalleryImagePriority.lookahead,
    );

    coordinator.retainThumbnailWindow({_request(2).stableRequestKey});
    expect(await stale, isFalse);
    expect(coordinator.queueDepth, 1);

    gate.complete();
    expect(await active, isTrue);
    expect(await retained, isTrue);
  });

  test('queue stays bounded and visible work displaces lookahead', () async {
    final gate = Completer<void>();
    final started = <String>[];
    final coordinator = OnlineGalleryPrefetchCoordinator(
      maxConcurrent: 1,
      maxQueued: 2,
      preloader: (request) {
        started.add(request.url);
        return request.url.endsWith('/0.jpg')
            ? gate.future
            : Future<void>.value();
      },
    );
    final active = coordinator.submit(
      _request(0),
      priority: GalleryImagePriority.visible,
    );
    final oldestLookahead = coordinator.submit(
      _request(1),
      priority: GalleryImagePriority.lookahead,
    );
    final newestLookahead = coordinator.submit(
      _request(2),
      priority: GalleryImagePriority.lookahead,
    );
    final visible = coordinator.submit(
      _request(3),
      priority: GalleryImagePriority.visible,
    );

    expect(coordinator.queueDepth, 2);
    expect(await newestLookahead, isFalse);
    gate.complete();
    expect(await active, isTrue);
    expect(await visible, isTrue);
    expect(await oldestLookahead, isTrue);
    expect(started, [
      'https://example.com/0.jpg',
      'https://example.com/3.jpg',
      'https://example.com/1.jpg',
    ]);
  });

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
