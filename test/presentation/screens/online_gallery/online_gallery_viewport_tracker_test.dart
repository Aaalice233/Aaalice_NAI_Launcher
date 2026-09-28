import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_viewport_tracker.dart';

GalleryItem _item(int id) => GalleryItem(
  id: id,
  workId: 'post-$id',
  sourceId: GallerySourceId.danbooru,
  width: 1,
  height: 1,
);

FixedScrollMetrics _metrics(double pixels) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: 5000,
  pixels: pixels,
  viewportDimension: 800,
  axisDirection: AxisDirection.down,
  devicePixelRatio: 1,
);

void main() {
  test(
    'resolves visible indices from stable identity after a sparse insert',
    () {
      final tracker = OnlineGalleryViewportTracker();
      addTearDown(tracker.dispose);
      final first = _item(1);
      final second = _item(2);

      tracker.recordVisibleItem(
        index: 1,
        item: second,
        itemWidth: 160,
        leadingScrollOffset: 900,
        viewportGeneration: tracker.generation,
        tokenSequence: 1,
      );

      final resolved = tracker.resolveVisibleItems([_item(0), first, second]);
      expect(resolved.single.index, 2);
      expect(resolved.single.item.stableKey, second.stableKey);
    },
  );

  test(
    'settles pagination from geometry nearest the viewport leading edge',
    () {
      final tracker = OnlineGalleryViewportTracker();
      addTearDown(tracker.dispose);
      final posts = [_item(0), _item(1), _item(2)];
      for (var index = 0; index < posts.length; index++) {
        tracker.recordVisibleItem(
          index: index,
          item: posts[index],
          itemWidth: 160,
          leadingScrollOffset: index * 900,
          viewportGeneration: tracker.generation,
          tokenSequence: index + 1,
        );
      }

      final anchor = tracker.resolveLeadingAnchor(
        posts: posts,
        metrics: _metrics(950),
      );

      expect(anchor?.index, 1);
      expect(anchor?.item.stableKey, posts[1].stableKey);
    },
  );

  test('remembers viewed media independently from current visibility', () {
    final tracker = OnlineGalleryViewportTracker();
    addTearDown(tracker.dispose);
    final item = _item(1);

    tracker.recordVisibleItem(
      index: 0,
      item: item,
      itemWidth: 160,
      leadingScrollOffset: 0,
      viewportGeneration: tracker.generation,
      tokenSequence: 1,
    );
    tracker.removeVisibleItem(
      item,
      viewportGeneration: tracker.generation,
      tokenSequence: 1,
    );

    expect(tracker.hasVisibleItems, isFalse);
    expect(tracker.viewedItemKeys, contains(item.stableKey));
  });

  test('ignores stale enter and exit from an older item instance', () {
    final tracker = OnlineGalleryViewportTracker();
    addTearDown(tracker.dispose);
    final item = _item(1);

    tracker.recordVisibleItem(
      index: 0,
      item: item,
      itemWidth: 160,
      leadingScrollOffset: 0,
      viewportGeneration: tracker.generation,
      tokenSequence: 2,
    );
    expect(
      tracker.recordVisibleItem(
        index: 0,
        item: item,
        itemWidth: 160,
        leadingScrollOffset: 400,
        viewportGeneration: tracker.generation,
        tokenSequence: 1,
      ),
      isFalse,
    );
    expect(tracker.resolveVisibleItems([item]).single.leadingScrollOffset, 0);
    expect(
      tracker.removeVisibleItem(
        item,
        viewportGeneration: tracker.generation,
        tokenSequence: 1,
      ),
      isNull,
    );
    expect(tracker.hasVisibleItems, isTrue);
    expect(
      tracker.removeVisibleItem(
        item,
        viewportGeneration: tracker.generation,
        tokenSequence: 2,
      ),
      isNotNull,
    );
  });

  test('rejects callbacks from a reset viewport generation', () {
    final tracker = OnlineGalleryViewportTracker();
    addTearDown(tracker.dispose);
    final item = _item(1);
    final staleGeneration = tracker.generation;

    tracker.resetVisibleItems();

    expect(
      tracker.recordVisibleItem(
        index: 0,
        item: item,
        itemWidth: 160,
        leadingScrollOffset: 0,
        viewportGeneration: staleGeneration,
        tokenSequence: 1,
      ),
      isFalse,
    );
    expect(tracker.hasVisibleItems, isFalse);
  });

  test('bounds viewed media history while retaining recent items', () {
    final tracker = OnlineGalleryViewportTracker();
    addTearDown(tracker.dispose);

    for (
      var id = 0;
      id <= OnlineGalleryViewportTracker.viewedItemCapacity;
      id++
    ) {
      tracker.recordVisibleItem(
        index: id,
        item: _item(id),
        itemWidth: 160,
        leadingScrollOffset: id.toDouble(),
        viewportGeneration: tracker.generation,
        tokenSequence: id + 1,
      );
    }

    expect(
      tracker.viewedItemKeys,
      hasLength(OnlineGalleryViewportTracker.viewedItemCapacity),
    );
    expect(tracker.viewedItemKeys, isNot(contains(_item(0).stableKey)));
    expect(
      tracker.viewedItemKeys,
      contains(
        _item(OnlineGalleryViewportTracker.viewedItemCapacity).stableKey,
      ),
    );
  });
}
