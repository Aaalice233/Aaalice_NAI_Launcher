import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
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
    final barRect = tester.getRect(find.byType(PaginationBar));
    final navigationRect = tester.getRect(
      find.byKey(const ValueKey('pagination-narrow-navigation')),
    );
    final totalInfoRect = tester.getRect(
      find.byKey(const ValueKey('pagination-narrow-total-info')),
    );
    final trailingActionRect = tester.getRect(
      find.byKey(const ValueKey('pagination-narrow-trailing-action')),
    );
    expect(navigationRect.center.dx, closeTo(barRect.center.dx, 0.1));
    expect(totalInfoRect.right, lessThanOrEqualTo(navigationRect.left));
    expect(trailingActionRect.left, greaterThanOrEqualTo(navigationRect.right));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(selectedPage, 2);
  });

  testWidgets('very narrow pagination keeps every setting reachable', (
    tester,
  ) async {
    await _pumpPagination(tester, width: 320, onPageChanged: (_) {});

    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('120 张'), findsNothing);
    expect(
      find.byKey(const ValueKey('pagination-narrow-items-per-page')),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(PaginationBar)).height, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('width and text-scale matrix reflows without overflow', (
    tester,
  ) async {
    for (final textScale in [1.0, 1.3, 2.0, 3.0]) {
      for (final width in [360.0, 412.0, 600.0, 700.0, 840.0, 1180.0, 1600.0]) {
        await _pumpPagination(
          tester,
          width: width,
          totalPages: 12,
          textScaler: TextScaler.linear(textScale),
          onPageChanged: (_) {},
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'width=$width, textScale=$textScale',
        );
      }
    }
  });

  testWidgets('editing closes when pagination becomes loading', (tester) async {
    final semantics = tester.ensureSemantics();
    var loading = false;
    var changes = 0;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return Scaffold(
              body: SizedBox(
                width: 360,
                child: PaginationBar(
                  currentPage: 1,
                  totalPages: 3,
                  loading: loading,
                  onPageChanged: (_) => changes++,
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('第 2 页'));
    await tester.pump();
    expect(find.byType(EditableText), findsOneWidget);

    setHostState(() => loading = true);
    await tester.pump();
    expect(find.byType(EditableText), findsNothing);
    expect(find.bySemanticsLabel('加载中...'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(changes, 0);
    semantics.dispose();
  });

  testWidgets('touch targets remain 48dp and loading blocks navigation', (
    tester,
  ) async {
    var changes = 0;
    await _pumpPagination(
      tester,
      width: 840,
      loading: true,
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
      onPageChanged: (_) => changes++,
    );

    for (final button in find.byType(IconButton).evaluate()) {
      expect(
        tester
            .getSize(find.byElementPredicate((element) => element == button))
            .height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(changes, 0);
  });

  testWidgets('tonal pagination remains distinct from a collapsed canvas', (
    tester,
  ) async {
    const canvas = Color(0xFF111111);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.red,
      brightness: Brightness.dark,
    ).copyWith(surface: canvas, surfaceContainer: canvas);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: colorScheme),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PaginationBar(
            currentPage: 0,
            totalPages: 1,
            tonalCard: true,
            onPageChanged: (_) {},
          ),
        ),
      ),
    );

    final tonalContainer = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(PaginationBar),
            matching: find.byType(Container),
          ),
        )
        .firstWhere(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration! as BoxDecoration).borderRadius != null,
        );
    final decoration = tonalContainer.decoration! as BoxDecoration;

    expect(decoration.color, isNot(canvas));
  });
}

Future<void> _pumpPagination(
  WidgetTester tester, {
  required double width,
  required ValueChanged<int> onPageChanged,
  bool loading = false,
  int totalPages = 3,
  TextScaler textScaler = TextScaler.noScaling,
  InteractionPolicy? interactionPolicy,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 240));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: InteractionPolicyScope(
        initialPolicy: interactionPolicy,
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PaginationBar(
              currentPage: 1,
              totalPages: totalPages,
              totalItems: 120,
              itemsPerPage: 60,
              loading: loading,
              onItemsPerPageChanged: (_) {},
              onPageChanged: onPageChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
