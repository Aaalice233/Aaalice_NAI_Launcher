import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_form_footer.dart';

import '../../helpers/viewport_scenarios.dart';

void main() {
  const footerKey = ValueKey('footer');

  // Column 不拉伸子节点，页脚拿到的是宽松宽度约束
  Widget looseHost({
    required double width,
    required Widget footer,
    TextDirection textDirection = TextDirection.ltr,
    double textScale = 1,
  }) {
    return localizedTestApp(
      textScale: textScale,
      home: Directionality(
        textDirection: textDirection,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: Column(mainAxisSize: MainAxisSize.min, children: [footer]),
          ),
        ),
      ),
    );
  }

  AdaptiveFormFooter footerWith({
    VoidCallback? onCancel,
    bool cancelEnabled = true,
    bool withPrimary = true,
    String primaryLabel = 'Save',
  }) {
    return AdaptiveFormFooter(
      key: footerKey,
      leading: [TextButton(onPressed: () {}, child: const Text('Delete'))],
      onCancel: onCancel,
      cancelEnabled: cancelEnabled,
      primary: withPrimary
          ? FilledButton(onPressed: () {}, child: Text(primaryLabel))
          : null,
    );
  }

  testWidgets('宽松约束下占满宽度，次要操作、取消、主操作依次贴右排列', (tester) async {
    await tester.pumpWidget(looseHost(width: 480, footer: footerWith()));

    final footer = tester.getRect(find.byKey(footerKey));
    expect(footer.width, 480);
    final delete = tester.getRect(find.text('Delete'));
    final cancel = tester.getRect(find.text('取消'));
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    expect(delete.center.dx, lessThan(cancel.center.dx));
    expect(cancel.center.dx, lessThan(save.center.dx));
    expect(save.right, footer.right - 16);
    expect(delete.center.dy, closeTo(save.center.dy, 0.5));
  });

  testWidgets('从右到左排版时贴向起始边的另一侧', (tester) async {
    await tester.pumpWidget(
      looseHost(
        width: 480,
        textDirection: TextDirection.rtl,
        footer: footerWith(),
      ),
    );

    expect(
      tester.getRect(find.widgetWithText(FilledButton, 'Save')).left,
      tester.getRect(find.byKey(footerKey)).left + 16,
    );
  });

  for (final (width, textScale) in [(200.0, 1.0), (320.0, 3.0)]) {
    testWidgets('$width 宽、${textScale}x 字号放不下一行时纵向堆叠并保持贴右', (tester) async {
      await tester.pumpWidget(
        looseHost(
          width: width,
          textScale: textScale,
          footer: footerWith(primaryLabel: 'Save all changes'),
        ),
      );

      expect(tester.takeException(), isNull);
      final footer = tester.getRect(find.byKey(footerKey));
      final buttons = [
        tester.getRect(find.widgetWithText(TextButton, 'Delete')),
        tester.getRect(find.widgetWithText(TextButton, '取消')),
        tester.getRect(find.widgetWithText(FilledButton, 'Save all changes')),
      ];
      for (final button in buttons) {
        expect(button.right, closeTo(footer.right - 16, 0.5));
        expect(button.left, greaterThanOrEqualTo(footer.left + 16));
      }
      expect(buttons[0].bottom, lessThanOrEqualTo(buttons[1].top));
      expect(buttons[1].bottom, lessThanOrEqualTo(buttons[2].top));
    });
  }

  testWidgets('默认取消关闭当前路由', (tester) async {
    await tester.pumpWidget(
      localizedTestApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(child: footerWith()),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(footerKey), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byKey(footerKey), findsNothing);
  });

  testWidgets('自定义取消回调替代默认关闭，禁用时不可点击', (tester) async {
    var cancelled = 0;
    await tester.pumpWidget(
      looseHost(width: 480, footer: footerWith(onCancel: () => cancelled++)),
    );
    await tester.tap(find.text('取消'));
    expect(cancelled, 1);

    await tester.pumpWidget(
      looseHost(
        width: 480,
        footer: footerWith(onCancel: () => cancelled++, cancelEnabled: false),
      ),
    );
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, '取消')).enabled,
      isFalse,
    );
  });

  testWidgets('只能关闭的表单不显示主操作，取消仍贴右', (tester) async {
    await tester.pumpWidget(
      looseHost(width: 480, footer: footerWith(withPrimary: false)),
    );

    expect(find.byType(FilledButton), findsNothing);
    expect(
      tester.getRect(find.widgetWithText(TextButton, '取消')).right,
      tester.getRect(find.byKey(footerKey)).right - 16,
    );
  });
}
