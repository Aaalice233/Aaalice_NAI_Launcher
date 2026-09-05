import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/grouped_grid_view.dart';

const Size _viewport = Size(600, 500);
const double _cardHeight = 70;
const int _columns = 3;

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
      final now = DateTime.now();

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
}

// skipOffstage:false also counts the cache region: the bounded quantity is the
// mounted card count, not the visible one.
final Finder _mountedCards = find.byType(_ProbeCard, skipOffstage: false);

List<LocalImageRecord> _sameDayImages(int count) =>
    _imagesOn('same-day', DateTime.now(), count);

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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GroupedGridView(
            key: gridKey,
            images: images,
            columns: _columns,
            itemWidth: 180,
            onScrollToGroup: onScrollToGroup,
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
