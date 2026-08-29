import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_detail_coordinator.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/gallery_grid_item.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  late Duration previousVisibilityUpdateInterval;

  setUp(() {
    previousVisibilityUpdateInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    VisibilityDetectorController.instance.updateInterval =
        previousVisibilityUpdateInterval;
  });

  testWidgets(
    'scope change retries a cancelled queued detail while the card stays visible',
    (tester) async {
      final activeGate = Completer<GalleryDetail>();
      final activeItem = _item.copyWith(id: 99, workId: 'active');
      final resolvedItem = _item.copyWith(
        previewFileUrl: 'https://example.test/resolved.jpg',
      );
      final coordinator = OnlineGalleryDetailCoordinator(
        maxConcurrent: 1,
        loader: (item, _) => item.id == activeItem.id
            ? activeGate.future
            : Future.value(GalleryDetail(item: resolvedItem, media: const [])),
      );
      final active = coordinator.request(activeItem);
      var scope = 1;

      await tester.pumpWidget(
        _app(detailRequestScope: scope, loadDetail: coordinator.request),
      );
      final detector = tester.widget<VisibilityDetector>(
        find.byType(VisibilityDetector),
      );
      detector.onVisibilityChanged?.call(
        VisibilityInfo(
          key: detector.key!,
          size: const Size(200, 200),
          visibleBounds: const Rect.fromLTWH(0, 0, 200, 200),
        ),
      );
      await tester.pump();
      expect(coordinator.queuedCount, 1);

      coordinator.cancelQueuedVisible();
      scope++;
      await tester.pumpWidget(
        _app(detailRequestScope: scope, loadDetail: coordinator.request),
      );
      await tester.pump();

      expect(coordinator.queuedCount, 1);
      activeGate.complete(GalleryDetail(item: activeItem, media: const []));
      await active;
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('resolved-card')), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets('same scope rebuild reuses the persistent detail future', (
    tester,
  ) async {
    final detail = Completer<GalleryDetail>();
    var calls = 0;
    Future<GalleryDetail> loadDetail(
      GalleryItem item, {
      required GalleryDetailPriority priority,
      bool forceRefresh = false,
    }) {
      calls++;
      return detail.future;
    }

    await tester.pumpWidget(
      _app(detailRequestScope: 1, loadDetail: loadDetail),
    );
    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(200, 200),
        visibleBounds: const Rect.fromLTWH(0, 0, 200, 200),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      _app(detailRequestScope: 1, loadDetail: loadDetail),
    );
    await tester.pump();

    expect(calls, 1);
    detail.complete(const GalleryDetail(item: _item, media: []));
    await tester.pump();
  });

  testWidgets('real detail errors show retry and retry can resolve the card', (
    tester,
  ) async {
    final firstAttempt = Completer<GalleryDetail>();
    final resolvedItem = _item.copyWith(
      previewFileUrl: 'https://example.test/resolved.jpg',
    );
    var calls = 0;
    var forcedRefresh = false;

    await tester.pumpWidget(
      _app(
        detailRequestScope: 1,
        loadDetail: (item, {required priority, forceRefresh = false}) {
          calls++;
          forcedRefresh = forceRefresh;
          return calls == 1
              ? firstAttempt.future
              : Future.value(
                  GalleryDetail(item: resolvedItem, media: const []),
                );
        },
      ),
    );

    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(200, 200),
        visibleBounds: const Rect.fromLTWH(0, 0, 200, 200),
      ),
    );
    await tester.pump();

    firstAttempt.completeError(StateError('network failed'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(calls, 2);
    expect(forcedRefresh, isTrue);
    expect(find.byKey(const ValueKey('resolved-card')), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
    'missing dimensions remain an empty stable card until first visibility',
    (tester) async {
      const item = GalleryItem(
        id: 2,
        workId: 'work-2',
        sourceId: GallerySourceId.danbooru,
        previewFileUrl: 'https://example.test/pending.jpg',
      );
      final loadMediaValues = <bool>[];
      final mediaGate = Completer<bool>();

      await tester.pumpWidget(
        _app(
          post: item,
          detailRequestScope: 1,
          loadDetail: (_, {required priority, forceRefresh = false}) =>
              throw StateError('detail should not load'),
          prepareMedia: (_, __) => mediaGate.future,
          onBuildCard: loadMediaValues.add,
        ),
      );

      expect(loadMediaValues, [isFalse]);
      expect(find.byKey(const ValueKey('resolved-card')), findsOneWidget);
      expect(tester.getSize(find.byType(GalleryGridItem)).height, 200);

      final detector = tester.widget<VisibilityDetector>(
        find.byType(VisibilityDetector),
      );
      detector.onVisibilityChanged?.call(
        VisibilityInfo(
          key: detector.key!,
          size: const Size(200, 200),
          visibleBounds: const Rect.fromLTWH(0, 0, 200, 200),
        ),
      );
      await tester.pump();

      expect(loadMediaValues.last, isFalse);
      mediaGate.complete(true);
      await tester.pump();
      await tester.pump();

      expect(loadMediaValues.last, isTrue);
      expect(find.byKey(const ValueKey('resolved-card')), findsOneWidget);
      expect(tester.getSize(find.byType(GalleryGridItem)).height, 200);
    },
  );

  testWidgets('AI TAG resolved media is prepared using its real URL', (
    tester,
  ) async {
    final resolved = _item.copyWith(
      imageWidth: 1200,
      imageHeight: 800,
      previewFileUrl: 'https://example.test/ai-tag-resolved.jpg',
    );
    final prepared = <GalleryItem>[];
    final mediaGate = Completer<bool>();
    final loadMediaValues = <bool>[];
    final layoutAspectRatios = <double>[];
    await tester.pumpWidget(
      _app(
        detailRequestScope: 1,
        loadDetail: (_, {required priority, forceRefresh = false}) =>
            Future.value(GalleryDetail(item: resolved, media: const [])),
        prepareMedia: (item, _) {
          prepared.add(item);
          return mediaGate.future;
        },
        onBuildCard: loadMediaValues.add,
        onLayoutAspectRatio: layoutAspectRatios.add,
      ),
    );

    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(200, 200),
        visibleBounds: const Rect.fromLTWH(0, 0, 200, 200),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(prepared, [resolved]);
    expect(loadMediaValues.last, isFalse);
    expect(layoutAspectRatios.last, 1.5);

    mediaGate.complete(true);
    await tester.pump();
    await tester.pump();
    expect(loadMediaValues.last, isTrue);
  });

  testWidgets('visible thumbnail retries after a transient prepare failure', (
    tester,
  ) async {
    const item = GalleryItem(
      id: 3,
      workId: 'work-3',
      sourceId: GallerySourceId.danbooru,
      previewFileUrl: 'https://example.test/retry.jpg',
    );
    var attempts = 0;
    final loadMediaValues = <bool>[];
    await tester.pumpWidget(
      _app(
        post: item,
        detailRequestScope: 1,
        loadDetail: (_, {required priority, forceRefresh = false}) =>
            throw StateError('detail should not load'),
        prepareMedia: (_, __) async => ++attempts > 1,
        onBuildCard: loadMediaValues.add,
      ),
    );

    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(200, 200),
        visibleBounds: const Rect.fromLTWH(0, 0, 200, 200),
      ),
    );
    await tester.pump();
    expect(attempts, 1);
    expect(loadMediaValues.last, isFalse);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(attempts, 2);
    expect(loadMediaValues.last, isTrue);
  });

  testWidgets('persistent prepare failures fall back without polling forever', (
    tester,
  ) async {
    var attempts = 0;
    final loadMediaValues = <bool>[];
    await tester.pumpWidget(
      _app(
        post: _item.copyWith(previewFileUrl: 'https://example.test/broken.jpg'),
        detailRequestScope: 1,
        loadDetail: (_, {required priority, forceRefresh = false}) =>
            throw StateError('detail should not load'),
        prepareMedia: (_, __) async {
          attempts++;
          return false;
        },
        onBuildCard: loadMediaValues.add,
      ),
    );

    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(200, 200),
        visibleBounds: const Rect.fromLTWH(0, 0, 200, 200),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(attempts, 4);
    expect(loadMediaValues.last, isTrue);
    await tester.pump(const Duration(minutes: 1));
    expect(attempts, 4);
  });

  testWidgets('cancelled background detail stays quiet and scope resumes it', (
    tester,
  ) async {
    final firstAttempt = Completer<GalleryDetail>();
    final resolvedItem = _item.copyWith(
      previewFileUrl: 'https://example.test/resolved.jpg',
    );
    var calls = 0;

    Future<GalleryDetail> loadDetail(
      GalleryItem item, {
      required GalleryDetailPriority priority,
      bool forceRefresh = false,
    }) {
      calls++;
      return calls == 1
          ? firstAttempt.future
          : Future.value(GalleryDetail(item: resolvedItem, media: const []));
    }

    await tester.pumpWidget(
      _app(detailRequestScope: 1, loadDetail: loadDetail),
    );
    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    detector.onVisibilityChanged?.call(
      VisibilityInfo(
        key: detector.key!,
        size: const Size(200, 200),
        visibleBounds: const Rect.fromLTWH(0, 0, 200, 200),
      ),
    );
    await tester.pump();

    firstAttempt.completeError(
      DioException.requestCancelled(
        requestOptions: RequestOptions(path: '/detail'),
        reason: 'Gallery paused',
      ),
    );
    await tester.pump();
    expect(find.text('Retry'), findsNothing);

    await tester.pumpWidget(
      _app(detailRequestScope: 2, loadDetail: loadDetail),
    );
    await tester.pump();
    expect(calls, 2);
    expect(find.byKey(const ValueKey('resolved-card')), findsOneWidget);
  });
}

const _item = GalleryItem(
  id: 1,
  workId: 'work-1',
  sourceId: GallerySourceId.aiTag,
);

Widget _app({
  GalleryItem post = _item,
  required Object detailRequestScope,
  required Future<GalleryDetail> Function(
    GalleryItem item, {
    required GalleryDetailPriority priority,
    bool forceRefresh,
  })
  loadDetail,
  Future<bool> Function(GalleryItem item, double itemWidth)? prepareMedia,
  ValueChanged<bool>? onBuildCard,
  ValueChanged<double>? onLayoutAspectRatio,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 200,
        height: 200,
        child: GalleryGridItem(
          post: post,
          index: 0,
          itemWidth: 200,
          columnCount: 1,
          scrolling: const AlwaysStoppedAnimation(false),
          anchorKey: null,
          onVisibilityChanged: (_, __, ___, ____, _____, ______) {},
          detailRequestScope: detailRequestScope,
          prepareMedia: prepareMedia ?? (_, __) => Future<bool>.value(true),
          loadDetail: loadDetail,
          buildCard:
              (
                context,
                item,
                itemWidth, {
                required layoutAspectRatio,
                required loadMedia,
                detail,
              }) {
                onBuildCard?.call(loadMedia);
                onLayoutAspectRatio?.call(layoutAspectRatio);
                return SizedBox(
                  key: const ValueKey('resolved-card'),
                  height: itemWidth / layoutAspectRatio,
                );
              },
        ),
      ),
    ),
  );
}
