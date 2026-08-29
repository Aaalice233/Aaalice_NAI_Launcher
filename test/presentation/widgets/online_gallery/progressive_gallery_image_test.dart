import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_image_request.dart';
import 'package:nai_launcher/core/cache/online_gallery_prefetch_coordinator.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/coordinated_gallery_image.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/progressive_gallery_image.dart';

const _thumbnail = GalleryImageRequest(
  sourceId: 'danbooru',
  url: 'https://example.test/thumb.jpg',
  tier: GalleryImageTier.thumbnail,
  targetDecodeWidth: 320,
);
const _sample = GalleryImageRequest(
  sourceId: 'danbooru',
  url: 'https://example.test/sample.jpg',
  tier: GalleryImageTier.sample,
  targetDecodeWidth: 640,
);

void main() {
  testWidgets('preloaded sample is shown without a transition', (tester) async {
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (_) =>
          GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
    );
    addTearDown(coordinator.dispose);
    expect(
      await coordinator.submit(_sample, priority: GalleryImagePriority.visible),
      isTrue,
    );

    await tester.pumpWidget(_app(coordinator));

    final transition = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(transition.duration, Duration.zero);
  });

  testWidgets('sample promotion fades for 140ms after loading', (tester) async {
    final gate = Completer<void>();
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (_) => GalleryImagePreloadOperation.fromFuture(gate.future),
    );
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(_app(coordinator));
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);

    gate.complete();
    await tester.pump();

    final transition = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(transition.duration, const Duration(milliseconds: 140));
  });

  testWidgets('reduced motion promotes the sample immediately', (tester) async {
    final gate = Completer<void>();
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (_) => GalleryImagePreloadOperation.fromFuture(gate.future),
    );
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(_app(coordinator, disableAnimations: true));
    gate.complete();
    await tester.pump();

    final transition = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(transition.duration, Duration.zero);
  });

  testWidgets(
    'visible image download is cancelled for critical activity and resumes',
    (tester) async {
      var starts = 0;
      var cancellations = 0;
      final coordinator = OnlineGalleryPrefetchCoordinator(
        preloader: (_) {
          starts += 1;
          final gate = Completer<void>();
          return GalleryImagePreloadOperation(
            future: gate.future,
            cancel: () {
              cancellations += 1;
              gate.completeError(StateError('cancelled'));
            },
          );
        },
      );
      addTearDown(coordinator.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CoordinatedGalleryImage(
            request: _thumbnail,
            coordinator: coordinator,
            placeholder: const Text('waiting'),
          ),
        ),
      );
      expect(starts, 1);

      coordinator.setCriticalNetworkActive(true);
      await tester.pump();
      expect(cancellations, 1);
      expect(find.text('waiting'), findsOneWidget);

      coordinator.setCriticalNetworkActive(false);
      await tester.pump();
      expect(starts, 2);
    },
  );

  testWidgets('cancelled sample preload resumes with the coordinator', (
    tester,
  ) async {
    var sampleStarts = 0;
    final gates = <Completer<void>>[];
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (request) {
        if (request.tier == GalleryImageTier.thumbnail) {
          return GalleryImagePreloadOperation.fromFuture(Future<void>.value());
        }
        sampleStarts += 1;
        final gate = Completer<void>();
        gates.add(gate);
        return GalleryImagePreloadOperation(
          future: gate.future,
          cancel: () => gate.completeError(StateError('cancelled')),
        );
      },
    );
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(_app(coordinator));
    expect(sampleStarts, 1);

    coordinator.setCriticalNetworkActive(true);
    await tester.pump();
    coordinator.setCriticalNetworkActive(false);
    await tester.pump();

    expect(sampleStarts, 2);
  });

  testWidgets('failed coordinated download renders a stable error state', (
    tester,
  ) async {
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (_) => GalleryImagePreloadOperation.fromFuture(
        Future<void>.error(StateError('bad image')),
      ),
    );
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CoordinatedGalleryImage(
          request: _thumbnail,
          coordinator: coordinator,
          placeholder: const Text('waiting'),
          errorWidget: const Text('failed'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('failed'), findsOneWidget);
    expect(find.text('waiting'), findsNothing);
  });
}

Widget _app(
  OnlineGalleryPrefetchCoordinator coordinator, {
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Center(
        child: SizedBox(
          width: 320,
          height: 320,
          child: ProgressiveGalleryImage(
            thumbnail: _thumbnail,
            sample: _sample,
            coordinator: coordinator,
          ),
        ),
      ),
    ),
  );
}
