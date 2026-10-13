import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/selection/card_selection.dart';
import 'package:nai_launcher/presentation/selection/card_selection_scope.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_shortcuts.dart';

class _ReadyShortcutConfigNotifier extends ShortcutConfigNotifier {
  _ReadyShortcutConfigNotifier(this._config);

  final ShortcutConfig _config;

  @override
  Future<ShortcutConfig> build() async => _config;
}

class _Selection with CardSelectionCommands {
  @override
  SelectionModeState state = const SelectionModeState();
}

class _Harness {
  _Harness(this.tester, this.searchFocus, this.searchController);

  final WidgetTester tester;
  final FocusNode searchFocus;
  final TextEditingController searchController;
  late StateSetter _setHostState;
  bool canUndo = true;
  bool canRedo = true;
  int undos = 0;
  int redos = 0;
  int refreshes = 0;

  Future<void> update(void Function() change) async {
    _setHostState(change);
    await tester.pump();
  }

  Future<void> press(
    LogicalKeyboardKey key, {
    bool control = false,
    bool meta = false,
    bool shift = false,
  }) async {
    final modifiers = [
      if (control) LogicalKeyboardKey.controlLeft,
      if (meta) LogicalKeyboardKey.metaLeft,
      if (shift) LogicalKeyboardKey.shiftLeft,
    ];
    for (final modifier in modifiers) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyEvent(key);
    for (final modifier in modifiers.reversed) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pump();
  }
}

const _blankKey = ValueKey('blank-area');
const _searchKey = ValueKey('search-field');

Future<_Harness> _pumpGallery(
  WidgetTester tester, {
  ShortcutConfig? config,
}) async {
  final searchFocus = FocusNode(debugLabel: 'search');
  final searchController = TextEditingController();
  addTearDown(searchFocus.dispose);
  addTearDown(searchController.dispose);
  final harness = _Harness(tester, searchFocus, searchController);
  final selection = _Selection();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          () => _ReadyShortcutConfigNotifier(
            config ?? ShortcutConfig.createDefault(),
          ),
        ),
      ],
      child: MaterialApp(
        home: CardSelectionScope(
          selection: selection.state,
          commands: selection,
          orderedIds: const ['a', 'b'],
          child: StatefulBuilder(
            builder: (context, setState) {
              harness._setHostState = setState;
              return LocalGalleryShortcuts(
                shortcuts: {
                  ShortcutIds.refreshGallery: () => harness.refreshes++,
                },
                canUndo: harness.canUndo,
                canRedo: harness.canRedo,
                onUndo: () => harness.undos++,
                onRedo: () => harness.redos++,
                child: Material(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 240,
                        child: TextField(
                          key: _searchKey,
                          focusNode: searchFocus,
                          controller: searchController,
                        ),
                      ),
                      const Expanded(child: SizedBox.expand(key: _blankKey)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return harness;
}

final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

void main() {
  testWidgets('快捷键启用时 Ctrl+Z 撤销，Ctrl+Shift+Z 与 Ctrl+Y 重做，画廊快捷键同时可用', (
    tester,
  ) async {
    final harness = await _pumpGallery(tester);

    await harness.press(LogicalKeyboardKey.keyZ, control: true);
    expect(harness.undos, 1);
    expect(harness.redos, 0);

    await harness.press(LogicalKeyboardKey.keyZ, control: true, shift: true);
    await harness.press(LogicalKeyboardKey.keyY, control: true);
    expect(harness.undos, 1);
    expect(harness.redos, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    expect(harness.refreshes, 1);
  }, variant: _desktop);

  testWidgets('快捷键全局关闭时撤销/重做仍然可用', (tester) async {
    final harness = await _pumpGallery(
      tester,
      config: ShortcutConfig.createDefault().copyWith(enableShortcuts: false),
    );

    await harness.press(LogicalKeyboardKey.keyZ, control: true);
    await harness.press(LogicalKeyboardKey.keyY, control: true);

    expect(harness.undos, 1);
    expect(harness.redos, 1);
  }, variant: _desktop);

  testWidgets('没有可撤销或可重做的记录时不触发回调', (tester) async {
    final harness = await _pumpGallery(tester);
    await harness.update(() {
      harness.canUndo = false;
      harness.canRedo = false;
    });

    await harness.press(LogicalKeyboardKey.keyZ, control: true);
    await harness.press(LogicalKeyboardKey.keyY, control: true);
    expect(harness.undos, 0);
    expect(harness.redos, 0);

    await harness.update(() => harness.canUndo = true);
    await harness.press(LogicalKeyboardKey.keyZ, control: true);
    expect(harness.undos, 1, reason: '重建后按最新的可撤销状态分派');
  }, variant: _desktop);

  testWidgets('搜索框聚焦时撤销键交给输入框自身，不触发批量撤销', (tester) async {
    final harness = await _pumpGallery(tester);
    await tester.tap(find.byKey(_searchKey), kind: PointerDeviceKind.mouse);
    await tester.pump();
    // UndoHistory 按节流记录，分两次输入才有可撤销的上一步
    await tester.enterText(find.byKey(_searchKey), 'c');
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byKey(_searchKey), 'cat');
    await tester.pump(const Duration(seconds: 1));

    await harness.press(LogicalKeyboardKey.keyZ, control: true);
    expect(harness.searchController.text, 'c', reason: '输入框自身完成撤销');
    await harness.press(LogicalKeyboardKey.keyZ, control: true, shift: true);
    expect(harness.searchController.text, 'cat', reason: '输入框自身完成重做');
    await harness.press(LogicalKeyboardKey.keyY, control: true);

    expect(harness.undos, 0);
    expect(harness.redos, 0);
  }, variant: _desktop);

  testWidgets('搜索框点外部失焦后 Ctrl+Z 仍触发批量撤销', (tester) async {
    final harness = await _pumpGallery(tester);
    await tester.tap(find.byKey(_searchKey), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(harness.searchFocus.hasPrimaryFocus, isTrue);
    await tester.tapAt(
      tester.getCenter(find.byKey(_blankKey)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(harness.searchFocus.hasFocus, isFalse);

    await harness.press(LogicalKeyboardKey.keyZ, control: true);

    expect(harness.undos, 1);
  }, variant: _desktop);

  testWidgets('macOS 使用 Cmd+Z 与 Cmd+Shift+Z，Ctrl 组合不触发', (tester) async {
    final harness = await _pumpGallery(tester);

    await harness.press(LogicalKeyboardKey.keyZ, control: true);
    await harness.press(LogicalKeyboardKey.keyY, control: true);
    expect(harness.undos, 0);
    expect(harness.redos, 0);

    await harness.press(LogicalKeyboardKey.keyZ, meta: true);
    await harness.press(LogicalKeyboardKey.keyZ, meta: true, shift: true);
    expect(harness.undos, 1);
    expect(harness.redos, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('按住撤销键产生的重复事件不会连续撤销', (tester) async {
    final harness = await _pumpGallery(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(harness.undos, 1);
  }, variant: _desktop);
}
