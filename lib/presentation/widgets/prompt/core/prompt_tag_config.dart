import 'dart:io';

/// 标签视图配置
class PromptTagConfig {
  /// 是否为移动平台
  final bool isMobile;

  /// 是否显示翻译
  final bool showTranslation;

  /// 是否紧凑模式
  final bool compact;

  /// 悬浮菜单延迟显示时间（毫秒）
  final int hoverMenuDelay;

  /// 悬浮菜单延迟隐藏时间（毫秒）
  final int hoverMenuHideDelay;

  /// 长按拖拽延迟（毫秒）
  final int dragDelay;

  /// 是否启用框选
  final bool enableBoxSelection;

  /// 是否启用动画
  final bool enableAnimation;

  const PromptTagConfig({
    this.isMobile = false,
    this.showTranslation = true,
    this.compact = false,
    this.hoverMenuDelay = 100,
    this.hoverMenuHideDelay = 200,
    this.dragDelay = 200,
    this.enableBoxSelection = true,
    this.enableAnimation = true,
  });

  /// 根据平台创建默认配置
  factory PromptTagConfig.forPlatform({bool? isMobile}) {
    final mobile = isMobile ?? (Platform.isAndroid || Platform.isIOS);
    return PromptTagConfig(
      isMobile: mobile,
      showTranslation: true,
      compact: mobile, // 移动端默认紧凑
      hoverMenuDelay: mobile ? 0 : 100,
      hoverMenuHideDelay: mobile ? 0 : 200,
      dragDelay: mobile ? 300 : 200,
      enableBoxSelection: !mobile, // 移动端禁用框选
      enableAnimation: true,
    );
  }

  /// 复制并修改
  PromptTagConfig copyWith({
    bool? isMobile,
    bool? showTranslation,
    bool? compact,
    int? hoverMenuDelay,
    int? hoverMenuHideDelay,
    int? dragDelay,
    bool? enableBoxSelection,
    bool? enableAnimation,
  }) {
    return PromptTagConfig(
      isMobile: isMobile ?? this.isMobile,
      showTranslation: showTranslation ?? this.showTranslation,
      compact: compact ?? this.compact,
      hoverMenuDelay: hoverMenuDelay ?? this.hoverMenuDelay,
      hoverMenuHideDelay: hoverMenuHideDelay ?? this.hoverMenuHideDelay,
      dragDelay: dragDelay ?? this.dragDelay,
      enableBoxSelection: enableBoxSelection ?? this.enableBoxSelection,
      enableAnimation: enableAnimation ?? this.enableAnimation,
    );
  }
}

/// 标签卡片尺寸配置
class TagChipSizes {
  TagChipSizes._();

  // 正常模式
  static const double normalHorizontalPadding = 10.0;
  static const double normalVerticalPadding = 6.0;
  static const double normalFontSize = 12.0;
  static const double normalTranslationFontSize = 10.0;
  static const double normalBorderRadius = 6.0;

  // 紧凑模式
  static const double compactHorizontalPadding = 8.0;
  static const double compactVerticalPadding = 4.0;
  static const double compactFontSize = 11.0;
  static const double compactTranslationFontSize = 9.0;
  static const double compactBorderRadius = 5.0;

  // 悬浮菜单
  static const double menuBorderRadius = 8.0;
  static const double menuBlurSigma = 12.0;
  static const double menuIconSize = 16.0;
  static const double menuButtonSize = 26.0;

  // 内联编辑
  static const double editInputMinWidth = 60.0;
  static const double editInputMaxWidth = 200.0;
  static const double editInputPadding = 8.0;
}

/// 标签交互模式
enum TagInteractionMode {
  /// 正常模式：单击选中，双击编辑，悬浮显示菜单
  normal,

  /// 只读模式：禁用所有交互
  readOnly,

  /// 批量选择模式：单击切换选中
  batchSelect,

  /// 编辑模式：当前正在编辑某个标签
  editing,
}

/// 标签操作类型
enum TagActionType {
  /// 增加权重
  increaseWeight,

  /// 减少权重
  decreaseWeight,

  /// 切换启用/禁用
  toggleEnabled,

  /// 编辑文本
  edit,

  /// 删除
  delete,

  /// 复制
  copy,
}
