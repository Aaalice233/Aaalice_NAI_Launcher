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
  const widths = [320.0, 600.0, 840.0, 1180.0, 1600.0];

  for (final width in widths) {
    testWidgets(
      'album and collection empty states fit 3x at ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pump(tester, child: const AlbumSelectDialog());
        expect(find.text('Cancel'), findsOneWidget);
        await _scrollAlbumBody(tester);
        expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _pump(tester, child: CollectionSelectDialog(theme: ThemeData()));
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('album controls remain reachable at 320px height', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(
      tester,
      textScaler: TextScaler.noScaling,
      albumState: GalleryAlbumState(albums: [_album]),
      child: const AlbumSelectDialog(),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('New Album').hitTestable(), findsOneWidget);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    await _scrollAlbumBody(tester);
    expect(find.text('Portraits'), findsOneWidget);
    _expectVisibleAlbumArea(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('album controls remain reachable at 3x text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(
      tester,
      albumState: GalleryAlbumState(albums: [_album]),
      child: const AlbumSelectDialog(),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('New Album').hitTestable(), findsOneWidget);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    await _scrollAlbumBody(tester);
    expect(find.text('Portraits'), findsOneWidget);
    _expectVisibleAlbumArea(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('album controls remain reachable with IME insets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(
      tester,
      textScaler: TextScaler.noScaling,
      viewInsets: const EdgeInsets.only(bottom: 300),
      albumState: GalleryAlbumState(albums: [_album]),
      child: const AlbumSelectDialog(),
    );

    expect(find.byIcon(Icons.search).hitTestable(), findsOneWidget);
    expect(find.text('Portraits').hitTestable(), findsOneWidget);
    expect(find.text('New Album').hitTestable(), findsOneWidget);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('album and collection search-empty states remain reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(
      tester,
      albumState: GalleryAlbumState(albums: [_album]),
      child: const AlbumSelectDialog(),
    );
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    await _scrollAlbumBody(tester);
    expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(
      tester,
      collectionState: CollectionState(collections: [_collection]),
      child: CollectionSelectDialog(theme: ThemeData()),
    );
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('No matching collections found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      name: '320px high',
      size: const Size(600, 320),
      viewInsets: EdgeInsets.zero,
    ),
    (
      name: 'IME leaves 320px',
      size: const Size(600, 640),
      viewInsets: const EdgeInsets.only(bottom: 320),
    ),
  ]) {
    testWidgets(
      'collection dialog remains usable at 3x with ${scenario.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(scenario.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pump(
          tester,
          collectionState: CollectionState(collections: [_collection]),
          viewInsets: scenario.viewInsets,
          child: CollectionSelectDialog(theme: ThemeData()),
        );

        final scrollView = find.byKey(const Key('collection-select-scroll'));
        var searchField = find.byType(TextField);
        expect(searchField.hitTestable(), findsOneWidget);

        await tester.enterText(searchField, 'missing');
        await tester.pump();
        final emptyState = find.text('No matching collections found');
        await tester.ensureVisible(emptyState);
        await tester.pump();
        expect(emptyState.hitTestable(), findsOneWidget);

        await tester.drag(scrollView, const Offset(0, 1000));
        await tester.pump();
        searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, '');
        await tester.pump();
        final collection = find.text('Landscapes');
        await tester.ensureVisible(collection);
        await tester.pump();
        expect(collection.hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.text('Cancel'));
        await tester.pump();
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final _album = GalleryAlbum(
  id: 'album',
  name: 'Portraits',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _collection = ImageCollection(
  id: 'collection',
  name: 'Landscapes',
  description: 'Wide landscape references',
  createdAt: DateTime(2026),
);

Future<void> _scrollAlbumBody(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
  await tester.pump();
}

void _expectVisibleAlbumArea(WidgetTester tester) {
  final viewport = tester.getRect(find.byType(CustomScrollView));
  final albumTile = tester.getRect(find.byType(ListTile));
  expect(viewport.intersect(albumTile).isEmpty, isFalse);
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  GalleryAlbumState albumState = const GalleryAlbumState(),
  CollectionState collectionState = const CollectionState(),
  TextScaler textScaler = const TextScaler.linear(3),
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        galleryAlbumNotifierProvider.overrideWith(
          () => _StaticAlbumNotifier(albumState),
        ),
        collectionNotifierProvider.overrideWith(
          () => _StaticCollectionNotifier(collectionState),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: textScaler, viewInsets: viewInsets),
          child: child!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
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
