import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/image_comparison_screen.dart';

void main() {
  final images = List.generate(
    2,
    (index) => LocalImageRecord(
      path: 'C:/tmp/missing_compare_$index.png',
      size: 1,
      modifiedAt: DateTime(2026),
    ),
  );

  testWidgets('two images stack on a narrow portrait window', (tester) async {
    await _pumpComparison(
      tester,
      size: const Size(360, 640),
      textScale: 2,
      images: images,
    );

    final viewers = tester
        .widgetList<InteractiveViewer>(find.byType(InteractiveViewer))
        .toList();
    expect(viewers, hasLength(2));
    final centers = find
        .byType(InteractiveViewer)
        .evaluate()
        .map((element) => tester.getCenter(find.byWidget(element.widget)))
        .toList();
    expect((centers[0].dx - centers[1].dx).abs(), lessThan(1));
    expect(centers[0].dy, lessThan(centers[1].dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two images use the wide workspace in landscape', (tester) async {
    await _pumpComparison(
      tester,
      size: const Size(760, 420),
      textScale: 1,
      images: images,
    );

    final centers = find
        .byType(InteractiveViewer)
        .evaluate()
        .map((element) => tester.getCenter(find.byWidget(element.widget)))
        .toList();
    expect(centers, hasLength(2));
    expect((centers[0].dy - centers[1].dy).abs(), lessThan(1));
    expect(centers[0].dx, lessThan(centers[1].dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state scrolls with actions at 320px and 3x text', (
    tester,
  ) async {
    await _pumpComparison(
      tester,
      size: const Size(320, 180),
      textScale: 3,
      images: const [],
    );

    expect(find.byKey(const ValueKey('comparison_back')), findsOneWidget);
    expect(find.byKey(const ValueKey('comparison_home')), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('comparison_message_scroll_view')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('too-many error scrolls on a short landscape viewport', (
    tester,
  ) async {
    await _pumpComparison(
      tester,
      size: const Size(568, 240),
      textScale: 3,
      images: List.generate(5, (index) => images[index % images.length]),
    );

    expect(find.byKey(const ValueKey('comparison_home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpComparison(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required List<LocalImageRecord> images,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          ),
          child: ImageComparisonScreen(images: images),
        ),
      ),
    ),
  );
  await tester.pump();
}
