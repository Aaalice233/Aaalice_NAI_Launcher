import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'layout_state_provider.g.dart';

/// UI布局状态数据类
class LayoutState {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final double leftPanelWidth;
  final double promptAreaHeight;
  final bool promptMaximized;

  const LayoutState({
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.leftPanelWidth = 300.0,
    this.promptAreaHeight = 200.0,
    this.promptMaximized = false,
  });

  /// 复制并更新部分字段
  LayoutState copyWith({
    bool? leftPanelExpanded,
    bool? rightPanelExpanded,
    double? leftPanelWidth,
    double? promptAreaHeight,
    bool? promptMaximized,
  }) {
    return LayoutState(
      leftPanelExpanded: leftPanelExpanded ?? this.leftPanelExpanded,
      rightPanelExpanded: rightPanelExpanded ?? this.rightPanelExpanded,
      leftPanelWidth: leftPanelWidth ?? this.leftPanelWidth,
      promptAreaHeight: promptAreaHeight ?? this.promptAreaHeight,
      promptMaximized: promptMaximized ?? this.promptMaximized,
    );
  }
}

/// UI布局状态 Notifier
@riverpod
class LayoutStateNotifier extends _$LayoutStateNotifier {
  @override
  LayoutState build() {
    // 从本地存储加载布局状态
    final storage = ref.read(localStorageServiceProvider);

    return LayoutState(
      leftPanelExpanded: storage.getLeftPanelExpanded(),
      rightPanelExpanded: storage.getRightPanelExpanded(),
      leftPanelWidth: storage.getLeftPanelWidth(),
      promptAreaHeight: storage.getPromptAreaHeight(),
      promptMaximized: storage.getPromptMaximized(),
    );
  }

  /// 设置左侧面板展开状态
  Future<void> setLeftPanelExpanded(bool expanded) async {
    state = state.copyWith(leftPanelExpanded: expanded);

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setLeftPanelExpanded(expanded);
  }

  /// 切换左侧面板展开状态
  Future<void> toggleLeftPanel() async {
    await setLeftPanelExpanded(!state.leftPanelExpanded);
  }

  /// 设置右侧面板展开状态
  Future<void> setRightPanelExpanded(bool expanded) async {
    state = state.copyWith(rightPanelExpanded: expanded);

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setRightPanelExpanded(expanded);
  }

  /// 切换右侧面板展开状态
  Future<void> toggleRightPanel() async {
    await setRightPanelExpanded(!state.rightPanelExpanded);
  }

  /// 设置左侧面板宽度
  Future<void> setLeftPanelWidth(double width) async {
    state = state.copyWith(leftPanelWidth: width);

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setLeftPanelWidth(width);
  }

  /// 设置提示区域高度
  Future<void> setPromptAreaHeight(double height) async {
    state = state.copyWith(promptAreaHeight: height);

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setPromptAreaHeight(height);
  }

  /// 设置提示区域最大化状态
  Future<void> setPromptMaximized(bool maximized) async {
    state = state.copyWith(promptMaximized: maximized);

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setPromptMaximized(maximized);
  }
}
