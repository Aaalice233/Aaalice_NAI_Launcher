import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/data/models/gallery/image_collection.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/collection_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_album_provider.dart';
import 'package:nai_launcher/presentation/widgets/collection_select_dialog.dart';
import 'package:nai_launcher/presentation/widgets/gallery/album_select_dialog.dart';

void main() {
  testWidgets(
    '320 wide selectors stay scrollable at 3x with SafeArea and IME',
    (tester) async {
      await _pumpHost(
        tester,
        size: const Size(320, 900),
        textScaler: const TextScaler.linear(3),
        viewInsets: const EdgeInsets.only(bottom: 180),
        padding: const EdgeInsets.only(top: 24, bottom: 16),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Open collection'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      final collectionScroll = find.byKey(
        const Key('collection-select-scroll'),
      );
      expect(collectionScroll, findsOneWidget);
      await _jumpToEndUntilVisible(
        tester,
        tester.widget<CustomScrollView>(collectionScroll).controller!,
        find.text('Collection 19'),
      );
      await _tapVisibleTop(tester, find.text('Collection 19'));
      expect(find.text('collection:collection-19'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Open album'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const ValueKey('adaptive-bottom-sheet')),
        findsOneWidget,
      );
      final albumScroll = find.byKey(const Key('album-select-scroll'));
      expect(albumScroll, findsOneWidget);
      await _jumpToEndUntilVisible(
        tester,
        tester.widget<CustomScrollView>(albumScroll).controller!,
        find.text('Album 29'),
      );
      await _tapVisibleTop(tester, find.text('Album 29'));
      expect(find.text('album:album-29'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320px-high compact selectors keep search and results reachable',
    (tester) async {
      await _pumpHost(
        tester,
        size: const Size(320, 320),
        textScaler: TextScaler.noScaling,
      );

      await tester.tap(find.text('Open collection'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search).hitTestable(), findsOneWidget);
      await _scrollToEnd(
        tester,
        find.byKey(const Key('collection-select-scroll')),
      );
      await tester.tap(find.text('Collection 19'));
      await tester.pumpAndSettle();
      expect(find.text('collection:collection-19'), findsOneWidget);

      await tester.tap(find.text('Open album'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search).hitTestable(), findsOneWidget);
      await _scrollToEnd(tester, find.byKey(const Key('album-select-scroll')));
      await tester.tap(find.text('Album 29'));
      await tester.pumpAndSettle();
      expect(find.text('album:album-29'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('IME leaves compact search and filtered selection usable', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      size: const Size(320, 568),
      viewInsets: const EdgeInsets.only(bottom: 248),
      textScaler: TextScaler.noScaling,
    );

    await tester.tap(find.text('Open album'));
    await tester.pumpAndSettle();
    final search = find.byType(TextField);
    expect(search.hitTestable(), findsOneWidget);
    await tester.enterText(search, 'Album 29');
    await tester.pumpAndSettle();
    final matchingAlbum = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('Album 29'),
    );
    expect(matchingAlbum.hitTestable(), findsOneWidget);
    await tester.tap(matchingAlbum);
    await tester.pumpAndSettle();
    expect(find.text('album:album-29'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded selectors use bounded centered dialogs', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      size: const Size(1180, 800),
      textScaler: TextScaler.noScaling,
    );

    await tester.tap(find.text('Open collection'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    final collectionDialog = tester.getRect(
      find.byKey(const ValueKey('adaptive-centered-form')),
    );
    expect(collectionDialog.width, 450);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open album'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    final albumDialog = tester.getRect(
      find.byKey(const ValueKey('adaptive-centered-form')),
    );
    expect(albumDialog.width, 450);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required Size size,
  required TextScaler textScaler,
  EdgeInsets viewInsets = EdgeInsets.zero,
  EdgeInsets padding = EdgeInsets.zero,
  bool empty = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final albums = empty
      ? <GalleryAlbum>[]
      : List.generate(
          30,
          (index) => GalleryAlbum(
            id: 'album-$index',
            name: 'Album $index',
            imageCount: index,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
  final collections = empty
      ? <ImageCollection>[]
      : List.generate(
          20,
          (index) => ImageCollection(
            id: 'collection-$index',
            name: 'Collection $index',
            createdAt: DateTime(2026),
          ),
        );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        galleryAlbumNotifierProvider.overrideWith(
          () => _StaticAlbumNotifier(GalleryAlbumState(albums: albums)),
        ),
        collectionNotifierProvider.overrideWith(
          () => _StaticCollectionNotifier(
            CollectionState(collections: collections),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            viewInsets: viewInsets,
            padding: padding,
            viewPadding: padding,
          ),
          child: child!,
        ),
        home: const _PresenterHost(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _scrollToEnd(WidgetTester tester, Finder scrollView) async {
  for (var i = 0; i < 5; i++) {
    await tester.drag(scrollView, const Offset(0, -500));
    await tester.pump();
  }
}

Future<void> _jumpToEndUntilVisible(
  WidgetTester tester,
  ScrollController controller,
  Finder target,
) async {
  for (var i = 0; i < 10 && target.evaluate().isEmpty; i++) {
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> _tapVisibleTop(WidgetTester tester, Finder label) async {
  final tile = find.ancestor(of: label, matching: find.byType(ListTile));
  final rect = tester.getRect(tile);
  await tester.tapAt(Offset(rect.center.dx, rect.top + 12));
  await tester.pumpAndSettle();
}

class _PresenterHost extends StatefulWidget {
  const _PresenterHost();

  @override
  State<_PresenterHost> createState() => _PresenterHostState();
}

class _PresenterHostState extends State<_PresenterHost> {
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FilledButton(
            onPressed: () {
              unawaited(_showCollection());
            },
            child: const Text('Open collection'),
          ),
          FilledButton(
            onPressed: () {
              unawaited(_showAlbum());
            },
            child: const Text('Open album'),
          ),
          if (_result != null) Text(_result!),
        ],
      ),
    );
  }

  Future<void> _showCollection() async {
    final result = await CollectionSelectDialog.show(
      context,
      theme: Theme.of(context),
    );
    if (result != null && mounted) {
      setState(() => _result = 'collection:${result.collectionId}');
    }
  }

  Future<void> _showAlbum() async {
    final result = await AlbumSelectDialog.show(context);
    if (result != null && mounted) {
      setState(() => _result = 'album:${result.albumId}');
    }
  }
}

class _StaticAlbumNotifier extends GalleryAlbumNotifier {
  _StaticAlbumNotifier(this.initialState);

  final GalleryAlbumState initialState;

  @override
  GalleryAlbumState build() => initialState;
}

class _StaticCollectionNotifier extends CollectionNotifier {
  _StaticCollectionNotifier(this.initialState);

  final CollectionState initialState;

  @override
  CollectionState build() => initialState;

  @override
  Future<void> initialize() async {}
}
