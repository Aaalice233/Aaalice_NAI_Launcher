import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/utils/image_date_grouping.dart';
import 'package:nai_launcher/presentation/widgets/grouped_grid_view.dart';

const Size _viewport = Size(600, 500);
const double _cardHeight = 70;
const int _columns = 3;
final DateTime _fixedNow = DateTime(2026, 10, 24, 12);

DateTime _fixedClock() => _fixedNow;

void main() {
  testWidgets(
    'mounted cards stay bounded when a group holds hundreds of images',
    (tester) async {
      await tester.binding.setSurfaceSize(_viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpGroupedGrid(tester, images: _sameDayImages(600));
      final mountedForSixHundred = _mountedCards.evaluate().length;

      await _pumpGroupedGrid(tester, images: _sameDayImages(1200));
      final mountedForTwelveHundred = _mountedCards.evaluate().length;

      expect(mountedForSixHundred, greaterThan(0));
      expect(mountedForSixHundred, lessThan(60));
      expect(mountedForTwelveHundred, mountedForSixHundred);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the last image of a large group is reachable at the bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(_viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGroupedGrid(tester, images: _sameDayImages(600));

    const lastCardKey = ValueKey('same-day-599');
    expect(find.byKey(lastCardKey, skipOffstage: false), findsNothing);

    await _scrollToEnd(tester);

    final lastCard = find.byKey(lastCardKey);
    expect(
      lastCard,
      findsOneWidget,
      reason: 'the final card must be onstage, not parked in the cache area',
    );
    expect(tester.getRect(lastCard).overlaps(Offset.zero & _viewport), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scrollToGroup pulls an offscreen group header into the viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(_viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final gridKey = GlobalKey<GroupedGridViewState>();
      ImageDateGroup? reportedCategory;
      final now = _fixedNow;

      await _pumpGroupedGrid(
        tester,
        images: [
          ..._imagesOn('today', now, 9),
          ..._imagesOn('yesterday', now.subtract(const Duration(days: 1)), 9),
          ..._imagesOn('earlier', now.subtract(const Duration(days: 60)), 9),
        ],
        gridKey: gridKey,
        onScrollToGroup: (category) => reportedCategory = category,
      );

      final earlierHeader = find.text('Earlier');
      expect(
        earlierHeader,
        findsNothing,
        reason: 'the target group must start offscreen to prove anything',
      );
      expect(find.text('Earlier', skipOffstage: false), findsOneWidget);

      gridKey.currentState!.scrollToGroup(ImageDateGroup.earlier);
      await tester.pumpAndSettle();

      expect(_scrollPosition(tester).pixels, greaterThan(0));
      expect(earlierHeader, findsOneWidget);
      expect(
        tester.getRect(earlierHeader).overlaps(Offset.zero & _viewport),
        isTrue,
      );
      expect(reportedCategory, ImageDateGroup.earlier);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('grouping is reused until the records or the day change', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(_viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gridKey = GlobalKey<GroupedGridViewState>();
    var now = DateTime(2026, 10, 24, 12);
    final records = [
      ..._imagesOn('today', now, 3),
      ..._imagesOn('old', DateTime(2026, 9, 1), 3),
    ];

    Future<void> pump(List<LocalImageRecord> images, {Locale? locale}) =>
        _pumpGroupedGrid(
          tester,
          images: images,
          gridKey: gridKey,
          clock: () => now,
          locale: locale,
        );

    await pump(records);
    final initial = gridKey.currentState!.debugGroups;
    expect(initial.map((group) => group.category), [
      ImageDateGroup.today,
      ImageDateGroup.earlier,
    ]);

    await pump(List.of(records));
    expect(gridKey.currentState!.debugGroups, same(initial));

    await pump(List.of(records), locale: const Locale('zh'));
    expect(gridKey.currentState!.debugGroups, same(initial));
    expect(find.text('Today'), findsNothing);

    final favorited = records[0].copyWith(isFavorite: true);
    await pump([favorited, ...records.skip(1)]);
    final afterReplace = gridKey.currentState!.debugGroups;
    expect(afterReplace, isNot(same(initial)));
    expect(afterReplace.first.images.first, same(favorited));

    now = now.add(const Duration(days: 1));
    await pump([favorited, ...records.skip(1)]);
    expect(gridKey.currentState!.debugGroups.map((group) => group.category), [
      ImageDateGroup.yesterday,
      ImageDateGroup.earlier,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reordering the same record instances regroups in the new order',
    (tester) async {
      await tester.binding.setSurfaceSize(_viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gridKey = GlobalKey<GroupedGridViewState>();
      final now = DateTime(2026, 10, 24, 12);
      final today = _imagesOn('today', now, 3);
      final old = _imagesOn('old', DateTime(2026, 9, 1), 3);

      Future<void> pump(List<LocalImageRecord> images) => _pumpGroupedGrid(
        tester,
        images: images,
        gridKey: gridKey,
        clock: () => now,
      );

      await pump([...today, ...old]);
      final initial = gridKey.currentState!.debugGroups;

      await pump([...today.reversed, ...old]);
      final reordered = gridKey.currentState!.debugGroups;

      expect(reordered, isNot(same(initial)));
      expect(reordered.first.images, hasLength(today.length));
      for (final (index, record) in today.reversed.indexed) {
        expect(reordered.first.images[index], same(record));
      }
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('today-2'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('today-0'))).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('group headers follow the locale', (tester) async {
    final images = _sameDayImages(3);

    await _pumpGroupedGrid(tester, images: images);
    expect(find.text('Today'), findsOneWidget);

    await _pumpGroupedGrid(tester, images: images, locale: const Locale('zh'));
    expect(find.text('Today'), findsNothing);
    expect(find.text('今天'), findsOneWidget);
  });
}

// skipOffstage:false also counts the cache region: the bounded quantity is the
// mounted card count, not the visible one.
final Finder _mountedCards = find.byType(_ProbeCard, skipOffstage: false);

List<LocalImageRecord> _sameDayImages(int count) =>
    _imagesOn('same-day', _fixedNow, count);

List<LocalImageRecord> _imagesOn(String prefix, DateTime day, int count) {
  return List.generate(
    count,
    (index) => LocalImageRecord(
      path: '$prefix-$index',
      size: index + 1,
      modifiedAt: day,
    ),
  );
}

Future<void> _pumpGroupedGrid(
  WidgetTester tester, {
  required List<LocalImageRecord> images,
  GlobalKey<GroupedGridViewState>? gridKey,
  void Function(ImageDateGroup category)? onScrollToGroup,
  DateTime Function() clock = _fixedClock,
  Locale? locale,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale ?? const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GroupedGridView(
            key: gridKey,
            images: images,
            columns: _columns,
            itemWidth: 180,
            onScrollToGroup: onScrollToGroup,
            clock: clock,
            buildCard: (record) => _ProbeCard(key: ValueKey(record.path)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

ScrollPosition _scrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

Future<void> _scrollToEnd(WidgetTester tester) async {
  final position = _scrollPosition(tester);
  for (var attempt = 0; attempt < 50; attempt++) {
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    if (position.pixels >= position.maxScrollExtent) break;
  }
  await tester.pumpAndSettle();
}

class _ProbeCard extends StatelessWidget {
  const _ProbeCard({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(height: _cardHeight);
}
