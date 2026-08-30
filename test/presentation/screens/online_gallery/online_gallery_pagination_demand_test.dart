import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_pagination_demand.dart';

void main() {
  test('expands load-ahead runway from measured scroll velocity', () {
    var now = DateTime(2026);
    final demand = OnlineGalleryPaginationDemand(now: () => now);

    demand.recordScroll(0);
    now = now.add(const Duration(milliseconds: 100));
    demand.recordScroll(1000);

    expect(demand.loadAheadDistance(1000), greaterThan(4000));
  });

  test('coalesces concurrent demand and rejects stale request completion', () {
    var now = DateTime(2026);
    final demand = OnlineGalleryPaginationDemand(now: () => now);

    final first = demand.beginRequest(
      scopeKey: 'search-a',
      cursor: '2',
      viewportDimension: 800,
    );
    expect(first, isNotNull);
    expect(
      demand.beginRequest(
        scopeKey: 'search-a',
        cursor: '2',
        viewportDimension: 800,
      ),
      isNull,
    );

    demand.resetScope('search-b');
    final second = demand.beginRequest(
      scopeKey: 'search-b',
      cursor: '1',
      viewportDimension: 800,
    );
    expect(second, isNotNull);

    final stale = demand.completeRequest(first!);
    expect(stale.accepted, isFalse);
    expect(demand.requestInFlight, isTrue);

    now = now.add(const Duration(seconds: 1));
    final current = demand.completeRequest(second!);
    expect(current.accepted, isTrue);
    expect(demand.requestInFlight, isFalse);
  });

  test('measures demand from loaded content instead of placeholder runway', () {
    final demand = OnlineGalleryPaginationDemand();
    const viewport = 728.0;
    const itemWidth = 181.9;
    const columnCount = 8;
    const spacing = 6.0;
    const pageSize = 60;
    final reservedExtent = demand.placeholderExtent(
      viewportDimension: viewport,
      itemWidth: itemWidth,
      columnCount: columnCount,
      spacing: spacing,
      pageSize: pageSize,
    );
    final demandDistance = demand.loadAheadDistance(viewport);
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: reservedExtent + demandDistance - 1,
      pixels: 0,
      viewportDimension: viewport,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

    expect(demand.isWithinDemandWindow(metrics), isFalse);
    expect(
      demand.isWithinDemandWindow(
        metrics,
        reservedPlaceholderExtent: reservedExtent,
      ),
      isTrue,
    );
  });

  test('reserves several viewports without unbounded placeholder growth', () {
    var now = DateTime(2026);
    final demand = OnlineGalleryPaginationDemand(now: () => now);
    demand.recordScroll(0);
    now = now.add(const Duration(milliseconds: 16));
    demand.recordScroll(10000);
    final token = demand.beginRequest(
      scopeKey: 'search',
      cursor: '2',
      viewportDimension: 800,
    );
    expect(token, isNotNull);

    final count = demand.placeholderCount(
      viewportDimension: 800,
      itemWidth: 160,
      columnCount: 4,
      spacing: 6,
      pageSize: 60,
    );

    expect(count, greaterThanOrEqualTo(60));
    expect(count, lessThanOrEqualTo((800 * 12 / 166).ceil() * 4));
  });
}
