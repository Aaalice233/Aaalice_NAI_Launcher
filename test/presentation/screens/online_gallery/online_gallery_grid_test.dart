import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_prefetch_coordinator.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_grid.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  test('scroll state changes do not notify grid listeners', () {
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) async {},
      ),
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    var scrollingNotifications = 0;
    controller.addListener(() => notifications++);
    controller.scrolling.addListener(() => scrollingNotifications++);

    controller.setScrolling(true);
    controller.setScrolling(false);

    expect(controller.isScrolling, isFalse);
    expect(notifications, 0);
    expect(scrollingNotifications, 2);
  });

  testWidgets('only unseen items rebuild when scrolling starts', (
    tester,
  ) async {
    final previousUpdateInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(
      () => VisibilityDetectorController.instance.updateInterval =
          previousUpdateInterval,
    );
    final scrolling = ValueNotifier(false);
    addTearDown(scrolling.dispose);
    var builds = 0;
    var lastHasBeenVisible = false;
    var lastIsScrolling = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Offstage(
          child: OnlineGalleryVisibilityDrivenItem(
            visibilityKey: 'post-1',
            scrolling: scrolling,
            onVisibilityChanged: (_, __) {},
            builder: (context, hasBeenVisible, isScrolling) {
              builds++;
              lastHasBeenVisible = hasBeenVisible;
              lastIsScrolling = isScrolling;
              return const SizedBox.square(dimension: 100);
            },
          ),
        ),
      ),
    );
    expect((builds, lastHasBeenVisible, lastIsScrolling), (1, false, false));

    scrolling.value = true;
    await tester.pump();
    expect((builds, lastHasBeenVisible, lastIsScrolling), (2, false, true));

    scrolling.value = false;
    await tester.pump();
    expect(builds, 2);

    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector, skipOffstage: false),
    );
    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size.square(100),
        visibleBounds: const Rect.fromLTWH(0, 0, 100, 100),
      ),
    );
    await tester.pump();
    expect((builds, lastHasBeenVisible, lastIsScrolling), (3, true, false));

    scrolling.value = true;
    await tester.pump();
    expect(builds, 3);
  });

  test('repeated visibility updates only enter the viewport once', () {
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) async {},
      ),
    );
    addTearDown(controller.dispose);
    const item = GalleryItem(
      id: 1,
      workId: 'post-1',
      sourceId: GallerySourceId.danbooru,
    );

    expect(
      controller.recordVisibleItem(
        index: 0,
        item: item,
        itemWidth: 200,
        visibleTop: 12,
      ),
      isTrue,
    );
    expect(
      controller.recordVisibleItem(
        index: 0,
        item: item,
        itemWidth: 200,
        visibleTop: -24,
      ),
      isFalse,
    );
    expect(controller.visibleItems[0]?.visibleTop, -24);
  });

  testWidgets('lazily builds only the viewport and cache neighborhood', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) async {},
      ),
    );
    addTearDown(controller.dispose);
    final items = List.generate(
      1000,
      (index) => GalleryItem(
        id: index,
        workId: 'post-$index',
        sourceId: GallerySourceId.danbooru,
      ),
    );
    final builtIndices = <int>{};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineGalleryGrid(
            state: OnlineGalleryState(searchCache: ModeCache(posts: items)),
            controller: controller,
            itemBuilder: (context, index, itemWidth, columnCount) {
              builtIndices.add(index);
              return const SizedBox(height: 120);
            },
          ),
        ),
      ),
    );

    expect(builtIndices, contains(0));
    expect(builtIndices, isNot(contains(999)));
    expect(builtIndices.length, lessThan(200));
    final initialLastIndex = builtIndices.reduce((a, b) => a > b ? a : b);

    await tester.drag(find.byType(OnlineGalleryGrid), const Offset(0, -700));
    await tester.pump();

    expect(
      builtIndices.reduce((a, b) => a > b ? a : b),
      greaterThan(initialLastIndex),
    );
    expect(builtIndices.length, lessThan(400));
  });

  testWidgets(
    'derives column count from grid width rather than viewport height',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1800, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = OnlineGalleryScreenController(
        prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
          preloader: (_) async {},
        ),
      );
      addTearDown(controller.dispose);
      int? builtColumnCount;

      Widget subject({required double width, required double height}) {
        return MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: height,
                child: OnlineGalleryGrid(
                  state: const OnlineGalleryState(),
                  controller: controller,
                  itemBuilder: (context, index, itemWidth, columnCount) {
                    builtColumnCount = columnCount;
                    return const SizedBox(height: 20);
                  },
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(subject(width: 360, height: 640));
      expect(builtColumnCount, 2);

      await tester.pumpWidget(subject(width: 360, height: 1000));
      expect(builtColumnCount, 2);

      await tester.pumpWidget(subject(width: 1180, height: 900));
      expect(builtColumnCount, 7);

      await tester.pumpWidget(subject(width: 1600, height: 900));
      expect(builtColumnCount, 8);
    },
  );
}
