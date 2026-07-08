import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/resize_handle.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/web_panel_split.dart';

Widget _wrap({
  required double ratio,
  required ValueChanged<double> onRatioChanged,
  VoidCallback? onRatioReset,
  required Widget topSection,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: 600,
          child: WebPanelSplit(
            ratio: ratio,
            onRatioChanged: onRatioChanged,
            onRatioReset: onRatioReset ?? () {},
            topSection: topSection,
            bottomSection: const Text('settings-anchor'),
            footer: const SizedBox(height: 48, child: Text('generate-anchor')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('上分区内容超长时，设置区与生成按钮仍然可见且位置固定', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ratio: 0.5,
        onRatioChanged: (_) {},
        topSection: ListView(
          children: [Container(height: 5000, color: const Color(0xFF000000))],
        ),
      ),
    );

    expect(find.text('settings-anchor'), findsOneWidget);
    expect(find.text('generate-anchor'), findsOneWidget);

    // 设置区锚点应位于分隔线之下（约在容器垂直中点附近），不被长内容推走
    final settingsTop = tester.getTopLeft(find.text('settings-anchor')).dy;
    final splitBox = tester.getRect(find.byType(WebPanelSplit));
    expect(settingsTop, greaterThan(splitBox.top + splitBox.height * 0.4));
  });

  testWidgets('拖拽分隔线按高度换算比例并回调', (tester) async {
    final reported = <double>[];
    await tester.pumpWidget(
      _wrap(
        ratio: 0.5,
        onRatioChanged: reported.add,
        topSection: const SizedBox.expand(),
      ),
    );

    // 可用高度约 600，向下拖 60 → 比例约 +0.1
    await tester.drag(
      find.byType(VerticalResizeHandle),
      const Offset(0, 60),
    );
    // 让 DoubleTapGestureRecognizer（双击重置手势）在按下时创建的内部
    // 40ms 计时器（kDoubleTapMinTime，用于判断两次点击间隔）自然到期，
    // 否则测试结束时会触发 "A Timer is still pending" 框架断言。
    // 该计时器与本次拖拽是否被识别为拖拽无关，也不会因为 arena 被
    // VerticalDragGestureRecognizer 抢占而被取消——纯属 Flutter 内部
    // 记账用途，因此这里只需多 pump 一次时间，不会再产生新的回调。
    await tester.pump(const Duration(milliseconds: 50));

    expect(reported, isNotEmpty);
    // 实测：dragStartBehavior 默认为 DragStartBehavior.start 且
    // kDragSlopDefault(20.0) > kTouchSlop(18.0)，tester.drag 会拆成两次
    // moveBy：第一次 dy=20 用于越过触摸容差、被吸收进"拖拽开始"过渡
    // （delta=0，不触发 onUpdate）；第二次 dy=60-20=40 才真正触发一次
    // onDrag 回调。WebPanelSplit 是无状态组件，回调里的 effectiveRatio
    // 恒为传入的 0.5，因此 reported 只有一条记录：
    // 0.5 + 40/600 ≈ 0.5667，落在原始 closeTo(0.6, 0.05) 容差范围内，
    // 无需调整目标值/容差。
    expect(reported.last, closeTo(0.6, 0.05));
  });

  testWidgets('比例被 clamp 在 0.2–0.8', (tester) async {
    final reported = <double>[];
    await tester.pumpWidget(
      _wrap(
        ratio: 0.75,
        onRatioChanged: reported.add,
        topSection: const SizedBox.expand(),
      ),
    );

    await tester.drag(
      find.byType(VerticalResizeHandle),
      const Offset(0, 500),
    );
    // 原因同上一个测试：flush 双击手势内部 40ms 计时器，避免
    // "A Timer is still pending" 框架断言（不影响已记录的 reported 值）。
    await tester.pump(const Duration(milliseconds: 50));

    // 实测：同上一测试的换算方式，第二次 moveBy 的 dy = 500-20 = 480，
    // newRatio = clamp(0.75 + 480/600, 0.2, 0.8) 远超上限，稳定 clamp 到
    // 0.8——该断言保持严格相等，不做容差放宽。
    expect(reported.last, WebPanelSplit.maxRatio);
  });

  testWidgets('双击分隔线触发重置回调', (tester) async {
    var resetCalled = false;
    await tester.pumpWidget(
      _wrap(
        ratio: 0.7,
        onRatioChanged: (_) {},
        onRatioReset: () => resetCalled = true,
        topSection: const SizedBox.expand(),
      ),
    );

    final handleCenter =
        tester.getCenter(find.byType(VerticalResizeHandle));
    await tester.tapAt(handleCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(handleCenter);
    await tester.pumpAndSettle();

    expect(resetCalled, isTrue);
  });
}
