import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/compact_icon_button.dart';

import '../../../helpers/text_layout_expectations.dart';

const _label = 'Pick a clone source';

void main() {
  testWidgets('窄槽位里放大文字时标签换行，不溢出槽位', (tester) async {
    await _pump(
      tester,
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: CompactIconButton(
          icon: Icons.my_location,
          label: _label,
          onPressed: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final label = tester.renderObject<RenderParagraph>(find.text(_label));
    expect(
      label.getMaxIntrinsicWidth(double.infinity),
      greaterThan(label.size.width),
      reason: '标签确实换了行',
    );
    expect(
      tester.getRect(find.byType(CompactIconButton)).width,
      lessThanOrEqualTo(160),
    );
  });

  testWidgets('宽度不受限时标签保持单行', (tester) async {
    await _pump(
      tester,
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: CompactIconButton(
          icon: Icons.my_location,
          label: _label,
          onPressed: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expectSingleLineUntruncated(tester, find.text(_label));
  });

  testWidgets('开关按钮把激活态作为读屏的开关状态', (tester) async {
    for (final isActive in const [true, false]) {
      await _pump(
        tester,
        CompactIconButton(
          icon: Icons.my_location,
          label: _label,
          tooltip: 'Also Alt+click',
          isActive: isActive,
          toggleable: true,
          onPressed: () {},
        ),
      );

      expect(
        tester.getSemantics(find.byType(CompactIconButton)),
        isSemantics(
          label: _label,
          tooltip: 'Also Alt+click',
          isButton: true,
          hasToggledState: true,
          isToggled: isActive,
          hasTapAction: true,
        ),
        reason: 'isActive=$isActive',
      );
    }
  });

  testWidgets('普通按钮不声明开关状态', (tester) async {
    await _pump(
      tester,
      CompactIconButton(
        icon: Icons.refresh,
        label: 'Refresh',
        isActive: true,
        onPressed: () {},
      ),
    );

    expect(
      tester.getSemantics(find.byType(CompactIconButton)),
      isSemantics(label: 'Refresh', isButton: true, hasToggledState: false),
    );
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(3)),
        child: app!,
      ),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
