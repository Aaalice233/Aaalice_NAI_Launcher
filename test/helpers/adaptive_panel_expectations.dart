import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_pinned_header_sliver.dart';

/// 最上层面板的标题栏位于正文的纵向滚动视图中，矮视口里随正文滚走
void expectPanelHeaderScrollsWithContent(
  WidgetTester tester, {
  String? reason,
}) {
  final header = find.byKey(
    const ValueKey('adaptive-panel-header-surface'),
    skipOffstage: false,
  );
  expect(header, findsWidgets, reason: reason);
  expect(
    find.ancestor(
      of: header.last,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        skipOffstage: false,
      ),
    ),
    findsOneWidget,
    reason: reason,
  );
}

/// [child] 所在的自适应固定头部
RenderAdaptivePinnedHeaderSliver pinnedHeaderSliverOf(
  WidgetTester tester,
  Finder child,
) {
  RenderObject? node = tester.renderObject(child);
  while (node is! RenderAdaptivePinnedHeaderSliver) {
    node = node!.parent;
  }
  return node;
}
