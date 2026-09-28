import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/keyboard_dismiss_region.dart';

void main() {
  testWidgets('点击输入框外的空白区域会取消焦点', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardDismissRegion(
            child: Column(
              children: [
                TextField(focusNode: focusNode),
                const Expanded(child: SizedBox(width: double.infinity)),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(100, 200), kind: PointerDeviceKind.touch);
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('子控件仍然接收点击操作', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: KeyboardDismissRegion(
          child: Center(
            child: FilledButton(
              onPressed: () => pressed = true,
              child: const Text('操作'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(pressed, isTrue);
  });

  testWidgets('禁用时保留当前焦点', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardDismissRegion(
            enabled: false,
            child: Column(
              children: [
                TextField(focusNode: focusNode),
                const Expanded(child: SizedBox(width: double.infinity)),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tapAt(const Offset(100, 200), kind: PointerDeviceKind.touch);
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
  });
}
