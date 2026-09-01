import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
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
