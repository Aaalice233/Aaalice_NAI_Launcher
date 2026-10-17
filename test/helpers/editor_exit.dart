import 'package:flutter_test/flutter_test.dart';

/// 离开编辑器的两条路径：标题栏关闭按钮与系统返回（Android 返回键/手势）。
enum EditorExit {
  closeButton,
  systemBack;

  Future<void> perform(WidgetTester tester) async {
    switch (this) {
      case EditorExit.closeButton:
        await tester.tap(find.byTooltip('Close'));
      case EditorExit.systemBack:
        await tester.binding.handlePopRoute();
    }
  }
}

/// 有界等待：编辑器没退出时保存按钮的不定进度圈一直在动，超过 [limit] 即失败。
Future<void> settleWithin(WidgetTester tester, Duration limit) =>
    tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      limit,
    );
