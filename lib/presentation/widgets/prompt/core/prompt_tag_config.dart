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

/// 标签动画时长配置
class TagAnimationDurations {
  TagAnimationDurations._();

  /// 悬浮动画时长（毫秒）
  static const int hover = 150;

  /// 入场动画时长（毫秒）
  static const int entrance = 300;

  /// 交错延迟时长（毫秒）
  static const int stagger = 50;

  /// 点击波纹动画时长（毫秒）
  static const int ripple = 200;

  /// 状态转换动画时长（毫秒）
  static const int stateTransition = 150;

  /// 权重变化动画时长（毫秒）
  static const int weightChange = 300;

  /// 拖拽反馈动画时长（毫秒）
  static const int dragFeedback = 200;

  /// 删除动画时长（毫秒）
  static const int delete = 250;

  /// 收藏心跳动画时长（毫秒）
  static const int favoriteHeart = 200;

  /// 玻璃态模糊动画时长（毫秒）
  static const int glassBlur = 150;
}

/// 标签布局间距配置
class TagSpacing {
  TagSpacing._();

  /// 水平间距（像素）
  static const double horizontal = 6.0;

  /// 垂直间距（像素）
  static const double vertical = 4.0;

  /// 紧凑模式水平间距（像素）
  static const double compactHorizontal = 4.0;

  /// 紧凑模式垂直间距（像素）
  static const double compactVertical = 3.0;

  /// 标签组间距（像素）
  static const double group = 12.0;

  /// 标签行内间距（像素）
  static const double inline = 4.0;
}

/// 标签圆角半径配置
class TagBorderRadius {
  TagBorderRadius._();

  /// 小圆角（像素）- 用于标签卡片
  static const double small = 6.0;

  /// 中等圆角（像素）- 用于悬浮菜单
  static const double medium = 8.0;

  /// 大圆角（像素）- 用于弹窗和面板
  static const double large = 12.0;

  /// 超大圆角（像素）- 用于对话框
  static const double extraLarge = 16.0;
}

/// 标签阴影配置
class TagShadowConfig {
  TagShadowConfig._();

  /// 正常状态阴影
  static const double normalBlurRadius = 8.0;
  static const double normalOffsetX = 0.0;
  static const double normalOffsetY = 2.0;
  static const double normalOpacity = 0.1;

  /// 悬浮状态阴影
  static const double hoverBlurRadius = 12.0;
  static const double hoverOffsetX = 0.0;
  static const double hoverOffsetY = 4.0;
  static const double hoverOpacity = 0.2;

  /// 选中状态阴影
  static const double selectedBlurRadius = 10.0;
  static const double selectedOffsetX = 0.0;
  static const double selectedOffsetY = 3.0;
  static const double selectedOpacity = 0.15;

  /// 拖拽状态阴影
  static const double draggingBlurRadius = 16.0;
  static const double draggingOffsetX = 0.0;
  static const double draggingOffsetY = 8.0;
  static const double draggingOpacity = 0.3;

  /// 禁用状态阴影
  static const double disabledBlurRadius = 4.0;
  static const double disabledOffsetX = 0.0;
  static const double disabledOffsetY = 1.0;
  static const double disabledOpacity = 0.05;
}

/// 标签玻璃态效果配置
class TagGlassmorphism {
  TagGlassmorphism._();

  /// 模糊半径（西格玛值）
  static const double blurSigma = 12.0;

  /// 表面透明度
  static const double surfaceOpacity = 0.7;

  /// 边框透明度
  static const double borderOpacity = 0.2;

  /// 背景透明度范围（最小值）
  static const double minBackgroundOpacity = 0.6;

  /// 背景透明度范围（最大值）
  static const double maxBackgroundOpacity = 0.8;

  /// 内部辉光强度
  static const double innerGlowOpacity = 0.1;
}
