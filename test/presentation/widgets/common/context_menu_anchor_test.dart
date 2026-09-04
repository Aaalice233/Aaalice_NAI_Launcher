import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/presentation/widgets/common/context_menu_anchor.dart';

/// 右键菜单锚点回归。
///
/// 应用壳层把分支 Navigator 放在自绘标题栏（40）和主导航栏（200）右侧，
/// showMenu 的 position 相对最近 Overlay 而不是窗口：直接传手势
/// globalPosition 会让菜单整体偏移一个壳层边距（相簿树右键菜单偏移 bug）。
void main() {
  // 模拟 DesktopShell 的偏移内容区：标题栏下方、导航栏右侧嵌套 Navigator。
  Widget shell(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 40),
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 200),
                  Expanded(
                    child: Navigator(
                      onGenerateRoute: (_) => PageRouteBuilder(
                        pageBuilder: (_, __, ___) => child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  RenderBox overlayBoxOf(WidgetTester tester, BuildContext context) {
    return Overlay.of(context).context.findRenderObject()! as RenderBox;
  }

  bool samePlace(Offset a, Offset b) =>
      (a.dx - b.dx).abs() < 0.01 && (a.dy - b.dy).abs() < 0.01;

  testWidgets('锚点换算到最近 Overlay 的局部坐标', (tester) async {
    BuildContext? probeContext;
    await tester.pumpWidget(
      shell(
        Builder(
          builder: (context) {
            probeContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    final overlayBox = overlayBoxOf(tester, probeContext!);
    final overlayOrigin = overlayBox.localToGlobal(Offset.zero);
    // 保证测试环境确实复现了"overlay 原点不在窗口左上角"的壳层偏移。
    expect(overlayOrigin, isNot(Offset.zero));

    const tapPosition = Offset(537, 289);
    final anchor = contextMenuAnchorAt(probeContext!, tapPosition);
    final anchorRect = anchor.toRect(Offset.zero & overlayBox.size);

    expect(anchorRect.left, closeTo(tapPosition.dx - overlayOrigin.dx, 0.01));
    expect(anchorRect.top, closeTo(tapPosition.dy - overlayOrigin.dy, 0.01));
  });

  testWidgets('菜单出现在点击点，而非偏移一个壳层边距', (tester) async {
    await tester.pumpWidget(
      shell(
        const _MenuProbe(),
      ),
    );

    const tapPosition = Offset(400, 300);
    final gesture = await tester.startGesture(
      tapPosition,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    final menuBox = tester.renderObject<RenderBox>(
      find
          .ancestor(
            of: find.byType(PopupMenuItem<void>),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(samePlace(menuBox.localToGlobal(Offset.zero), tapPosition), isTrue);
  });
}

/// 在嵌套 Navigator 页面内右键弹出菜单的探针。
class _MenuProbe extends StatelessWidget {
  const _MenuProbe();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => showMenu<void>(
        context: context,
        position: contextMenuAnchorAt(context, details.globalPosition),
        items: const [
          PopupMenuItem<void>(child: Text('menu-item')),
        ],
      ),
      child: const SizedBox.expand(),
    );
  }
}
