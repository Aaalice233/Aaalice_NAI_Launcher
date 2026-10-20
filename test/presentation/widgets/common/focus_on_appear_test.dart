import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/focus_on_appear.dart';

/// 页面锚点先拿到焦点，之后再出现内联编辑框，对应重命名入口
class _Page extends StatefulWidget {
  const _Page({required this.anchor, required this.buildEditor});

  final FocusNode anchor;
  final Widget Function() buildEditor;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  bool editing = false;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: widget.anchor,
    autofocus: true,
    child: Material(
      child: Column(children: [if (editing) widget.buildEditor()]),
    ),
  );
}

Future<_PageState> _pumpPage(
  WidgetTester tester,
  FocusNode anchor,
  Widget Function() buildEditor,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _Page(anchor: anchor, buildEditor: buildEditor),
    ),
  );
  await tester.pump();
  expect(anchor.hasPrimaryFocus, isTrue);
  return tester.state<_PageState>(find.byType(_Page));
}

Future<void> _startEditing(WidgetTester tester, _PageState page) async {
  // ignore: invalid_use_of_protected_member
  page.setState(() => page.editing = true);
  await tester.pump();
  await tester.pump();
}

void main() {
  late FocusNode anchor;
  late FocusNode field;

  setUp(() {
    anchor = FocusNode(debugLabel: 'anchor');
    field = FocusNode(debugLabel: 'field');
  });

  tearDown(() {
    anchor.dispose();
    field.dispose();
  });

  testWidgets('FocusOnAppear 在编辑框出现后把焦点交给它', (tester) async {
    final page = await _pumpPage(
      tester,
      anchor,
      () => FocusOnAppear(child: TextField(focusNode: field)),
    );

    await _startEditing(tester, page);

    expect(field.hasPrimaryFocus, isTrue);
  });

  testWidgets('输入框优先于排在前面的其他可聚焦控件', (tester) async {
    final page = await _pumpPage(
      tester,
      anchor,
      () => FocusOnAppear(
        child: Row(
          children: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.close)),
            Expanded(child: TextField(focusNode: field)),
          ],
        ),
      ),
    );

    await _startEditing(tester, page);

    expect(field.hasPrimaryFocus, isTrue);
  });

  group('FocusOnAppear.self', () {
    late int escapes;
    Widget popup() => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => escapes++,
      },
      child: FocusOnAppear.self(child: TextField(focusNode: field)),
    );

    setUp(() => escapes = 0);

    testWidgets('出现后焦点停在弹层本身，外层 Esc 绑定立即可用', (tester) async {
      final page = await _pumpPage(tester, anchor, popup);

      await _startEditing(tester, page);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(field.hasFocus, isFalse);
      expect(anchor.hasPrimaryFocus, isFalse);
      expect(escapes, 1);
    });

    testWidgets('内部输入框失焦后焦点收回到弹层，Esc 仍可用', (tester) async {
      final page = await _pumpPage(tester, anchor, popup);
      await _startEditing(tester, page);
      field.requestFocus();
      await tester.pump();
      expect(field.hasPrimaryFocus, isTrue);

      field.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(escapes, 1);
    });

    testWidgets('弹层移除后焦点回到页面原持有者', (tester) async {
      final page = await _pumpPage(tester, anchor, popup);
      await _startEditing(tester, page);
      expect(anchor.hasPrimaryFocus, isFalse);

      // ignore: invalid_use_of_protected_member
      page.setState(() => page.editing = false);
      await tester.pump();

      expect(anchor.hasPrimaryFocus, isTrue);
    });
  });
}
