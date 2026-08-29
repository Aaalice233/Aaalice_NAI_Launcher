import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_image_request.dart';
import 'package:nai_launcher/core/cache/online_gallery_prefetch_coordinator.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';
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

  testWidgets('sample promotion uses the bounded fast motion token', (
    tester,
  ) async {
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
    expect(transition.duration, const Duration(milliseconds: 120));
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

  testWidgets('request replacement clears a stale failure', (tester) async {
    var request = _thumbnail;
    late StateSetter update;
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (candidate) => GalleryImagePreloadOperation.fromFuture(
        candidate == _thumbnail
            ? Future<void>.error(StateError('bad image'))
            : Future<void>.value(),
      ),
    );
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return CoordinatedGalleryImage(
              request: request,
              coordinator: coordinator,
              placeholder: const Text('waiting'),
              errorWidget: const Text('failed'),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('failed'), findsOneWidget);

    update(() => request = _sample);
    await tester.pump();
    await tester.pump();

    expect(find.text('failed'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('coordinated images keep the placeholder until the first frame', (
    tester,
  ) async {
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (_) =>
          GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
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
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final frameBuilder = image.frameBuilder!;
    final context = tester.element(find.byType(Image));
    expect(frameBuilder(context, const SizedBox(), null, false), isA<Text>());
    const decoded = SizedBox(key: ValueKey('decoded-image'));
    final firstFrame = frameBuilder(context, decoded, 0, false);
    expect(firstFrame, isA<Stack>());
    final stack = firstFrame as Stack;
    final fade = stack.children.last as TweenAnimationBuilder<double>;
    expect(fade.duration, const Duration(milliseconds: 120));
  });

  testWidgets('gallery fade clamps long theme motion to 160ms', (tester) async {
    final coordinator = OnlineGalleryPrefetchCoordinator(
      preloader: (_) =>
          GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
    );
    addTearDown(coordinator.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            AppThemeExtension(fastDuration: Duration(milliseconds: 400)),
          ],
        ),
        home: CoordinatedGalleryImage(
          request: _thumbnail,
          coordinator: coordinator,
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final context = tester.element(find.byType(Image));
    final result = image.frameBuilder!(context, const SizedBox(), 0, false);
    final fade =
        (result as Stack).children.last as TweenAnimationBuilder<double>;
    expect(fade.duration, const Duration(milliseconds: 160));
  });

  testWidgets(
    'synchronous cache frame bypasses fade and keeps gapless playback',
    (tester) async {
      final coordinator = OnlineGalleryPrefetchCoordinator(
        preloader: (_) =>
            GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
      );
      addTearDown(coordinator.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CoordinatedGalleryImage(
            request: _thumbnail,
            coordinator: coordinator,
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.gaplessPlayback, isTrue);
      final context = tester.element(find.byType(Image));
      const decoded = SizedBox(key: ValueKey('cached-frame'));
      final result = image.frameBuilder!(context, decoded, 0, true);
      expect(identical(result, decoded), isTrue);
    },
  );
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
