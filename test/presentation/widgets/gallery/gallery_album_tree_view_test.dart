import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/desktop_window_frame.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_album_tree_view.dart';

GalleryAlbum _album(String id, {String? parentId}) => GalleryAlbum(
  id: id,
  name: id,
  parentId: parentId,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Widget _host(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(width: 260, height: 760, child: child)),
  );
}

/// 相簿树交互回归：桌面右键菜单执行动作、就地重命名、新相簿自动展开。
/// （此前桌面右键菜单漏注册选择回调，四个操作全部无效。）
void main() {
  testWidgets('收藏项注册为本地图像拖拽目标', (tester) async {
    await tester.pumpWidget(
      _host(
        GalleryAlbumTreeView(
          albums: const [],
          totalImageCount: 1,
          favoriteCount: 0,
          onAlbumSelected: (_) {},
          onImageFavoriteDrop: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final favorite = find.byKey(const ValueKey('local-gallery-favorites'));
    expect(favorite, findsOneWidget);
    expect(
      find.ancestor(of: favorite, matching: find.byType(DropRegion)),
      findsOneWidget,
    );
  });

  testWidgets('右键菜单的四个操作各自执行对应回调', (tester) async {
    String? renamedId;
    String? renamedNewName;
    String? addSubParentId;
    String? deletedId;
    var moveToRootCalled = false;

    await tester.pumpWidget(
      _host(
        GalleryAlbumTreeView(
          albums: [_album('first')],
          totalImageCount: 3,
          onAlbumSelected: (_) {},
          onAlbumRename: (id, newName) async {
            renamedId = id;
            renamedNewName = newName;
          },
          onAddAlbumRequest: (parentId) async {
            addSubParentId = parentId;
          },
          onAlbumMove: (id, _) async {
            moveToRootCalled = true;
            return true;
          },
          onAlbumDeleteRequest: (id) async {
            deletedId = id;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openContextMenu() async {
      await tester.tap(find.text('first'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
    }

    // 新建子相簿：应携带父相簿 id（本次回归的核心断言）
    await openContextMenu();
    await tester.tap(find.text('新建子相簿'));
    await tester.pumpAndSettle();
    expect(addSubParentId, 'first');

    // 删除
    await openContextMenu();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(deletedId, 'first');

    // 根级相簿不显示“移到根级”
    await openContextMenu();
    expect(find.text('移到根级'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // 就地重命名：菜单触发输入框，提交新名字
    await openContextMenu();
    await tester.tap(find.text('重命名'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '新名字');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(renamedId, 'first');
    expect(renamedNewName, '新名字');
    expect(moveToRootCalled, isFalse);
  });

  testWidgets('右键菜单出现在点击位置（壳层偏移 overlay 下无偏移）', (tester) async {
    // 生产壳层结构：真实 DesktopWindowFrame 提供 40px 自绘标题栏，
    // 分支 Navigator 在 200px 主导航栏右侧。showMenu 的 position 相对
    // 最近 Overlay，直接传手势窗口全局坐标会让菜单整体偏移一个壳层
    // 边距（相簿树右键菜单偏移 bug）。
    Widget offsetHost(Widget child) {
      return MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DesktopWindowFrame(
            enabled: true,
            child: Row(
              children: [
                const SizedBox(width: 200),
                Expanded(
                  child: Navigator(
                    onGenerateRoute: (_) =>
                        PageRouteBuilder(pageBuilder: (_, __, ___) => child),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      offsetHost(
        GalleryAlbumTreeView(
          albums: [_album('first')],
          totalImageCount: 0,
          onAlbumSelected: (_) {},
          onAlbumRename: (_, _) async {},
          onAddAlbumRequest: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 点击内容区左半侧的相簿行（与生产中相簿面板位于内容区左侧一致），
    // 菜单应从点击点向右下展开。
    final rowCenter = tester.getCenter(find.text('first'));
    final tapPosition = Offset(280, rowCenter.dy);
    final gesture = await tester.startGesture(
      tapPosition,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    // 用菜单面板（菜单项最近的 Material 祖先）断言面板原点贴合点击点
    final menuPanel = find
        .ancestor(
          of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
          matching: find.byType(Material),
        )
        .first;
    expect(menuPanel, findsOneWidget);
    final panelTopLeft = tester.getTopLeft(menuPanel);
    expect(panelTopLeft.dx, closeTo(tapPosition.dx, 0.01));
    expect(panelTopLeft.dy, closeTo(tapPosition.dy, 0.01));
  });

  testWidgets('子相簿的新增使其祖先链自动展开并立即可见', (tester) async {
    await tester.pumpWidget(
      _host(
        GalleryAlbumTreeView(
          albums: [_album('root')],
          totalImageCount: 0,
          onAlbumSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 收起状态下子相簿不可见
    expect(find.text('child'), findsNothing);

    await tester.pumpWidget(
      _host(
        GalleryAlbumTreeView(
          albums: [
            _album('root'),
            _album('child', parentId: 'root'),
          ],
          totalImageCount: 0,
          onAlbumSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 新增子相簿后父级自动展开，子相簿立即可见
    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('深层嵌套的新相簿展开整条祖先链', (tester) async {
    await tester.pumpWidget(
      _host(
        GalleryAlbumTreeView(
          albums: [
            _album('root'),
            _album('mid', parentId: 'root'),
          ],
          totalImageCount: 0,
          onAlbumSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('mid'), findsNothing);

    await tester.pumpWidget(
      _host(
        GalleryAlbumTreeView(
          albums: [
            _album('root'),
            _album('mid', parentId: 'root'),
            _album('leaf', parentId: 'mid'),
          ],
          totalImageCount: 0,
          onAlbumSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('mid'), findsOneWidget);
    expect(find.text('leaf'), findsOneWidget);
  });
}
