/// 提示词编辑器工具栏配置
///
/// 定义 [PromptEditorToolbar] 组件的功能开关和外观选项。
/// 支持通过预设配置快速适配不同使用场景。
library;

/// 提示词编辑器工具栏配置
///
/// 通过布尔标志控制工具栏中各个操作按钮的显示与隐藏。
/// 提供预设配置用于常见使用场景。
class PromptEditorToolbarConfig {
  // ==================== 功能开关 ====================

  /// 是否显示随机生成按钮
  ///
  /// 启用后，显示随机按钮用于随机生成提示词。
  final bool showRandomButton;

  /// 是否显示全屏编辑按钮
  ///
  /// 启用后，显示全屏按钮用于打开全屏编辑模式。
  final bool showFullscreenButton;

  /// 是否显示清空按钮
  ///
  /// 启用后，显示清空按钮用于清除提示词内容。
  final bool showClearButton;

  /// 是否显示设置按钮
  ///
  /// 启用后，显示设置按钮用于打开设置菜单。
  final bool showSettingsButton;

  // ==================== 外观选项 ====================

  /// 是否紧凑模式
  ///
  /// 紧凑模式下优先显示必要操作，隐藏次要操作。
  final bool compact;

  /// 清空前是否需要确认
  ///
  /// 启用后，点击清空按钮时会显示确认弹窗。
  final bool confirmBeforeClear;

  const PromptEditorToolbarConfig({
    this.showRandomButton = true,
    this.showFullscreenButton = true,
    this.showClearButton = true,
    this.showSettingsButton = true,
    this.compact = false,
    this.confirmBeforeClear = true,
  });

  // ==================== 预设配置 ====================

  /// 主编辑器预设配置
  ///
  /// 适用于主界面的提示词编辑器，启用所有功能。
  static const mainEditor = PromptEditorToolbarConfig(
    showRandomButton: true,
    showFullscreenButton: true,
    showClearButton: true,
    showSettingsButton: true,
    compact: false,
    confirmBeforeClear: true,
  );

  /// 角色编辑器预设配置
  ///
  /// 适用于角色详情面板中的提示词编辑器。
  /// 只启用清空按钮，其他功能（设置等）跟随主界面。
  /// 清空操作无需确认，直接执行。
  static const characterEditor = PromptEditorToolbarConfig(
    showRandomButton: false,
    showFullscreenButton: false,
    showClearButton: true,
    showSettingsButton: false,
    compact: false,
    confirmBeforeClear: false,
  );

  /// 紧凑模式预设配置
  ///
  /// 适用于空间有限的场景，仅显示必要的操作按钮。
  static const compactMode = PromptEditorToolbarConfig(
    showRandomButton: false,
    showFullscreenButton: false,
    showClearButton: true,
    showSettingsButton: false,
    compact: true,
    confirmBeforeClear: true,
  );

  /// 创建配置副本并覆盖指定属性
  PromptEditorToolbarConfig copyWith({
    bool? showRandomButton,
    bool? showFullscreenButton,
    bool? showClearButton,
    bool? showSettingsButton,
    bool? compact,
    bool? confirmBeforeClear,
  }) {
    return PromptEditorToolbarConfig(
      showRandomButton: showRandomButton ?? this.showRandomButton,
      showFullscreenButton: showFullscreenButton ?? this.showFullscreenButton,
      showClearButton: showClearButton ?? this.showClearButton,
      showSettingsButton: showSettingsButton ?? this.showSettingsButton,
      compact: compact ?? this.compact,
      confirmBeforeClear: confirmBeforeClear ?? this.confirmBeforeClear,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PromptEditorToolbarConfig &&
        other.showRandomButton == showRandomButton &&
        other.showFullscreenButton == showFullscreenButton &&
        other.showClearButton == showClearButton &&
        other.showSettingsButton == showSettingsButton &&
        other.compact == compact &&
        other.confirmBeforeClear == confirmBeforeClear;
  }

  @override
  int get hashCode {
    return Object.hash(
      showRandomButton,
      showFullscreenButton,
      showClearButton,
      showSettingsButton,
      compact,
      confirmBeforeClear,
    );
  }

  @override
  String toString() {
    return 'PromptEditorToolbarConfig('
        'showRandomButton: $showRandomButton, '
        'showFullscreenButton: $showFullscreenButton, '
        'showClearButton: $showClearButton, '
        'showSettingsButton: $showSettingsButton, '
        'compact: $compact, '
        'confirmBeforeClear: $confirmBeforeClear)';
  }
}
