import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/data/models/gallery/gallery_category.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/gallery_album_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_category_panel.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_gallery_toolbar.dart';
import 'package:hive/hive.dart';

bool _removedClicked = false;

void _markRemoved() => _removedClicked = true;

class _ToolbarGalleryNotifier extends LocalGalleryNotifier {
  _ToolbarGalleryNotifier(this._initialState, {required this.filteredPaths});

  final LocalGalleryState _initialState;
  final List<String> filteredPaths;

  @override
  LocalGalleryState build() => _initialState;

  @override
  Future<List<String>> getFilteredImagePaths() async => filteredPaths;
}

class _ActiveSelectionNotifier extends LocalGallerySelectionNotifier {
  _ActiveSelectionNotifier(this._initialSelectedIds, {required this.isActive});

  final Set<String> _initialSelectedIds;
  final bool isActive;

  @override
  SelectionModeState build() {
    return SelectionModeState(
      isActive: isActive,
      selectedIds: _initialSelectedIds,
    );
  }
}

/// 本地图库相簿侧栏集成测试（Windows 真实窗口）。
///
/// 覆盖：侧栏层级渲染、相簿选择、应用内卡片拖拽加入相簿（Flutter
/// 拖拽协议），并在窄/宽两个断点截图落盘供视觉验收。
/// OS 级文件拖放（super_drag_and_drop DropRegion）无法在集成测试中
/// 模拟，由人工验收。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final now = DateTime(2026);
  final album = GalleryAlbum(
    id: 'album-1',
    name: '测试相簿',
    imageCount: 3,
    createdAt: now,
    updatedAt: now,
  );
  final childAlbum = GalleryAlbum(
    id: 'album-1-1',
    name: '子相簿',
    parentId: 'album-1',
    imageCount: 1,
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

  final outputDir = Directory('tool/.tmp/windows-e2e');
  final screenshots = <String, GlobalKey>{};

  Widget wrapBoundary(String key, Widget child) {
    final boundaryKey = GlobalKey();
    screenshots[key] = boundaryKey;
    return RepaintBoundary(key: boundaryKey, child: child);
  }

  Widget buildHarness({
    required double width,
    String? selectedAlbumId,
    void Function(String albumId, String imagePath)? onDrop,
    ValueChanged<String?>? onAlbumSelected,
  }) {
    final record = LocalImageRecord(
      path: 'gallery/drag-source.png',
      size: 42,
      modifiedAt: now,
    );

    final panel = LocalGalleryCategoryPanel(
      galleryState: const LocalGalleryState(totalCount: 545),
      categoryState: GalleryCategoryState(categories: [category]),
      albumState: GalleryAlbumState(
        albums: [album, childAlbum],
        selectedAlbumId: selectedAlbumId,
      ),
      favoriteCount: Future.value(1),
      onCreateCategory: () {},
      onCategorySelected: (_) {},
      onCategoryRename: (_, _) async {},
      onCategoryDelete: (_) async {},
      onAddSubCategory: (_) async {},
      onCategoryMove: (_, _) async {},
      onImageDrop: (_, _) async {},
      onSyncWithFileSystem: () async {},
      onCreateAlbum: (_) async {},
      onAlbumSelected: onAlbumSelected ?? (_) {},
      onAlbumRename: (_, _) async {},
      onAlbumDeleteRequest: (_) async {},
      onAddAlbumRequest: (_) async {},
      onAlbumMove: (_, _) async => true,
      onAlbumMoveToSlot: (_, _, _) async => true,
      onCategoryMoveToSlot: (_, _, _) async => true,
      onImageDropToAlbum: (imagePath, albumId) async {
        onDrop?.call(albumId, imagePath);
      },
    );

    final gridTile = Draggable<LocalImageRecord>(
      data: record,
      feedback: SizedBox(
        width: 72,
        height: 72,
        child: Container(color: Colors.blueGrey, child: const FlutterLogo()),
      ),
      childWhenDragging: const SizedBox(width: 72, height: 72),
      child: Container(
        width: 72,
        height: 72,
        color: Colors.blueGrey.shade700,
        child: const Center(
          child: Text(
            '拖我',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );

    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: 760,
              child: Row(
                children: [
                  SizedBox(width: width >= 600 ? 250 : width, child: panel),
                  if (width >= 600)
                    const Expanded(child: ColoredBox(color: Color(0xFF141414))),
                ],
              ),
            ),
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.all(24),
            child: gridTile,
          ),
        ),
      ),
    );
  }

  Future<void> savePng(String name) async {
    final key = screenshots[name]!;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${outputDir.path}/$name.png');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  }

  setUpAll(() async {
    await outputDir.create(recursive: true);
    final hiveDir = Directory.systemTemp.createTempSync('album_it_hive_');
    Hive.init(hiveDir.path);
  });

  testWidgets('宽屏：层级渲染与相簿选择', (tester) async {
    await tester.binding.setSurfaceSize(const Size(840, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? selected;
    await tester.pumpWidget(
      wrapBoundary(
        'wide-hierarchy',
        buildHarness(width: 840, onAlbumSelected: (id) => selected = id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部图片'), findsOneWidget);
    expect(find.text('相簿'), findsOneWidget);
    expect(find.text('测试相簿'), findsOneWidget);
    expect(find.text('文件夹'), findsOneWidget);
    expect(find.text('测试文件夹'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('测试相簿'));
    await tester.pumpAndSettle();
    expect(selected, 'album-1');
    await savePng('wide-hierarchy');
  });

  testWidgets('应用内拖拽卡片到相簿触发加入', (tester) async {
    await tester.binding.setSurfaceSize(const Size(840, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? droppedAlbum;
    String? droppedPath;
    await tester.pumpWidget(
      wrapBoundary(
        'wide-drag-drop',
        buildHarness(
          width: 840,
          onDrop: (albumId, imagePath) {
            droppedAlbum = albumId;
            droppedPath = imagePath;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 展开父相簿以显示子相簿，验证嵌套相簿同样是有效放置区
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('子相簿'), findsOneWidget);

    final dragStart = tester.getCenter(find.text('拖我'));
    final dropTarget = tester.getCenter(find.text('子相簿'));
    final gesture = await tester.startGesture(dragStart);
    // 位移需超过触摸阈值，Draggable 才会开始拖拽
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 100));
    // 分步移动到目标，让 DragTarget 逐帧识别悬停
    final delta = (dropTarget - (dragStart + const Offset(40, 0))) / 10;
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(delta);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(droppedAlbum, 'album-1-1');
    expect(droppedPath, 'gallery/drag-source.png');
    await savePng('wide-drag-drop');
  });

  testWidgets('窄屏：面板内容完整无溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapBoundary('narrow-panel', buildHarness(width: 412)),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部图片'), findsOneWidget);
    expect(find.text('测试相簿'), findsOneWidget);
    expect(find.text('测试文件夹'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await savePng('narrow-panel');
  });

  testWidgets('浏览相簿时多选工具栏的移出按钮可点击', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localGalleryNotifierProvider.overrideWith(
            () => _ToolbarGalleryNotifier(
              const LocalGalleryState(
                currentImages: [],
                filteredCount: 2,
                totalCount: 2,
                totalPages: 1,
                isInitialized: true,
              ),
              filteredPaths: const ['gallery/a.png', 'gallery/b.png'],
            ),
          ),
          localGallerySelectionNotifierProvider.overrideWith(
            () => _ActiveSelectionNotifier(const {
              'gallery/a.png',
            }, isActive: true),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LocalGalleryToolbar(
              enableSearchAutocomplete: false,
              onRemoveFromAlbum: _markRemoved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text('移出相簿');
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_removedClicked, isTrue);
  });
}
