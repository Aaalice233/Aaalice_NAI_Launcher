import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/gallery/gallery_album.dart';
import 'package:nai_launcher/data/models/gallery/gallery_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/gallery_album_provider.dart';
import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_category_panel.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_shortcuts.dart';
import 'package:nai_launcher/presentation/selection/card_selection.dart';
import 'package:nai_launcher/presentation/selection/card_selection_scope.dart';

class _DefaultShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _Selection with CardSelectionCommands {
  @override
  SelectionModeState state = const SelectionModeState();
}

const _searchKey = ValueKey('search');

/// 与本地图库页同构：分类面板和搜索框都在页面按键层的内层作用域里
Future<List<(String, String, String)>> _pumpGallery(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1180, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final renames = <(String, String, String)>[];
  final selection = _Selection();
  final now = DateTime(2026);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          _DefaultShortcutConfigNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardSelectionScope(
          selection: selection.state,
          commands: selection,
          orderedIds: const ['image'],
          child: LocalGalleryShortcuts(
            shortcuts: const {},
            canUndo: false,
            canRedo: false,
            onUndo: () {},
            onRedo: () {},
            child: Material(
              child: Row(
                children: [
                  SizedBox(
                    width: 250,
                    height: 760,
                    child: LocalGalleryCategoryPanel(
                      galleryState: const LocalGalleryState(totalCount: 1),
                      categoryState: GalleryCategoryState(
                        categories: [
                          GalleryCategory(
                            id: 'folder',
                            name: '测试文件夹',
                            folderPath: '测试文件夹',
                            imageCount: 1,
                            createdAt: now,
                            updatedAt: now,
                          ),
                        ],
                      ),
                      albumState: GalleryAlbumState(
                        albums: [
                          GalleryAlbum(
                            id: 'album',
                            name: '测试相簿',
                            imageCount: 1,
                            createdAt: now,
                            updatedAt: now,
                          ),
                        ],
                      ),
                      favoriteCount: Future.value(0),
                      onCreateCategory: () {},
                      onCategorySelected: (_) {},
                      onCategoryRename: (id, name) async =>
                          renames.add(('folder', id, name)),
                      onCategoryDelete: (_) async {},
                      onAddSubCategory: (_) async {},
                      onCategoryMove: (_, _) async {},
                      onImagesDrop: (_, _) async {},
                      onSyncWithFileSystem: () async {},
                      onCreateAlbum: (_) async {},
                      onAlbumSelected: (_) {},
                      onAlbumRename: (id, name) async =>
                          renames.add(('album', id, name)),
                      onAlbumDeleteRequest: (_) async {},
                      onAddAlbumRequest: (_) async {},
                      onAlbumMove: (_, _) async => true,
                      onAlbumMoveToSlot: (_, _, _) async => true,
                      onCategoryMoveToSlot: (_, _, _) async => true,
                      onImagesDropToAlbum: (_, _) async {},
                    ),
                  ),
                  const Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 240,
                        child: TextField(key: _searchKey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return renames;
}

Finder _renameField() => find.descendant(
  of: find.byType(LocalGalleryCategoryPanel),
  matching: find.byType(EditableText),
);

EditableText _renameEditable(WidgetTester tester) =>
    tester.widget<EditableText>(_renameField());

Future<void> _openRename(WidgetTester tester, String label) async {
  await tester.tap(
    find.text(label),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('重命名').last);
  // 菜单项在菜单关闭后延时切换到编辑态
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
  expect(_renameField(), findsOneWidget);
  expect(_renameEditable(tester).focusNode.hasPrimaryFocus, isTrue);
}

/// 再次进入编辑时输入框显示当前名称，随后用 Esc 关闭以停掉光标闪烁计时器
Future<void> _expectReopensWithName(WidgetTester tester, String label) async {
  await _openRename(tester, label);
  expect(_renameEditable(tester).controller.text, label);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(_renameField(), findsNothing);
}

/// 路由作用域位于分类面板与页面级 Esc 绑定之间，冒泡的 Esc 必先经过它
List<KeyEvent> _recordBubbledEscapes(WidgetTester tester) {
  final scope = FocusScope.of(
    tester.element(find.byType(LocalGalleryCategoryPanel)),
  );
  final previousHandler = scope.onKeyEvent;
  final escapes = <KeyEvent>[];
  scope.onKeyEvent = (node, event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      escapes.add(event);
    }
    return KeyEventResult.ignored;
  };
  addTearDown(() => scope.onKeyEvent = previousHandler);
  return escapes;
}

void main() {
  for (final (kind, label, id) in const [
    ('album', '测试相簿', 'album'),
    ('folder', '测试文件夹', 'folder'),
  ]) {
    testWidgets('搜索框留在页面作用域焦点历史里时，右键重命名$label仍直接可输入', (tester) async {
      final renames = await _pumpGallery(tester);
      final search = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(_searchKey),
          matching: find.byType(EditableText),
        ),
      );
      await tester.tap(find.byKey(_searchKey), kind: PointerDeviceKind.mouse);
      await tester.pump();
      // 外壳切回分支时只聚焦输入框所在作用域，输入框仍是该作用域记住的子节点
      search.focusNode.enclosingScope!.requestScopeFocus();
      await tester.pump();

      await tester.tap(
        find.text(label),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名').last);
      // 菜单项在菜单关闭后延时切换到编辑态
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      final rename = tester.widget<EditableText>(
        find.byWidgetPredicate(
          (widget) => widget is EditableText && widget.controller.text == label,
        ),
      );
      expect(rename.focusNode.hasPrimaryFocus, isTrue);

      tester.testTextInput.enterText('新名字');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(renames, [(kind, id, '新名字')]);
      expect(search.controller.text, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('重命名$label时按 Esc 放弃修改并退出，按键不冒泡给页面', (tester) async {
      final renames = await _pumpGallery(tester);
      await _openRename(tester, label);
      final escapes = _recordBubbledEscapes(tester);

      tester.testTextInput.enterText('草稿');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(escapes, isEmpty, reason: 'Esc 应被重命名框消费');
      expect(_renameField(), findsNothing);
      expect(renames, isEmpty);
      await _expectReopensWithName(tester, label);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('重命名$label时点外部放弃修改，再次进入显示当前名称', (tester) async {
      final renames = await _pumpGallery(tester);
      await _openRename(tester, label);

      tester.testTextInput.enterText('草稿');
      await tester.pump();
      await tester.tapAt(const Offset(800, 600), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(_renameField(), findsNothing);
      expect(renames, isEmpty);
      await _expectReopensWithName(tester, label);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('重命名$label时空白名称按回车不提交，再次进入显示当前名称', (tester) async {
      final renames = await _pumpGallery(tester);
      await _openRename(tester, label);

      tester.testTextInput.enterText('   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(_renameField(), findsNothing);
      expect(renames, isEmpty);
      await _expectReopensWithName(tester, label);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
