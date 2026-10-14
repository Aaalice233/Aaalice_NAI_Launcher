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
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_aware_widget.dart';

class _ReadyShortcutConfigNotifier extends ShortcutConfigNotifier {
  _ReadyShortcutConfigNotifier(this._config);

  final ShortcutConfig _config;

  @override
  Future<ShortcutConfig> build() async => _config;
}

class _Selection extends ChangeNotifier with CardSelectionCommands {
  SelectionModeState _state = const SelectionModeState();

  @override
  SelectionModeState get state => _state;

  @override
  set state(SelectionModeState value) {
    _state = value;
    notifyListeners();
  }
}

class _Harness {
  _Harness(this.tester, this.selection, this.searchFocus);

  final WidgetTester tester;
  final _Selection selection;
  final FocusNode searchFocus;
  int refreshes = 0;
  late StateSetter _setContentState;
  bool _showRenameField = false;

  Future<void> setRenameFieldVisible(bool visible) async {
    _setContentState(() => _showRenameField = visible);
    await tester.pump();
    await tester.pump();
  }

  Future<void> pressCtrl(LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  Future<void> pressRefresh() async {
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pump();
  }

  Future<void> clickSearchThenOutside() async {
    await tester.tap(_searchField, kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(searchFocus.hasPrimaryFocus, isTrue);
    await tester.tapAt(
      tester.getCenter(find.byKey(_blankKey)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(searchFocus.hasFocus, isFalse);
  }
}

const _orderedIds = ['a', 'b', 'c'];
const _blankKey = ValueKey('blank-area');
const _renameKey = ValueKey('rename-field');
final _searchField = find.byKey(const ValueKey('search-field'));
const _outsideKey = ValueKey('outside-page');

Future<_Harness> _pumpPage(
  WidgetTester tester, {
  ShortcutConfig? config,
}) async {
  final selection = _Selection();
  final searchFocus = FocusNode(debugLabel: 'search');
  addTearDown(selection.dispose);
  addTearDown(searchFocus.dispose);
  final harness = _Harness(tester, selection, searchFocus);

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
        home: Column(
          children: [
            Expanded(child: _buildPage(selection, harness, searchFocus)),
            TextButton(
              key: _outsideKey,
              onPressed: () {},
              child: const Text('outside'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return harness;
}

Widget _buildPage(
  _Selection selection,
  _Harness harness,
  FocusNode searchFocus,
) => ListenableBuilder(
  listenable: selection,
  builder: (context, _) => CardSelectionScope(
    selection: selection.state,
    commands: selection,
    orderedIds: _orderedIds,
    child: CardSelectionPageShortcuts(
      contextType: ShortcutContext.gallery,
      shortcuts: {ShortcutIds.refreshGallery: () => harness.refreshes++},
      child: Material(
        child: StatefulBuilder(
          builder: (context, setState) {
            harness._setContentState = setState;
            return Column(
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    key: const ValueKey('search-field'),
                    focusNode: searchFocus,
                  ),
                ),
                if (harness._showRenameField)
                  const SizedBox(
                    width: 240,
                    child: TextField(key: _renameKey, autofocus: true),
                  ),
                const Expanded(child: SizedBox.expand(key: _blankKey)),
              ],
            );
          },
        ),
      ),
    ),
  ),
);

bool _primaryFocusInsidePage() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<CardSelectionPageShortcuts>() !=
    null;

final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

void main() {
  testWidgets('挂载后页面快捷键与多选按键都在按键冒泡路径上', (tester) async {
    final harness = await _pumpPage(tester);

    expect(_primaryFocusInsidePage(), isTrue);

    await harness.pressRefresh();
    expect(harness.refreshes, 1);

    await harness.pressCtrl(LogicalKeyboardKey.keyA);
    expect(harness.selection.state.isActive, isTrue);
    expect(harness.selection.state.selectedIds, _orderedIds.toSet());

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(harness.selection.state.isActive, isFalse);
  });

  testWidgets('快捷键全局关闭时多选按键照常工作，页面快捷键不触发', (tester) async {
    final harness = await _pumpPage(
      tester,
      config: ShortcutConfig.createDefault().copyWith(enableShortcuts: false),
    );

    await harness.pressRefresh();
    expect(harness.refreshes, 0);

    await harness.pressCtrl(LogicalKeyboardKey.keyA);
    expect(harness.selection.state.selectedIds, _orderedIds.toSet());
  });

  testWidgets('输入框点外部失焦后焦点留在页面内，页面快捷键与多选按键仍然生效', (tester) async {
    final harness = await _pumpPage(tester);

    await harness.clickSearchThenOutside();

    expect(_primaryFocusInsidePage(), isTrue);
    await harness.pressRefresh();
    expect(harness.refreshes, 1);
    await harness.pressCtrl(LogicalKeyboardKey.keyA);
    expect(harness.selection.state.selectedIds, _orderedIds.toSet());
  }, variant: _desktop);

  testWidgets('页面内后出现的 autofocus 输入框获得焦点，移除后快捷键仍然生效', (tester) async {
    final harness = await _pumpPage(tester);

    await harness.setRenameFieldVisible(true);
    final renameField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(_renameKey),
        matching: find.byType(EditableText),
      ),
    );
    expect(renameField.focusNode.hasPrimaryFocus, isTrue);

    await harness.setRenameFieldVisible(false);
    expect(_primaryFocusInsidePage(), isTrue);
    await harness.pressRefresh();
    expect(harness.refreshes, 1);
  });

  testWidgets('输入框聚焦时 Ctrl+A 留给输入框，不触发卡片全选', (tester) async {
    final harness = await _pumpPage(tester);
    harness.searchFocus.requestFocus();
    await tester.pump();

    await harness.pressCtrl(LogicalKeyboardKey.keyA);

    expect(harness.selection.state.isActive, isFalse);
    expect(harness.selection.state.selectedIds, isEmpty);
  });

  testWidgets('Tab 从初始焦点直接进入页面内容，不停在锚点或内层作用域上', (tester) async {
    final harness = await _pumpPage(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(harness.searchFocus.hasPrimaryFocus, isTrue);
  });

  testWidgets('Tab 到页面末尾后离开内层作用域，不在页面内绕圈', (tester) async {
    final harness = await _pumpPage(tester);
    harness.searchFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      Focus.of(tester.element(find.text('outside'))).hasPrimaryFocus,
      isTrue,
    );
  });
}
