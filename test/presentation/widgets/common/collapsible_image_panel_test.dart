import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/collapsible_image_panel.dart';

void main() {
  Widget buildSubject({
    required double width,
    required bool expanded,
    required VoidCallback onToggle,
    bool disableAnimations = false,
    bool showSummary = true,
    bool hasData = false,
    WidgetBuilder? childBuilder,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: CollapsibleImagePanel(
                title: '角色',
                icon: Icons.people_outline,
                isExpanded: expanded,
                onToggle: onToggle,
                hasData: hasData,
                summary: showSummary
                    ? const Text(
                        '3 个启用 · Alice +2',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      )
                    : null,
                childBuilder:
                    childBuilder ??
                    (context) =>
                        const SizedBox(key: Key('panel-body'), height: 120),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('折叠时不构建内容，展开后收起保留子树', (tester) async {
    var expanded = false;
    var buildCount = 0;
    late StateSetter setHostState;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return buildSubject(
            width: 320,
            expanded: expanded,
            onToggle: () => setState(() => expanded = !expanded),
            childBuilder: (context) {
              buildCount++;
              return const Text('延迟内容', key: Key('lazy-body'));
            },
          );
        },
      ),
    );

    expect(buildCount, 0);
    expect(find.byKey(const Key('lazy-body')), findsNothing);

    await tester.tap(find.byKey(const Key('collapsible-header-角色')));
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
    expect(buildCount, greaterThan(0));
    expect(find.byKey(const Key('lazy-body')), findsOneWidget);

    setHostState(() => expanded = false);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('lazy-body'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byKey(const Key('lazy-body')), findsNothing);
  });

  testWidgets('标题行支持键盘切换并暴露可点击语义', (tester) async {
    var expanded = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => buildSubject(
          width: 320,
          expanded: expanded,
          onToggle: () => setState(() => expanded = !expanded),
        ),
      ),
    );

    final header = find.byKey(const Key('collapsible-header-角色'));
    final semantics = tester.getSemantics(header).getSemanticsData();
    expect(semantics.label, contains('角色'));
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(expanded, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(expanded, isFalse);
  });

  testWidgets('reduced motion 立即完成展开动画', (tester) async {
    var expanded = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => buildSubject(
          width: 320,
          expanded: expanded,
          disableAnimations: true,
          onToggle: () => setState(() => expanded = !expanded),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collapsible-header-角色')));
    await tester.pump();

    expect(expanded, isTrue);
    expect(find.byKey(const Key('panel-body')), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const Key('collapsible-content-角色')),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1);
  });

  for (final width in [280.0, 416.0, 700.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('$width 宽度下标题摘要无溢出且箭头贴右', (tester) async {
      await tester.pumpWidget(
        buildSubject(width: width, expanded: false, onToggle: () {}),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('3 个启用 · Alice +2'), findsOneWidget);

      final header = find.byKey(const Key('collapsible-header-角色'));
      final chevron = find.byKey(const Key('collapsible-chevron-角色'));
      final summary = find.byKey(const Key('collapsible-summary-角色'));
      expect(
        tester.getTopRight(header).dx - tester.getCenter(chevron).dx,
        lessThanOrEqualTo(24),
      );
      expect(
        (tester.getCenter(header).dx - tester.getCenter(summary).dx).abs(),
        lessThanOrEqualTo(1),
      );
    });
  }

  testWidgets('无摘要时箭头仍固定在标题行右侧', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        width: 416,
        expanded: false,
        showSummary: false,
        onToggle: () {},
      ),
    );
    await tester.pump();

    final header = find.byKey(const Key('collapsible-header-角色'));
    final chevron = find.byKey(const Key('collapsible-chevron-角色'));
    expect(
      tester.getTopRight(header).dx - tester.getCenter(chevron).dx,
      lessThanOrEqualTo(24),
    );
  });

  testWidgets('浅色主题下有数据但无背景图时不使用白色前景', (tester) async {
    await tester.pumpWidget(
      buildSubject(width: 416, expanded: false, hasData: true, onToggle: () {}),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('角色'));
    final chevron = tester.widget<Icon>(
      find.byKey(const Key('collapsible-chevron-角色')),
    );
    expect(title.style?.color, isNot(Colors.white));
    expect(chevron.color, isNot(Colors.white));
  });
}
