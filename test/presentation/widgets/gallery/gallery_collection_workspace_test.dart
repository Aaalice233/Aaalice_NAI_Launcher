import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';

void main() {
  testWidgets('collection chrome keeps one full-width toolbar above regions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GalleryCollectionWorkspace(
            toolbar: GalleryCollectionToolbarSurface(
              key: Key('toolbar'),
              child: Text('页面'),
            ),
            sidebar: SizedBox(
              key: Key('sidebar'),
              width: GalleryCollectionChrome.sidebarWidth,
              child: GallerySidebarSurface(child: SizedBox.expand()),
            ),
            body: ColoredBox(key: Key('body'), color: Colors.black),
            footer: SizedBox(key: Key('footer'), height: 56),
          ),
        ),
      ),
    );

    final toolbar = tester.getRect(find.byKey(const Key('toolbar')));
    final sidebar = tester.getRect(find.byKey(const Key('sidebar')));
    final body = tester.getRect(find.byKey(const Key('body')));
    final footer = tester.getRect(find.byKey(const Key('footer')));

    expect(toolbar, const Rect.fromLTWH(0, 0, 800, 72));
    expect(sidebar.top, toolbar.bottom);
    expect(sidebar.width, GalleryCollectionChrome.sidebarWidth);
    expect(body.top, toolbar.bottom);
    expect(footer.bottom, 600);
    expect(find.byType(Divider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection chrome resolves visible tonal layers', (
    tester,
  ) async {
    const canvas = Color(0xFF111111);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ).copyWith(
          surface: canvas,
          surfaceContainerLow: canvas,
          surfaceContainer: canvas,
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: colorScheme),
        home: const Scaffold(
          body: Column(
            children: [
              GalleryCollectionToolbarSurface(child: Text('工具栏')),
              Expanded(child: GallerySidebarSurface(child: SizedBox.expand())),
            ],
          ),
        ),
      ),
    );

    final toolbar = tester.widget<Container>(
      find.descendant(
        of: find.byType(GalleryCollectionToolbarSurface),
        matching: find.byType(Container),
      ),
    );
    final sidebar = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(GallerySidebarSurface),
        matching: find.byType(ColoredBox),
      ),
    );

    expect(toolbar.color, isNot(canvas));
    expect(sidebar.color, isNot(canvas));
    expect(sidebar.color, isNot(toolbar.color));
  });
}
