import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/data/models/gallery/gallery_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/gallery_album_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_category_panel.dart';

void main() {
  final now = DateTime(2026);
  final album = GalleryAlbum(
    id: 'album-1',
    name: '测试相簿',
    imageCount: 3,
    createdAt: now,
    updatedAt: now,
  );
  final category = GalleryCategory(
    id: 'folder-1',
    name: '测试文件夹',
    folderPath: '测试文件夹',
    imageCount: 7,
    createdAt: now,
    updatedAt: now,
  );

  Widget buildPanel({
    GalleryAlbumState? albumState,
    GalleryCategoryState? categoryState,
    ValueChanged<String?>? onAlbumSelected,
    ValueChanged<String?>? onCategorySelected,
    bool modal = false,
    ScrollController? scrollController,
  }) {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: modal ? 420 : 250,
              height: 760,
              child: LocalGalleryCategoryPanel(
                galleryState: const LocalGalleryState(totalCount: 545),
                categoryState:
                    categoryState ??
                    GalleryCategoryState(categories: [category]),
                albumState: albumState ?? GalleryAlbumState(albums: [album]),
                favoriteCount: Future.value(1),
                modal: modal,
                scrollController: scrollController,
                onCreateCategory: () {},
                onCategorySelected: onCategorySelected ?? (_) {},
                onCategoryRename: (_, _) async {},
                onCategoryDelete: (_) async {},
                onAddSubCategory: (_) async {},
                onCategoryMove: (_, _) async {},
                onCategoryReorder: (_, _, _) async {},
                onImageDrop: (_, _) async {},
                onSyncWithFileSystem: () async {},
                onCreateAlbum: (_) async {},
                onAlbumSelected: onAlbumSelected ?? (_) {},
                onAlbumRenameRequest: (_) async {},
                onAlbumDeleteRequest: (_) async {},
                onAddAlbumRequest: (_) async {},
                onAlbumMove: (_, _) async => true,
                onImageDropToAlbum: (_, _) async {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('侧栏按全部图像、相簿、文件夹排列并默认展开', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.pumpAndSettle();

    final allImagesY = tester.getTopLeft(find.text('全部图片')).dy;
    final albumsY = tester.getTopLeft(find.text('相簿')).dy;
    final favoriteY = tester.getTopLeft(find.text('收藏')).dy;
    final foldersY = tester.getTopLeft(find.text('文件夹')).dy;
    final categoryY = tester.getTopLeft(find.text('测试文件夹')).dy;

    expect(allImagesY, lessThan(albumsY));
    expect(albumsY, lessThan(favoriteY));
    expect(favoriteY, lessThan(foldersY));
    expect(foldersY, lessThan(categoryY));
    expect(find.text('测试相簿'), findsOneWidget);
    expect(find.text('新建'), findsNWidgets(2));
    expect(find.byType(Divider), findsNothing);

    final allImagesSize = tester.getSize(
      find.byKey(const ValueKey('local-gallery-all-images')),
    );
    final albumsHeaderSize = tester.getSize(
      find.byKey(const ValueKey('local-gallery-albums-toggle')),
    );
    expect(allImagesSize.height, albumsHeaderSize.height);

    final albumBottom = tester.getBottomLeft(find.text('测试相簿')).dy;
    expect(foldersY - albumBottom, lessThan(48));
  });

  testWidgets('相簿和文件夹标题有分组背景和悬浮反馈', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.pumpAndSettle();

    const albumKey = ValueKey('local-gallery-albums-toggle');
    final context = tester.element(find.byKey(albumKey));
    final colorScheme = Theme.of(context).colorScheme;

    Color sectionColor() {
      final container = tester.widget<AnimatedContainer>(find.byKey(albumKey));
      return (container.decoration! as BoxDecoration).color!;
    }

    expect(sectionColor(), colorScheme.onSurface.withValues(alpha: 0.06));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(albumKey)));
    await tester.pumpAndSettle();

    expect(sectionColor(), colorScheme.onSurface.withValues(alpha: 0.11));
  });

  testWidgets('相簿和文件夹区域可以独立收起与展开', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('local-gallery-albums-toggle')));
    await tester.pump();

    expect(find.text('收藏'), findsNothing);
    expect(find.text('测试相簿'), findsNothing);
    expect(find.text('测试文件夹'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('local-gallery-folders-toggle')),
    );
    await tester.pump();

    expect(find.text('测试文件夹'), findsNothing);
    expect(find.text('全部图片'), findsOneWidget);
    expect(find.text('相簿'), findsOneWidget);
    expect(find.text('文件夹'), findsOneWidget);
  });

  testWidgets('从文件夹选择全部图像会走统一清空分类入口', (tester) async {
    String? selectedCategory = 'not-called';
    var albumSelectionCalled = false;

    await tester.pumpWidget(
      buildPanel(
        categoryState: GalleryCategoryState(
          categories: [category],
          selectedCategoryId: category.id,
        ),
        onCategorySelected: (id) => selectedCategory = id,
        onAlbumSelected: (_) => albumSelectionCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('local-gallery-all-images')));
    await tester.pump();

    expect(selectedCategory, isNull);
    expect(albumSelectionCalled, isFalse);
  });

  testWidgets('modal 面板保留相簿和文件夹标题及全部操作层级', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      buildPanel(modal: true, scrollController: scrollController),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部图片'), findsOneWidget);
    expect(find.text('相簿'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('文件夹'), findsOneWidget);
    expect(find.text('新建'), findsNWidgets(2));
    expect(scrollController.hasClients, isTrue);
    expect(tester.takeException(), isNull);
  });
}
