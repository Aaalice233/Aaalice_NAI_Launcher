import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/inline_rename_field.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/fallback_focus_home.dart';

const _outsideKey = ValueKey('outside');

/// 调用方只持有是否在编辑；页面锚点先拿到焦点并作为焦点退回点，对应真实页面的按键层
class _Host extends StatefulWidget {
  const _Host({required this.anchor, required this.framed});

  final FocusNode anchor;
  final bool framed;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String name = '原名';
  bool editing = false;
  final submits = <String>[];
  int cancels = 0;
  final bubbledEscapes = <KeyEvent>[];

  void startEditing() => setState(() => editing = true);

  @override
  Widget build(BuildContext context) => FallbackFocusHome(
    focusNode: widget.anchor,
    child: Focus(
      focusNode: widget.anchor,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          bubbledEscapes.add(event);
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        child: Column(
          children: [
            SizedBox(
              width: 240,
              child: editing
                  ? InlineRenameField(
                      name: name,
                      framed: widget.framed,
                      onSubmit: (value) {
                        submits.add(value);
                        setState(() {
                          name = value;
                          editing = false;
                        });
                      },
                      onCancel: () {
                        cancels++;
                        setState(() => editing = false);
                      },
                    )
                  : Text(name),
            ),
            const SizedBox(key: _outsideKey, width: 240, height: 200),
          ],
        ),
      ),
    ),
  );
}

Finder _field() => find.byType(EditableText);

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(_field());

Future<_HostState> _pumpHost(
  WidgetTester tester,
  FocusNode anchor, {
  required bool framed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _Host(anchor: anchor, framed: framed),
    ),
  );
  await tester.pump();
  expect(anchor.hasPrimaryFocus, isTrue);
  return tester.state<_HostState>(find.byType(_Host));
}

Future<void> _startEditing(WidgetTester tester, _HostState host) async {
  host.startEditing();
  await tester.pump();
  await tester.pump();
  expect(_field(), findsOneWidget);
  expect(_editable(tester).focusNode.hasPrimaryFocus, isTrue);
}

/// 退出编辑后输入框消失，焦点回到页面锚点
void _expectExited(WidgetTester tester, FocusNode anchor) {
  expect(_field(), findsNothing);
  expect(anchor.hasPrimaryFocus, isTrue);
}

void main() {
  late FocusNode anchor;

  setUp(() => anchor = FocusNode(debugLabel: 'anchor'));
  tearDown(() => anchor.dispose());

  for (final framed in [true, false]) {
    final variant = framed ? '带输入色面' : '无输入色面';

    testWidgets('$variant：回车只提交一次，去掉首尾空白', (tester) async {
      final host = await _pumpHost(tester, anchor, framed: framed);
      expect(find.byType(ThemedInput), findsNothing);
      await _startEditing(tester, host);
      expect(find.byType(ThemedInput), framed ? findsOneWidget : findsNothing);
      expect(_editable(tester).controller.text, '原名');

      final editable = _editable(tester);
      tester.testTextInput.enterText('  新名  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      editable.onSubmitted!('再次提交');
      await tester.pumpAndSettle();

      expect(host.submits, ['新名']);
      expect(host.cancels, 0);
      _expectExited(tester, anchor);
    });

    testWidgets('$variant：空白名称按回车不提交并退出', (tester) async {
      final host = await _pumpHost(tester, anchor, framed: framed);
      await _startEditing(tester, host);

      tester.testTextInput.enterText('   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(host.submits, isEmpty);
      expect(host.cancels, 1);
      _expectExited(tester, anchor);
    });

    testWidgets('$variant：Esc 放弃修改并退出，按键不冒泡', (tester) async {
      final host = await _pumpHost(tester, anchor, framed: framed);
      await _startEditing(tester, host);

      tester.testTextInput.enterText('草稿');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(host.bubbledEscapes, isEmpty, reason: 'Esc 应被输入框消费');
      expect(host.submits, isEmpty);
      expect(host.cancels, 1);
      _expectExited(tester, anchor);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });

    for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      testWidgets('$variant：${kind.name} 点输入框外部放弃修改，点输入框内部不退出', (tester) async {
        final host = await _pumpHost(tester, anchor, framed: framed);
        await _startEditing(tester, host);

        tester.testTextInput.enterText('草稿');
        await tester.pump();
        await tester.tap(_field(), kind: kind);
        await tester.pump();
        expect(_field(), findsOneWidget);
        expect(host.cancels, 0);

        await tester.tap(find.byKey(_outsideKey), kind: kind);
        await tester.pumpAndSettle();

        expect(host.submits, isEmpty);
        expect(host.cancels, 1);
        _expectExited(tester, anchor);
      });
    }

    testWidgets('$variant：每次进入编辑都从当前名称开始，草稿不残留', (tester) async {
      final host = await _pumpHost(tester, anchor, framed: framed);
      await _startEditing(tester, host);
      tester.testTextInput.enterText('草稿');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _startEditing(tester, host);
      expect(_editable(tester).controller.text, '原名');
      tester.testTextInput.enterText('新名');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // ignore: invalid_use_of_protected_member
      host.setState(() => host.name = '外部改名');
      await tester.pump();
      await _startEditing(tester, host);
      expect(_editable(tester).controller.text, '外部改名');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(host.submits, ['新名']);
    });
  }
}
