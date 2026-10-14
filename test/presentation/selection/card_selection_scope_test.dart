import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/selection/card_selection.dart';
import 'package:nai_launcher/presentation/selection/card_selection_scope.dart';

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

const _orderedIds = ['a', 'b'];
const _searchKey = ValueKey('search-field');
const _gridKey = ValueKey('card-grid');

/// 搜索框与卡片区是兄弟，对应资料库页面：多选处理器只包住卡片区
Future<_Selection> _pumpLibrary(
  WidgetTester tester, {
  required bool reclaimFallbackFocus,
}) async {
  final selection = _Selection();
  addTearDown(selection.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: ListenableBuilder(
          listenable: selection,
          builder: (context, _) => CardSelectionScope(
            selection: selection.state,
            commands: selection,
            orderedIds: _orderedIds,
            child: Column(
              children: [
                const SizedBox(width: 240, child: TextField(key: _searchKey)),
                Expanded(
                  child: CardSelectionShortcuts(
                    reclaimFallbackFocus: reclaimFallbackFocus,
                    child: const SizedBox.expand(key: _gridKey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return selection;
}

Future<void> _clickSearchThenGrid(WidgetTester tester) async {
  await tester.tap(find.byKey(_searchKey), kind: PointerDeviceKind.mouse);
  await tester.pump();
  await tester.tapAt(
    tester.getCenter(find.byKey(_gridKey)),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
}

Future<void> _pressSelectAll(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

void main() {
  testWidgets('页面焦点归属的多选处理器在兄弟输入框失焦后收回焦点', (tester) async {
    final selection = await _pumpLibrary(tester, reclaimFallbackFocus: true);

    await _clickSearchThenGrid(tester);
    await _pressSelectAll(tester);

    expect(selection.state.selectedIds, _orderedIds.toSet());
  }, variant: _desktop);

  testWidgets('未声明为焦点归属时失焦落点不变', (tester) async {
    final selection = await _pumpLibrary(tester, reclaimFallbackFocus: false);

    await _clickSearchThenGrid(tester);
    await _pressSelectAll(tester);

    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
    expect(selection.state.selectedIds, isEmpty);
  }, variant: _desktop);
}
