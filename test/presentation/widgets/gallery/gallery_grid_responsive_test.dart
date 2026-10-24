import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/gallery/draggable_image_card.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_grid.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_card_3d.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  const cases = <(double, int)>[
    (320, 2),
    (360, 2),
    (600, 3),
    (840, 4),
    (1180, 6),
    (1600, 8),
  ];

  for (final (width, columns) in cases) {
    testWidgets(
      'grid fills ${width.toInt()}px with $columns responsive columns',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpGrid(tester, columns: columns, selectedIndices: const {0});

        final delegate =
            tester.widget<GridView>(find.byType(GridView)).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, columns);

        final firstCard = tester.widget<LocalImageCard3D>(
          find.byType(LocalImageCard3D).first,
        );
        final expectedWidth = (width - 24 - 12 * (columns - 1)) / columns;
        expect(firstCard.width, closeTo(expectedWidth, 0.001));
        expect(firstCard.isSelected, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('selection and scroll offset survive a responsive resize', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGrid(tester, columns: 3, selectedIndices: const {0, 20});
    await tester.drag(find.byType(GridView), const Offset(0, -900));
    await tester.pump();

    final beforeResize = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(beforeResize, greaterThan(0));

    await tester.binding.setSurfaceSize(const Size(840, 500));
    await tester.pump();

    final afterResize = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(afterResize, closeTo(beforeResize, 0.001));

    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
    await tester.pump();
    final firstCard = tester.widget<LocalImageCard3D>(
      find.byType(LocalImageCard3D).first,
    );
    expect(firstCard.record.path, 'G:/gallery/image-0.png');
    expect(firstCard.isSelected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling keeps mounted cards without rebuilding the grid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGrid(tester, columns: 3);
    final before = _mountedCardsByPath(tester);

    await tester.drag(find.byType(GridView), const Offset(0, -120));
    // 跨过可见性检测的默认 500ms 批次
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    final after = _mountedCardsByPath(tester);
    final retained = before.keys.where(after.containsKey).toList();
    expect(retained, isNotEmpty);
    for (final path in retained) {
      expect(after[path], same(before[path]), reason: path);
    }
    expect(find.byType(VisibilityDetector, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolled cards keep their index, keyboard activation and drag', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final taps = <(String, int)>[];

    await _pumpGrid(
      tester,
      columns: 3,
      enableDrag: true,
      onTap: (record, index) => taps.add((record.path, index)),
    );
    await tester.drag(find.byType(GridView), const Offset(0, -900));
    await tester.pump();

    final tapped = _cardFor('G:/gallery/image-13.png');
    await tester.tap(tapped);
    await tester.pump(kDoubleTapTimeout);
    expect(taps.last, ('G:/gallery/image-13.png', 13));

    final focused = _cardFor('G:/gallery/image-14.png');
    final focusTarget = find.descendant(
      of: find.descendant(
        of: focused,
        matching: find.byType(FocusableActionDetector),
      ),
      matching: find.byType(GestureDetector),
    );
    Focus.of(tester.element(focusTarget.first)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps.last, ('G:/gallery/image-14.png', 14));

    for (final path in ['G:/gallery/image-13.png', 'G:/gallery/image-14.png']) {
      final drag = tester.widget<DraggableImageCard>(
        find.descendant(
          of: _cardFor(path),
          matching: find.byType(DraggableImageCard),
        ),
      );
      expect(drag.record.path, path);
    }
    expect(taps, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid scroll state survives switching to grouped-list mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _GridToggleHarness(),
        ),
      ),
    );
    await tester.drag(find.byType(GridView), const Offset(0, -900));
    await tester.pump();
    final beforeSwitch = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(beforeSwitch, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('toggle-grid-mode')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('grouped-list-placeholder')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('toggle-grid-mode')));
    await tester.pump();
    final afterSwitch = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(afterSwitch, closeTo(beforeSwitch, 0.001));
    expect(tester.takeException(), isNull);
  });
}

Map<String, LocalImageCard3D> _mountedCardsByPath(WidgetTester tester) => {
  for (final card in tester.widgetList<LocalImageCard3D>(
    find.byType(LocalImageCard3D, skipOffstage: false),
  ))
    card.record.path: card,
};

Finder _cardFor(String path) => find.byWidgetPredicate(
  (widget) => widget is LocalImageCard3D && widget.record.path == path,
);

Future<void> _pumpGrid(
  WidgetTester tester, {
  required int columns,
  Set<int>? selectedIndices,
  bool enableDrag = false,
  void Function(LocalImageRecord record, int index)? onTap,
}) async {
  final images = List.generate(
    60,
    (index) => LocalImageRecord(
      path: 'G:/gallery/image-$index.png',
      size: index + 1,
      modifiedAt: DateTime(2026, 8, 1),
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GalleryGrid(
            images: images,
            columns: columns,
            spacing: 12,
            padding: const EdgeInsets.all(12),
            selectedIndices: selectedIndices,
            enableDrag: enableDrag,
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _GridToggleHarness extends StatefulWidget {
  const _GridToggleHarness();

  @override
  State<_GridToggleHarness> createState() => _GridToggleHarnessState();
}

class _GridToggleHarnessState extends State<_GridToggleHarness> {
  bool grouped = false;

  @override
  Widget build(BuildContext context) {
    final images = List.generate(
      60,
      (index) => LocalImageRecord(
        path: 'G:/gallery/toggle-$index.png',
        size: index + 1,
        modifiedAt: DateTime(2026, 8, 1),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const ValueKey('toggle-grid-mode'),
            onPressed: () => setState(() => grouped = !grouped),
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      body: grouped
          ? const Center(
              key: ValueKey('grouped-list-placeholder'),
              child: Text('Grouped list'),
            )
          : GalleryGrid(
              key: const PageStorageKey<String>('gallery-grid'),
              images: images,
              columns: 3,
              spacing: 12,
              padding: const EdgeInsets.all(12),
              enableDrag: false,
            ),
    );
  }
}
