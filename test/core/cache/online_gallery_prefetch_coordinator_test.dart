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

GalleryImagePreloadOperation _operation(Future<void> future) =>
    GalleryImagePreloadOperation.fromFuture(future);

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
        return _operation(gate.future.whenComplete(() => active--));
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
        return _operation(gate.future);
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
        preloader: (_) => _operation(gate.future),
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
    'completed thumbnails are reused without starting another preload',
    () async {
      var starts = 0;
      final request = _request(1);
      final coordinator = OnlineGalleryPrefetchCoordinator(
        preloader: (_) {
          starts++;
          return _operation(Future<void>.value());
        },
      );
      addTearDown(coordinator.dispose);

      expect(
        await coordinator.submit(
          request,
          priority: GalleryImagePriority.visible,
        ),
        isTrue,
      );
      expect(coordinator.isReady(request), isTrue);
      expect(
        await coordinator.submit(
          request,
          priority: GalleryImagePriority.visible,
        ),
        isTrue,
      );
      expect(starts, 1);
    },
  );

  test(
    'generation rotation rejects old queued and in-flight results',
    () async {
      final gate = Completer<void>();
      final coordinator = OnlineGalleryPrefetchCoordinator(
        maxConcurrent: 1,
        preloader: (_) => _operation(gate.future),
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

  test('scrolling rejects lookahead but still starts hover work', () async {
    final started = <String>[];
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (request) =>
          _operation(Future<void>.sync(() => started.add(request.url))),
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
    expect(await low, isFalse);
  });

  test('moving thumbnail window cancels stale queued requests', () async {
    final gate = Completer<void>();
    final coordinator = OnlineGalleryPrefetchCoordinator(
      maxConcurrent: 1,
      preloader: (request) => _operation(
        request.url.endsWith('/0.jpg') ? gate.future : Future<void>.value(),
      ),
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
        return _operation(
          request.url.endsWith('/0.jpg') ? gate.future : Future<void>.value(),
        );
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
        preloader: (_) => _operation(Future<void>.value()),
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

  test('new generation cancels stale in-flight work on the wire', () async {
    final gates = <Completer<void>>[];
    var cancels = 0;
    var starts = 0;
    final request = _request(1);
    final coordinator = OnlineGalleryPrefetchCoordinator(
      maxConcurrent: 1,
      preloader: (_) {
        starts++;
        final gate = Completer<void>();
        gates.add(gate);
        return GalleryImagePreloadOperation(
          future: gate.future,
          cancel: () {
            cancels++;
            if (!gate.isCompleted) {
              gate.completeError(StateError('cancelled'));
            }
          },
        );
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
    expect(await old, isFalse);
    await _waitUntil(() => gates.length == 2);
    gates[1].complete();
    expect(await current, isTrue);
    expect(starts, 2);
    expect(cancels, 1);
  });

  test(
    'stale completion cannot remove the replacement in-flight task',
    () async {
      final gates = <Completer<void>>[];
      final coordinator = OnlineGalleryPrefetchCoordinator(
        maxConcurrent: 2,
        preloader: (_) {
          final gate = Completer<void>();
          gates.add(gate);
          return GalleryImagePreloadOperation(
            future: gate.future,
            cancel: () {},
          );
        },
      );
      addTearDown(coordinator.dispose);
      final request = _request(1);

      final stale = coordinator.submit(
        request,
        priority: GalleryImagePriority.visible,
      );
      coordinator.rotateGeneration();
      final replacement = coordinator.submit(
        request,
        priority: GalleryImagePriority.visible,
      );
      await _waitUntil(() => gates.length == 2);

      gates.first.complete();
      expect(await stale, isFalse);
      expect(coordinator.activeCount, 1);

      gates.last.complete();
      expect(await replacement, isTrue);
      expect(coordinator.activeCount, 0);
    },
  );

  test(
    'critical activity cancels low-priority work but keeps detail',
    () async {
      final cancelled = <String>[];
      final gates = <String, Completer<void>>{};
      final coordinator = OnlineGalleryPrefetchCoordinator(
        preloader: (request) {
          final gate = Completer<void>();
          gates[request.url] = gate;
          return GalleryImagePreloadOperation(
            future: gate.future,
            cancel: () {
              cancelled.add(request.url);
              if (!gate.isCompleted) {
                gate.completeError(StateError('cancelled'));
              }
            },
          );
        },
      );

      final visible = coordinator.submit(
        _request(1),
        priority: GalleryImagePriority.visible,
      );
      coordinator.setCriticalNetworkActive(true);
      expect(await visible, isFalse);
      expect(cancelled, ['https://example.com/1.jpg']);

      final rejected = coordinator.submit(
        _request(2),
        priority: GalleryImagePriority.hover,
      );
      final detail = coordinator.submit(
        _request(3),
        priority: GalleryImagePriority.interactiveDetail,
      );
      expect(await rejected, isFalse);
      await _waitUntil(() => gates.containsKey('https://example.com/3.jpg'));
      gates['https://example.com/3.jpg']!.complete();
      expect(await detail, isTrue);
    },
  );

  test('nested pause reasons resume only after every reason clears', () async {
    final started = <String>[];
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (request) =>
          _operation(Future<void>.sync(() => started.add(request.url))),
    );

    coordinator.setPageVisible(false);
    coordinator.setAppForeground(false);
    expect(coordinator.pauseReasons, {
      GalleryPrefetchPauseReason.pageHidden,
      GalleryPrefetchPauseReason.appBackground,
    });

    coordinator.setPageVisible(true);
    expect(coordinator.isPaused, isTrue);
    expect(
      await coordinator.submit(
        _request(1),
        priority: GalleryImagePriority.interactiveDetail,
      ),
      isFalse,
    );

    coordinator.setAppForeground(true);
    expect(coordinator.isPaused, isFalse);
    expect(
      await coordinator.submit(
        _request(2),
        priority: GalleryImagePriority.visible,
      ),
      isTrue,
    );
    expect(started, ['https://example.com/2.jpg']);
  });

  test('visible work is not starved by continuous detail work', () async {
    final started = <String>[];
    final gates = <Completer<void>>[];
    final coordinator = OnlineGalleryPrefetchCoordinator(
      maxConcurrent: 1,
      preloader: (request) {
        started.add(request.url);
        final gate = Completer<void>();
        gates.add(gate);
        return _operation(gate.future);
      },
    );

    final first = coordinator.submit(
      _request(0),
      priority: GalleryImagePriority.interactiveDetail,
    );
    final visible = coordinator.submit(
      _request(9),
      priority: GalleryImagePriority.visible,
    );
    final details = [
      for (var index = 1; index <= 4; index++)
        coordinator.submit(
          _request(index),
          priority: GalleryImagePriority.interactiveDetail,
        ),
    ];

    for (var index = 0; index < 3; index++) {
      gates[index].complete();
      await _waitUntil(() => gates.length > index + 1);
    }
    expect(started[3], 'https://example.com/9.jpg');

    for (var index = 3; index < 6; index++) {
      gates[index].complete();
      if (index < 5) await _waitUntil(() => gates.length > index + 1);
    }
    expect(await first, isTrue);
    expect(await visible, isTrue);
    expect(await Future.wait(details), everyElement(isTrue));
  });

  test('dispose cancels active work and rejects future submissions', () async {
    final gate = Completer<void>();
    var cancelled = false;
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (_) => GalleryImagePreloadOperation(
        future: gate.future,
        cancel: () {
          cancelled = true;
          if (!gate.isCompleted) gate.completeError(StateError('cancelled'));
        },
      ),
    );
    final active = coordinator.submit(
      _request(1),
      priority: GalleryImagePriority.visible,
    );
    coordinator.dispose();
    expect(await active, isFalse);
    expect(cancelled, isTrue);
    expect(
      await coordinator.submit(
        _request(2),
        priority: GalleryImagePriority.visible,
      ),
      isFalse,
    );
  });

  test(
    'negative cache lasts 15 seconds and explicit retry clears it',
    () async {
      var now = DateTime(2026);
      var attempts = 0;
      final request = _request(1, tier: GalleryImageTier.sample);
      final coordinator = OnlineGalleryPrefetchCoordinator(
        now: () => now,
        preloader: (_) => _operation(
          Future<void>.sync(() {
            attempts++;
            throw StateError('failed');
          }),
        ),
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

  test('cancels one hover request without cancelling visible work', () async {
    final gates = <String, Completer<void>>{};
    final cancelled = <String>[];
    final coordinator = OnlineGalleryPrefetchCoordinator(
      maxConcurrent: 2,
      preloader: (request) {
        final gate = Completer<void>();
        gates[request.url] = gate;
        return GalleryImagePreloadOperation(
          future: gate.future,
          cancel: () {
            cancelled.add(request.url);
            gate.completeError(StateError('cancelled'));
          },
        );
      },
    );
    addTearDown(coordinator.dispose);
    final hoverRequest = _request(1, tier: GalleryImageTier.sample);
    final visibleRequest = _request(2);
    final hover = coordinator.submit(
      hoverRequest,
      priority: GalleryImagePriority.hover,
    );
    final visible = coordinator.submit(
      visibleRequest,
      priority: GalleryImagePriority.visible,
    );

    coordinator.cancel(
      hoverRequest,
      priority: GalleryImagePriority.hover,
      reason: 'hover-dismissed',
    );
    expect(await hover, isFalse);
    expect(cancelled, [hoverRequest.url]);

    gates[visibleRequest.url]!.complete();
    expect(await visible, isTrue);
  });
}
