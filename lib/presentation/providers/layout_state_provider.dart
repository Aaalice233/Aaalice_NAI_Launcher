import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'layout_state_provider.g.dart';

/// UI布局状态数据类
class LayoutState {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final double leftPanelWidth;
  final double rightPanelWidth;
  final double promptAreaHeight;
  final bool promptMaximized;
  final bool fixedTagsSidebarExpanded;
  final double fixedTagsSidebarWidth;
  final String fixedTagsSidebarViewMode;
  final double fixedTagsNegativeHeight;
  final double webLeftPanelWidth;
  final bool webLeftPanelExpanded;

  const LayoutState({
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.leftPanelWidth = 300.0,
    this.rightPanelWidth = 280.0,
    this.promptAreaHeight = 200.0,
    this.promptMaximized = false,
    this.fixedTagsSidebarExpanded = false,
    this.fixedTagsSidebarWidth = 280.0,
    this.fixedTagsSidebarViewMode = 'list',
    this.fixedTagsNegativeHeight = 180.0,
    this.webLeftPanelWidth = 400.0,
    this.webLeftPanelExpanded = true,
  });

  /// 复制并更新部分字段
  LayoutState copyWith({
    bool? leftPanelExpanded,
    bool? rightPanelExpanded,
    double? leftPanelWidth,
    double? rightPanelWidth,
    double? promptAreaHeight,
    bool? promptMaximized,
    bool? fixedTagsSidebarExpanded,
    double? fixedTagsSidebarWidth,
    String? fixedTagsSidebarViewMode,
    double? fixedTagsNegativeHeight,
    double? webLeftPanelWidth,
    bool? webLeftPanelExpanded,
  }) {
    return LayoutState(
      leftPanelExpanded: leftPanelExpanded ?? this.leftPanelExpanded,
      rightPanelExpanded: rightPanelExpanded ?? this.rightPanelExpanded,
      leftPanelWidth: leftPanelWidth ?? this.leftPanelWidth,
      rightPanelWidth: rightPanelWidth ?? this.rightPanelWidth,
      promptAreaHeight: promptAreaHeight ?? this.promptAreaHeight,
      promptMaximized: promptMaximized ?? this.promptMaximized,
      fixedTagsSidebarExpanded:
          fixedTagsSidebarExpanded ?? this.fixedTagsSidebarExpanded,
      fixedTagsSidebarWidth:
          fixedTagsSidebarWidth ?? this.fixedTagsSidebarWidth,
      fixedTagsSidebarViewMode:
          fixedTagsSidebarViewMode ?? this.fixedTagsSidebarViewMode,
      fixedTagsNegativeHeight:
          fixedTagsNegativeHeight ?? this.fixedTagsNegativeHeight,
      webLeftPanelWidth: webLeftPanelWidth ?? this.webLeftPanelWidth,
      webLeftPanelExpanded: webLeftPanelExpanded ?? this.webLeftPanelExpanded,
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
      rightPanelWidth: storage.getRightPanelWidth(),
      promptAreaHeight: storage.getPromptAreaHeight(),
      promptMaximized: storage.getPromptMaximized(),
      fixedTagsSidebarExpanded: storage.getFixedTagsSidebarExpanded(),
      fixedTagsSidebarWidth: storage.getFixedTagsSidebarWidth(),
      fixedTagsSidebarViewMode: storage.getFixedTagsSidebarViewMode(),
      fixedTagsNegativeHeight: storage.getFixedTagsNegativeHeight(),
      webLeftPanelWidth: storage.getWebLeftPanelWidth(),
      webLeftPanelExpanded: storage.getWebLeftPanelExpanded(),
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

  /// 设置右侧面板宽度
  Future<void> setRightPanelWidth(double width) async {
    state = state.copyWith(rightPanelWidth: width);

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setRightPanelWidth(width);
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

  /// 设置固定词侧边栏展开状态
  Future<void> setFixedTagsSidebarExpanded(bool expanded) async {
    state = state.copyWith(fixedTagsSidebarExpanded: expanded);

    final storage = ref.read(localStorageServiceProvider);
    await storage.setFixedTagsSidebarExpanded(expanded);
  }

  /// 切换固定词侧边栏展开状态
  Future<void> toggleFixedTagsSidebar() async {
    await setFixedTagsSidebarExpanded(!state.fixedTagsSidebarExpanded);
  }

  /// 设置固定词侧边栏宽度
  Future<void> setFixedTagsSidebarWidth(double width) async {
    final clamped = width.clamp(240.0, 400.0).toDouble();
    state = state.copyWith(fixedTagsSidebarWidth: clamped);

    final storage = ref.read(localStorageServiceProvider);
    await storage.setFixedTagsSidebarWidth(clamped);
  }

  /// 设置固定词侧边栏视图模式
  Future<void> setFixedTagsSidebarViewMode(String mode) async {
    final normalized = mode == 'grid' ? 'grid' : 'list';
    state = state.copyWith(fixedTagsSidebarViewMode: normalized);

    final storage = ref.read(localStorageServiceProvider);
    await storage.setFixedTagsSidebarViewMode(normalized);
  }

  /// 设置负向固定词区域高度
  Future<void> setFixedTagsNegativeHeight(double height) async {
    final clamped = height.clamp(60.0, 500.0).toDouble();
    state = state.copyWith(fixedTagsNegativeHeight: clamped);

    final storage = ref.read(localStorageServiceProvider);
    await storage.setFixedTagsNegativeHeight(clamped);
  }

  /// 设置官网式布局左栏宽度
  Future<void> setWebLeftPanelWidth(double width) async {
    final clamped = width.clamp(320.0, 560.0).toDouble();
    state = state.copyWith(webLeftPanelWidth: clamped);

    final storage = ref.read(localStorageServiceProvider);
    await storage.setWebLeftPanelWidth(clamped);
  }

  /// 设置官网式布局左栏展开状态
  Future<void> setWebLeftPanelExpanded(bool expanded) async {
    state = state.copyWith(webLeftPanelExpanded: expanded);

    final storage = ref.read(localStorageServiceProvider);
    await storage.setWebLeftPanelExpanded(expanded);
  }

}
