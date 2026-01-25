import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/widgets/prompt/core/prompt_tag_colors.dart';
import 'package:nai_launcher/presentation/widgets/prompt/core/prompt_tag_config.dart';

/// 标签芯片主题配置
/// 提供集中化的样式管理，包括阴影、圆角、装饰等
class TagChipTheme {
  TagChipTheme._();

  // ========== 阴影预设 ==========

  /// 正常状态阴影
  static const List<BoxShadow> normalShadow = [
    BoxShadow(
      color: Color(0x00000000), // transparent, will be set with opacity
      blurRadius: TagShadowConfig.normalBlurRadius,
      offset: Offset(
        TagShadowConfig.normalOffsetX,
        TagShadowConfig.normalOffsetY,
      ),
    ),
  ];

  /// 悬浮状态阴影
  static const List<BoxShadow> hoverShadow = [
    BoxShadow(
      color: Color(0x00000000), // transparent, will be set with opacity
      blurRadius: TagShadowConfig.hoverBlurRadius,
      offset: Offset(
        TagShadowConfig.hoverOffsetX,
        TagShadowConfig.hoverOffsetY,
      ),
    ),
  ];

  /// 选中状态阴影
  static const List<BoxShadow> selectedShadow = [
    BoxShadow(
      color: Color(0x00000000), // transparent, will be set with opacity
      blurRadius: TagShadowConfig.selectedBlurRadius,
      offset: Offset(
        TagShadowConfig.selectedOffsetX,
        TagShadowConfig.selectedOffsetY,
      ),
    ),
  ];

  /// 拖拽状态阴影
  static const List<BoxShadow> draggingShadow = [
    BoxShadow(
      color: Color(0x00000000), // transparent, will be set with opacity
      blurRadius: TagShadowConfig.draggingBlurRadius,
      offset: Offset(
        TagShadowConfig.draggingOffsetX,
        TagShadowConfig.draggingOffsetY,
      ),
    ),
  ];

  /// 禁用状态阴影
  static const List<BoxShadow> disabledShadow = [
    BoxShadow(
      color: Color(0x00000000), // transparent, will be set with opacity
      blurRadius: TagShadowConfig.disabledBlurRadius,
      offset: Offset(
        TagShadowConfig.disabledOffsetX,
        TagShadowConfig.disabledOffsetY,
      ),
    ),
  ];

  // ========== 阴影生成方法 ==========

  /// 获取正常状态阴影列表
  ///
  /// [baseColor] 基础颜色（用于彩色阴影）
  /// [isDark] 是否暗色模式
  static List<BoxShadow> getNormalShadows({
    Color? baseColor,
    required bool isDark,
  }) {
    final shadowColor = baseColor ?? (isDark ? Colors.white : Colors.black);
    return [
      BoxShadow(
        color: shadowColor.withOpacity(TagShadowConfig.normalOpacity),
        blurRadius: TagShadowConfig.normalBlurRadius,
        offset: const Offset(
          TagShadowConfig.normalOffsetX,
          TagShadowConfig.normalOffsetY,
        ),
      ),
    ];
  }

  /// 获取悬浮状态阴影列表
  ///
  /// [baseColor] 基础颜色（用于彩色阴影）
  /// [isDark] 是否暗色模式
  static List<BoxShadow> getHoverShadows({
    Color? baseColor,
    required bool isDark,
  }) {
    final shadowColor = baseColor ?? (isDark ? Colors.white : Colors.black);
    return [
      BoxShadow(
        color: shadowColor.withOpacity(TagShadowConfig.hoverOpacity),
        blurRadius: TagShadowConfig.hoverBlurRadius,
        offset: const Offset(
          TagShadowConfig.hoverOffsetX,
          TagShadowConfig.hoverOffsetY,
        ),
      ),
    ];
  }

  /// 获取选中状态阴影列表
  ///
  /// [baseColor] 基础颜色（用于彩色阴影）
  /// [isDark] 是否暗色模式
  static List<BoxShadow> getSelectedShadows({
    required Color baseColor,
    required bool isDark,
  }) {
    return [
      BoxShadow(
        color: baseColor.withOpacity(TagShadowConfig.selectedOpacity),
        blurRadius: TagShadowConfig.selectedBlurRadius,
        offset: const Offset(
          TagShadowConfig.selectedOffsetX,
          TagShadowConfig.selectedOffsetY,
        ),
      ),
    ];
  }

  /// 获取拖拽状态阴影列表
  ///
  /// [baseColor] 基础颜色（用于彩色阴影）
  /// [isDark] 是否暗色模式
  static List<BoxShadow> getDraggingShadows({
    Color? baseColor,
    required bool isDark,
  }) {
    final shadowColor = baseColor ?? (isDark ? Colors.white : Colors.black);
    return [
      BoxShadow(
        color: shadowColor.withOpacity(TagShadowConfig.draggingOpacity),
        blurRadius: TagShadowConfig.draggingBlurRadius,
        offset: const Offset(
          TagShadowConfig.draggingOffsetX,
          TagShadowConfig.draggingOffsetY,
        ),
      ),
    ];
  }

  /// 获取禁用状态阴影列表
  static List<BoxShadow> getDisabledShadows({
    required bool isDark,
  }) {
    final shadowColor = isDark ? Colors.white : Colors.black;
    return [
      BoxShadow(
        color: shadowColor.withOpacity(TagShadowConfig.disabledOpacity),
        blurRadius: TagShadowConfig.disabledBlurRadius,
        offset: const Offset(
          TagShadowConfig.disabledOffsetX,
          TagShadowConfig.disabledOffsetY,
        ),
      ),
    ];
  }

  // ========== 装饰生成方法 ==========

  /// 生成标签芯片装饰
  ///
  /// [category] 标签分类
  /// [isSelected] 是否选中
  /// [isHovered] 是否悬浮
  /// [isDragging] 是否拖拽中
  /// [isEnabled] 是否启用
  /// [theme] 主题数据
  static BoxDecoration getChipDecoration({
    required int category,
    bool isSelected = false,
    bool isHovered = false,
    bool isDragging = false,
    bool isEnabled = true,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = PromptTagColors.getByCategory(category);
    final gradient = CategoryGradient.getGradientByCategory(category);

    // 获取背景色（使用渐变）
    final backgroundGradient = isEnabled
        ? gradient
        : null;

    // 获取边框色
    final borderColor = PromptTagColors.getBorderColor(
      baseColor,
      isSelected: isSelected,
      isHovered: isHovered,
      isEnabled: isEnabled,
      theme: theme,
    );

    // 获取阴影
    List<BoxShadow> shadows;
    if (isDragging) {
      shadows = getDraggingShadows(baseColor: baseColor, isDark: isDark);
    } else if (isSelected) {
      shadows = getSelectedShadows(baseColor: baseColor, isDark: isDark);
    } else if (isHovered) {
      shadows = getHoverShadows(baseColor: baseColor, isDark: isDark);
    } else if (isEnabled) {
      shadows = getNormalShadows(baseColor: baseColor, isDark: isDark);
    } else {
      shadows = getDisabledShadows(isDark: isDark);
    }

    return BoxDecoration(
      gradient: backgroundGradient,
      color: backgroundGradient == null
          ? PromptTagColors.getBackgroundColor(
              baseColor,
              isSelected: isSelected,
              isEnabled: isEnabled,
              theme: theme,
            )
          : null,
      border: Border.all(
        color: borderColor,
        width: isDragging ? 2.0 : 1.0,
      ),
      borderRadius: BorderRadius.circular(TagBorderRadius.small),
      boxShadow: shadows,
    );
  }

  /// 生成玻璃态装饰
  ///
  /// [category] 标签分类
  /// [isSelected] 是否选中
  /// [isHovered] 是否悬浮
  /// [isEnabled] 是否启用
  /// [theme] 主题数据
  static BoxDecoration getGlassmorphismDecoration({
    required int category,
    bool isSelected = false,
    bool isHovered = false,
    bool isEnabled = true,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = PromptTagColors.getByCategory(category);
    final gradient = CategoryGradient.getGradientByCategory(category);

    // 玻璃态背景色（低透明度）
    final backgroundGradient = LinearGradient(
      colors: [
        gradient.colors.first.withOpacity(
          isEnabled ? TagGlassmorphism.minBackgroundOpacity : 0.3,
        ),
        gradient.colors.last.withOpacity(
          isEnabled ? TagGlassmorphism.maxBackgroundOpacity : 0.4,
        ),
      ],
      begin: gradient.begin,
      end: gradient.end,
    );

    // 玻璃态边框
    final borderColor = baseColor.withOpacity(
      isEnabled ? TagGlassmorphism.borderOpacity : 0.1,
    );

    // 玻璃态阴影
    final shadows = isEnabled
        ? getNormalShadows(baseColor: baseColor, isDark: isDark)
        : getDisabledShadows(isDark: isDark);

    return BoxDecoration(
      gradient: backgroundGradient,
      border: Border.all(
        color: borderColor,
        width: 1.0,
      ),
      borderRadius: BorderRadius.circular(TagBorderRadius.medium),
      boxShadow: shadows,
    );
  }

  /// 生成拖拽状态装饰（带虚线边框）
  ///
  /// [category] 标签分类
  /// [theme] 主题数据
  static BoxDecoration getDraggingDecoration({
    required int category,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = PromptTagColors.getByCategory(category);
    final gradient = CategoryGradient.getGradientByCategory(category);

    return BoxDecoration(
      gradient: gradient,
      border: Border.all(
        color: baseColor,
        width: 2.0,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
      borderRadius: BorderRadius.circular(TagBorderRadius.small),
      boxShadow: getDraggingShadows(baseColor: baseColor, isDark: isDark),
    );
  }

  // ========== 圆角配置 ==========

  /// 获取标签芯片圆角
  static BorderRadius getChipBorderRadius() {
    return BorderRadius.circular(TagBorderRadius.small);
  }

  /// 获取悬浮菜单圆角
  static BorderRadius getMenuBorderRadius() {
    return BorderRadius.circular(TagBorderRadius.medium);
  }

  /// 获取弹窗面板圆角
  static BorderRadius getPanelBorderRadius() {
    return BorderRadius.circular(TagBorderRadius.large);
  }

  // ========== 内边距配置 ==========

  /// 获取正常模式内边距
  static EdgeInsets getNormalPadding() {
    return const EdgeInsets.symmetric(
      horizontal: TagChipSizes.normalHorizontalPadding,
      vertical: TagChipSizes.normalVerticalPadding,
    );
  }

  /// 获取紧凑模式内边距
  static EdgeInsets getCompactPadding() {
    return const EdgeInsets.symmetric(
      horizontal: TagChipSizes.compactHorizontalPadding,
      vertical: TagChipSizes.compactVerticalPadding,
    );
  }

  // ========== 间距配置 ==========

  /// 获取标签间距
  static EdgeInsets getTagSpacing({bool compact = false}) {
    return EdgeInsets.symmetric(
      horizontal: compact ? TagSpacing.compactHorizontal : TagSpacing.horizontal,
      vertical: compact ? TagSpacing.compactVertical : TagSpacing.vertical,
    );
  }

  // ========== 颜色辅助方法 ==========

  /// 获取文本颜色（确保 WCAG AA 对比度）
  static Color getTextColor({
    required int category,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    // 暗色模式下使用白色，亮色模式下使用对比色
    if (isDark) {
      return Colors.white.withOpacity(0.95);
    }

    // 亮色模式下，使用渐变的对比色
    return CategoryGradient.getContrastColor(category);
  }

  /// 获取翻译文本颜色（降低透明度）
  static Color getTranslationTextColor({
    required int category,
    required ThemeData theme,
  }) {
    return getTextColor(
      category: category,
      theme: theme,
    ).withOpacity(0.65);
  }

  /// 获取权重指示器颜色
  static Color getWeightIndicatorColor({
    required double weight,
    required int category,
  }) {
    final weightColor = PromptTagColors.getWeightColor(weight);
    if (weightColor != Colors.transparent) {
      return weightColor;
    }
    return PromptTagColors.getByCategory(category);
  }
}
