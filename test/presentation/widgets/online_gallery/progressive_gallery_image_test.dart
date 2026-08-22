import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_image_request.dart';
import 'package:nai_launcher/core/cache/online_gallery_prefetch_coordinator.dart';
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
      preloader: (_) async {},
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
      preloader: (_) => gate.future,
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
      preloader: (_) => gate.future,
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
