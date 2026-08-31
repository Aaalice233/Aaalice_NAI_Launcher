import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_prefetch_coordinator.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_grid.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_masonry_layout.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  test('scroll state changes do not notify grid listeners', () {
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) =>
            GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
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

  testWidgets('unseen items reveal once after scrolling stops', (tester) async {
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
    var lastIsVisible = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Offstage(
          child: OnlineGalleryVisibilityDrivenItem(
            visibilityKey: 'post-1',
            scrolling: scrolling,
            onVisibilityChanged: (_, __, ___) {},
            builder: (context, hasBeenVisible, isScrolling, isVisible) {
              builds++;
              lastHasBeenVisible = hasBeenVisible;
              lastIsScrolling = isScrolling;
              lastIsVisible = isVisible;
              return const SizedBox.square(dimension: 100);
            },
          ),
        ),
      ),
    );
    expect((builds, lastHasBeenVisible, lastIsScrolling), (1, false, false));

    scrolling.value = true;
    await tester.pump();
    expect((builds, lastHasBeenVisible, lastIsScrolling), (1, false, false));

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
    expect(
      (builds, lastHasBeenVisible, lastIsScrolling, lastIsVisible),
      (1, false, false, false),
    );

    scrolling.value = false;
    await tester.pump();
    expect(
      (builds, lastHasBeenVisible, lastIsScrolling, lastIsVisible),
      (2, true, false, true),
    );

    scrolling.value = true;
    await tester.pump();
    expect(builds, 2);
  });

  test('scroll restore revisions reject stale post-frame work', () {
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) =>
            GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
      ),
    );
    addTearDown(controller.dispose);

    final first = controller.beginScrollRestore();
    final second = controller.beginScrollRestore();

    expect(controller.isCurrentScrollRestore(first), isFalse);
    expect(controller.isCurrentScrollRestore(second), isTrue);
    controller.invalidateScrollRestore();
    expect(controller.isCurrentScrollRestore(second), isFalse);
  });

  test('repeated visibility updates only enter the viewport once', () {
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) =>
            GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
      ),
    );
    addTearDown(controller.dispose);
    const item = GalleryItem(
      id: 1,
      workId: 'post-1',
      sourceId: GallerySourceId.danbooru,
    );
    expect(
      controller.viewportTracker.recordVisibleItem(
        index: 0,
        item: item,
        itemWidth: 200,
        leadingScrollOffset: 12,
        viewportGeneration: controller.viewportGeneration,
        tokenSequence: 1,
      ),
      isTrue,
    );
    expect(
      controller.viewportTracker.recordVisibleItem(
        index: 0,
        item: item,
        itemWidth: 200,
        leadingScrollOffset: -24,
        viewportGeneration: controller.viewportGeneration,
        tokenSequence: 1,
      ),
      isFalse,
    );
    expect(
      controller.viewportTracker
          .resolveVisibleItems(const [item])
          .single
          .leadingScrollOffset,
      -24,
    );
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
        preloader: (_) =>
            GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
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
              if (index < items.length) builtIndices.add(index);
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

  test('precomputed masonry finds only geometry intersecting an offset', () {
    final snapshot = OnlineGalleryMasonryLayoutSnapshot(
      aspectRatios: const [1, 2, 0.5, 1, 1, 1],
      placeholderCount: 0,
      columnCount: 2,
      itemWidth: 100,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
    );

    expect(snapshot.placementFor(0).scrollOffset, 0);
    expect(snapshot.placementFor(1).scrollOffset, 0);
    expect(snapshot.placementFor(2).scrollOffset, 86);
    expect(snapshot.placementFor(2).mainAxisExtent, 200);
    expect(snapshot.minIndexForScrollOffset(120), 2);
    expect(snapshot.maxIndexForScrollOffset(120), 3);
    expect(snapshot.maxScrollExtent, 392);
  });

  testWidgets('far jumps build only the destination cache neighborhood', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) =>
            GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
      ),
    );
    addTearDown(controller.dispose);
    final items = List.generate(
      2000,
      (index) => GalleryItem(
        id: index,
        workId: 'post-$index',
        sourceId: GallerySourceId.danbooru,
        width: 100 + index % 5 * 20,
        height: 100 + index % 7 * 30,
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
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    builtIndices.clear();
    final middle = controller.scrollController.position.maxScrollExtent / 2;
    controller.scrollController.jumpTo(middle);
    await tester.pump();

    expect(builtIndices, isNotEmpty);
    expect(builtIndices.length, lessThan(150));
    expect(builtIndices.reduce((a, b) => a < b ? a : b), greaterThan(500));

    builtIndices.clear();
    controller.scrollController.jumpTo(0);
    await tester.pump();

    expect(builtIndices, isNotEmpty);
    expect(builtIndices.length, lessThan(150));
    expect(builtIndices.reduce((a, b) => a > b ? a : b), lessThan(150));
  });

  testWidgets('initial loading creates a scrollable batch of empty cards', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) =>
            GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineGalleryGrid(
            state: const OnlineGalleryState(isLoading: true),
            controller: controller,
            itemBuilder: (context, index, itemWidth, columnCount) =>
                const SizedBox(height: 24),
          ),
        ),
      ),
    );

    expect(find.byType(OnlineGalleryPendingCard), findsWidgets);
    expect(
      controller.scrollController.position.maxScrollExtent,
      greaterThan(0),
    );
    final before = controller.scrollController.offset;
    await tester.drag(find.byType(OnlineGalleryGrid), const Offset(0, -400));
    await tester.pump();
    expect(controller.scrollController.offset, greaterThan(before));
  });

  testWidgets('append placeholders reserve slots after existing posts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) =>
            GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
      ),
    );
    addTearDown(controller.dispose);
    final items = List.generate(
      4,
      (index) => GalleryItem(
        id: index,
        workId: 'post-$index',
        sourceId: GallerySourceId.danbooru,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineGalleryGrid(
            state: OnlineGalleryState(
              isLoadingMore: true,
              searchCache: ModeCache(posts: items),
            ),
            controller: controller,
            itemBuilder: (context, index, itemWidth, columnCount) =>
                SizedBox(key: ValueKey('loaded-$index'), height: itemWidth),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('loaded-0')), findsOneWidget);
    expect(find.byType(OnlineGalleryPendingCard), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(SliverGrid),
        matching: find.byType(OnlineGalleryPendingCard),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byType(SliverGrid),
        matching: find.byKey(const ValueKey('loaded-0')),
      ),
      findsOneWidget,
    );
    final pending = tester.widgetList<OnlineGalleryPendingCard>(
      find.byType(OnlineGalleryPendingCard),
    );
    expect(pending.every((card) => card.itemWidth > 0), isTrue);
    expect(
      controller.scrollController.position.maxScrollExtent,
      greaterThan(0),
    );
    final loadingExtent = controller.scrollController.position.maxScrollExtent;

    final completedItems = List.generate(
      8,
      (index) => GalleryItem(
        id: index,
        workId: 'post-$index',
        sourceId: GallerySourceId.danbooru,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineGalleryGrid(
            state: OnlineGalleryState(
              searchCache: ModeCache(posts: completedItems),
            ),
            controller: controller,
            itemBuilder: (context, index, itemWidth, columnCount) =>
                SizedBox(key: ValueKey('completed-$index'), height: itemWidth),
          ),
        ),
      ),
    );
    await tester.pump();

    final completedExtent =
        controller.scrollController.position.maxScrollExtent;
    expect(completedExtent, greaterThanOrEqualTo(loadingExtent));
    controller.scrollController.jumpTo(completedExtent);
    await tester.pump();
    expect(find.byType(OnlineGalleryPendingCard), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineGalleryGrid(
            state: OnlineGalleryState(
              searchCache: ModeCache(posts: completedItems, hasMore: false),
            ),
            controller: controller,
            itemBuilder: (context, index, itemWidth, columnCount) =>
                SizedBox(key: ValueKey('completed-$index'), height: itemWidth),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnlineGalleryPendingCard), findsNothing);
    expect(find.byKey(const ValueKey('completed-7')), findsOneWidget);
  });

  testWidgets(
    'does not snap back when posts replace a deep placeholder runway',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(840, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = OnlineGalleryScreenController(
        prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
          preloader: (_) =>
              GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
        ),
      );
      addTearDown(controller.dispose);

      Widget subject(int postCount) {
        final items = List.generate(
          postCount,
          (index) => GalleryItem(
            id: index,
            workId: 'post-$index',
            sourceId: GallerySourceId.danbooru,
            width: 1,
            height: 1,
          ),
        );
        return MaterialApp(
          home: Scaffold(
            body: OnlineGalleryGrid(
              state: OnlineGalleryState(
                isLoadingMore: true,
                searchCache: ModeCache(posts: items),
              ),
              controller: controller,
              itemBuilder: (context, index, itemWidth, columnCount) =>
                  SizedBox(key: ValueKey('loaded-$index'), height: itemWidth),
            ),
          ),
        );
      }

      await tester.pumpWidget(subject(108));
      final deepRunwayOffset =
          controller.scrollController.position.maxScrollExtent - 300;
      expect(deepRunwayOffset, greaterThan(3000));
      controller.scrollController.jumpTo(deepRunwayOffset);
      await tester.pump();
      expect(find.byType(OnlineGalleryPendingCard), findsWidgets);

      await tester.pumpWidget(subject(168));
      await tester.pump();

      expect(controller.scrollController.offset, closeTo(deepRunwayOffset, 1));
      expect(controller.scrollController.offset, greaterThan(3000));
    },
  );

  testWidgets(
    'keeps twenty-one loaded pages reachable after append placeholders change',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(840, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = OnlineGalleryScreenController(
        prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
          preloader: (_) =>
              GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
        ),
      );
      addTearDown(controller.dispose);
      final initialItems = List.generate(
        21 * 60,
        (index) => GalleryItem(
          id: index,
          workId: 'post-$index',
          sourceId: GallerySourceId.danbooru,
          width: 1,
          height: 1,
        ),
      );

      Widget subject(List<GalleryItem> items, {bool loadingMore = false}) {
        return MaterialApp(
          home: Scaffold(
            body: OnlineGalleryGrid(
              state: OnlineGalleryState(
                isLoadingMore: loadingMore,
                searchCache: ModeCache(posts: items, hasMore: loadingMore),
              ),
              controller: controller,
              itemBuilder: (context, index, itemWidth, columnCount) => SizedBox(
                key: ValueKey('grid-item:${items[index].stableKey}'),
                height: 100,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(subject(initialItems));
      controller.scrollController.jumpTo(
        controller.scrollController.position.maxScrollExtent,
      );
      await tester.pump();
      final initialMaxScrollExtent =
          controller.scrollController.position.maxScrollExtent;
      final bottomOffset = controller.scrollController.offset;
      expect(bottomOffset, greaterThan(1000));

      await tester.pumpWidget(subject(initialItems, loadingMore: true));
      await tester.pump();
      expect(controller.scrollController.offset, greaterThan(1000));

      final appendedItems = [
        ...initialItems,
        for (
          var index = initialItems.length;
          index < initialItems.length + 60;
          index++
        )
          GalleryItem(
            id: index,
            workId: 'post-$index',
            sourceId: GallerySourceId.danbooru,
            width: 1,
            height: 1,
          ),
      ];
      await tester.pumpWidget(subject(appendedItems));
      await tester.pump();
      expect(controller.scrollController.offset, greaterThan(1000));
      expect(
        controller.scrollController.position.maxScrollExtent,
        greaterThan(initialMaxScrollExtent),
      );

      controller.scrollController.jumpTo(
        controller.scrollController.position.maxScrollExtent,
      );
      await tester.pump();
      expect(
        find.byKey(ValueKey('grid-item:${appendedItems.last.stableKey}')),
        findsOneWidget,
      );

      controller.scrollController.jumpTo(0);
      await tester.pump();
      expect(
        find.byKey(ValueKey('grid-item:${initialItems.first.stableKey}')),
        findsOneWidget,
      );
      expect(appendedItems, hasLength(1320));
    },
  );

  testWidgets(
    'derives column count from grid width rather than viewport height',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1800, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = OnlineGalleryScreenController(
        prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
          preloader: (_) =>
              GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
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
                  state: const OnlineGalleryState(
                    searchCache: ModeCache(
                      posts: [
                        GalleryItem(
                          id: 1,
                          workId: 'column-probe',
                          sourceId: GallerySourceId.danbooru,
                        ),
                      ],
                    ),
                  ),
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

  testWidgets(
    'restores a page seven anchor through zero constraints and column changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = OnlineGalleryScreenController(
        prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
          preloader: (_) =>
              GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
        ),
      );
      addTearDown(controller.dispose);
      final items = List.generate(
        7 * 60,
        (index) => GalleryItem(
          id: index,
          workId: 'page-seven-$index',
          sourceId: GallerySourceId.danbooru,
          width: 100 + index % 5 * 20,
          height: 100 + index % 7 * 15,
        ),
      );
      const anchorIndex = 365;
      const localOffset = 18.0;
      final state = OnlineGalleryState(
        searchCache: ModeCache(
          posts: items,
          page: 7,
          hasMore: false,
          scrollOffset: 12000,
          anchorStableKey: items[anchorIndex].stableKey,
          anchorLocalOffset: localOffset,
        ),
      );

      double expectedOffset(double width) {
        const spacing = 6.0;
        final availableWidth = width - 24;
        final columns = ((availableWidth + spacing) / (160 + spacing))
            .floor()
            .clamp(1, 8);
        final itemWidth = (availableWidth - (columns - 1) * spacing) / columns;
        final layout = OnlineGalleryMasonryLayoutSnapshot(
          aspectRatios: [for (final item in items) item.width / item.height],
          placeholderCount: 0,
          columnCount: columns,
          itemWidth: itemWidth,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
        );
        return 12 + layout.placementFor(anchorIndex).scrollOffset + localOffset;
      }

      Widget subject(double width, double height) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: OnlineGalleryGrid(
                state: state,
                controller: controller,
                itemBuilder: (_, __, ___, ____) => const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(subject(840, 700));
      expect(
        controller.scrollController.offset,
        closeTo(expectedOffset(840), 1),
      );

      final retainedOffset = controller.scrollController.offset;
      await tester.pumpWidget(subject(840, 0));
      expect(controller.scrollController.hasClients, isFalse);

      await tester.pumpWidget(subject(840, 700));
      expect(controller.scrollController.offset, closeTo(retainedOffset, 1));

      await tester.pumpWidget(subject(1180, 700));
      expect(
        controller.scrollController.offset,
        closeTo(expectedOffset(1180), 1),
      );
      expect(state.currentCache.page, 7);
      expect(state.posts, hasLength(420));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps viewport snapshots isolated by browsing scope', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(840, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = OnlineGalleryScreenController(
      prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
        preloader: (_) =>
            GalleryImagePreloadOperation.fromFuture(Future<void>.value()),
      ),
    );
    addTearDown(controller.dispose);
    final items = List.generate(
      180,
      (index) => GalleryItem(
        id: index,
        workId: 'scope-$index',
        sourceId: GallerySourceId.danbooru,
        width: 1,
        height: 1,
      ),
    );

    OnlineGalleryState scopedState(String query, int anchorIndex) =>
        OnlineGalleryState(
          searchQuery: query,
          searchCache: ModeCache(
            posts: items,
            page: 3,
            hasMore: false,
            anchorStableKey: items[anchorIndex].stableKey,
            anchorLocalOffset: 10,
          ),
        );

    Widget subject(OnlineGalleryState state, {double height = 700}) =>
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: height,
              child: OnlineGalleryGrid(
                state: state,
                controller: controller,
                itemBuilder: (_, __, ___, ____) => const SizedBox.expand(),
              ),
            ),
          ),
        );

    final first = scopedState('first', 80);
    final second = scopedState('second', 140);
    await tester.pumpWidget(subject(first));
    final firstOffset = controller.scrollController.offset;
    controller.stageViewportRestore(
      scope: second.currentCacheKey,
      cache: second.currentCache,
    );
    await tester.pumpWidget(subject(second, height: 0));
    await tester.pumpWidget(subject(second));
    final secondOffset = controller.scrollController.offset;
    expect(secondOffset, greaterThan(firstOffset));

    controller.stageViewportRestore(
      scope: first.currentCacheKey,
      cache: first.currentCache,
    );
    await tester.pumpWidget(subject(first));
    expect(controller.scrollController.offset, closeTo(firstOffset, 1));
    expect(first.currentCache.page, 3);
    expect(second.currentCache.page, 3);
  });
}
