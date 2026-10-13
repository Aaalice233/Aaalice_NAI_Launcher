import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 请求把工作流参数面板呈现到屏幕上，状态值是单调递增的请求序号。
///
/// [ImageWorkflowLauncher] 进入放大 / 增强时只会展开参数面板。桌面上面板常驻
/// 可见，展开即可；手机上参数面板在抽屉里，需要由移动端生成页监听这里的请求
/// 打开抽屉，否则点了「放大 / 增强」屏幕上没有任何变化。没有监听者时请求不产生
/// 任何效果。
class WorkflowPanelRevealNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final workflowPanelRevealProvider =
    NotifierProvider<WorkflowPanelRevealNotifier, int>(
      WorkflowPanelRevealNotifier.new,
    );
