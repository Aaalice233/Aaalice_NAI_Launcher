import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/presentation/adaptive/ios_keyboard_dismissal.dart';

void main() {
  tearDown(() => PlatformCapabilities.debugOverride = null);

  Future<FocusNode> pumpField(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      platform,
    );
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: IosKeyboardDismissal(
          child: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focusNode),
                // 模拟自动补全浮层：登记为输入框的一部分。
                const TextFieldTapRegion(
                  child: SizedBox(
                    key: ValueKey('suggestions'),
                    width: 200,
                    height: 80,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
                const SizedBox(
                  key: ValueKey('outside'),
                  width: 200,
                  height: 200,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    return focusNode;
  }

  testWidgets('iOS 点输入框外部收起键盘，点补全浮层不收', (tester) async {
    final focusNode = await pumpField(tester, TargetPlatform.iOS);

    await tester.tap(find.byKey(const ValueKey('suggestions')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('outside')));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('Android 保持框架默认：点外部不失焦', (tester) async {
    final focusNode = await pumpField(tester, TargetPlatform.android);

    await tester.tap(find.byKey(const ValueKey('outside')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
  });
}
