import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/prompt_copy_split_button.dart';

void main() {
  Widget subject({
    double width = 240,
    VoidCallback? onPressed,
    List<Widget>? menuChildren,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: PromptCopySplitButton(
              key: const ValueKey('copy-split'),
              primaryLabel: '复制全部 TAG 与完整提示词内容',
              menuTooltip: '更多复制方式',
              onPressed: onPressed,
              menuButtonKey: const ValueKey('copy-menu'),
              menuChildren:
                  menuChildren ??
                  [const MenuItemButton(onPressed: null, child: Text('自定义复制'))],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('主操作与菜单组成连续的 48px 分割按钮', (tester) async {
    await tester.pumpWidget(subject(onPressed: () {}));

    final split = find.byKey(const ValueKey('copy-split'));
    final buttons = find.descendant(
      of: split,
      matching: find.byType(OutlinedButton),
    );
    expect(buttons, findsNWidgets(2));

    final primaryRect = tester.getRect(buttons.at(0));
    final menuRect = tester.getRect(buttons.at(1));
    expect(primaryRect.height, 48);
    expect(menuRect.size, const Size(48, 48));
    expect(primaryRect.right, closeTo(menuRect.left - 1, 0.1));
    expect(tester.getRect(split).height, 48);
    expect(tester.takeException(), isNull);
  });

  for (final width in [160.0, 240.0, 360.0, 412.0, 600.0]) {
    testWidgets('$width 宽度下长文案不挤压菜单入口', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(subject(width: width, onPressed: () {}));

      final menuRect = tester.getRect(find.byKey(const ValueKey('copy-menu')));
      expect(menuRect.width, 48);
      expect(menuRect.right, lessThanOrEqualTo(width));
      expect(find.byType(FittedBox), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('下拉入口打开菜单且不触发主操作', (tester) async {
    var primaryPresses = 0;
    await tester.pumpWidget(
      subject(
        onPressed: () => primaryPresses++,
        menuChildren: [
          MenuItemButton(onPressed: () {}, child: const Text('自定义复制')),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('copy-menu')));
    await tester.pumpAndSettle();

    expect(find.text('自定义复制'), findsOneWidget);
    expect(primaryPresses, 0);
    expect(tester.takeException(), isNull);
  });
}
