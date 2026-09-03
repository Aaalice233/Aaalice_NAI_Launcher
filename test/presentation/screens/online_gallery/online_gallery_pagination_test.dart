import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/cache/online_gallery_prefetch_coordinator.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_pagination.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_screen_controller.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';

class _MockOnlineGalleryNotifier extends Mock
    implements OnlineGalleryNotifier {}

void main() {
  for (final width in [320.0, 360.0]) {
    testWidgets(
      'pagination remains reachable at ${width.toInt()}px and text scale 3',
      (tester) async {
        final controller = _createController();
        final notifier = _MockOnlineGalleryNotifier();
        addTearDown(controller.dispose);
        final visitedPages = <int>[];

        await _pumpPagination(
          tester,
          width: width,
          state: const OnlineGalleryState(searchCache: ModeCache(page: 2)),
          controller: controller,
          notifier: notifier,
          onGoToPage: (page) async => visitedPages.add(page),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('online-gallery-pagination-bar')),
              )
              .height,
          greaterThan(48),
        );
        _expectBorderlessFooterSurface(tester);

        final scrollable = find.byType(SingleChildScrollView);
        await tester.drag(scrollable, const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.chevron_right).hitTestable(), findsOneWidget);
        await tester.tap(find.byIcon(Icons.chevron_right).hitTestable());

        await tester.drag(scrollable, const Offset(300, 0));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.chevron_left).hitTestable(), findsOneWidget);
        await tester.tap(find.byIcon(Icons.chevron_left).hitTestable());

        expect(visitedPages, containsAll(<int>[1, 3]));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'random exhausted actions remain reachable without clipping at text scale 3',
    (tester) async {
      final controller = _createController();
      final notifier = _MockOnlineGalleryNotifier();
      addTearDown(controller.dispose);
      when(() => notifier.restartRandom()).thenAnswer((_) async {});

      await _pumpPagination(
        tester,
        width: 320,
        state: const OnlineGalleryState(
          randomEnabled: true,
          randomSession: RandomGallerySession(exhausted: true),
        ),
        controller: controller,
        notifier: notifier,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('online-gallery-random-status-bar')),
            )
            .height,
        greaterThan(48),
      );
      _expectBorderlessFooterSurface(tester);
      await tester.ensureVisible(find.byIcon(Icons.replay));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.replay).hitTestable(), findsOneWidget);

      await tester.tap(find.byIcon(Icons.replay).hitTestable());
      verify(() => notifier.restartRandom()).called(1);
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectBorderlessFooterSurface(WidgetTester tester) {
  final finder = find.byKey(
    const ValueKey('online-gallery-footer-tonal-surface'),
  );
  final container = tester.widget<Container>(finder);
  final decoration = container.decoration! as BoxDecoration;
  final colorScheme = Theme.of(tester.element(finder)).colorScheme;

  expect(decoration.color, controlSurfaceColor(colorScheme));
  expect(decoration.border, isNull);
  expect(decoration.borderRadius, isNotNull);
}

OnlineGalleryScreenController _createController() {
  return OnlineGalleryScreenController(
    prefetchCoordinator: OnlineGalleryPrefetchCoordinator(
      preloader: (_) => GalleryImagePreloadOperation.fromFuture(Future.value()),
    ),
  );
}

Future<void> _pumpPagination(
  WidgetTester tester, {
  required double width,
  required OnlineGalleryState state,
  required OnlineGalleryScreenController controller,
  required OnlineGalleryNotifier notifier,
  Future<void> Function(int page)? onGoToPage,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 120);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(3)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: OnlineGalleryPagination(
            state: state,
            controller: controller,
            notifier: notifier,
            onGoToPage: onGoToPage ?? (_) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
