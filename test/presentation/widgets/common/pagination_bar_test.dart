import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/pagination_bar.dart';

void main() {
  testWidgets('narrow gallery pagination matches the compact online style', (
    tester,
  ) async {
    int? selectedPage;
    await _pumpPagination(
      tester,
      width: 430,
      onPageChanged: (page) => selectedPage = page,
    );

    expect(find.text('第 2 页'), findsOneWidget);
    expect(find.text('120 张'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(tester.getSize(find.byType(PaginationBar)).height, 48);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(selectedPage, 2);
  });

  testWidgets('very narrow pagination keeps the count compact', (tester) async {
    await _pumpPagination(tester, width: 320, onPageChanged: (_) {});

    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('120 张'), findsNothing);
    expect(tester.getSize(find.byType(PaginationBar)).height, 48);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPagination(
  WidgetTester tester, {
  required double width,
  required ValueChanged<int> onPageChanged,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 240));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: PaginationBar(
            currentPage: 1,
            totalPages: 3,
            totalItems: 120,
            itemsPerPage: 60,
            onPageChanged: onPageChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
