import 'package:flutter/material.dart';
import '../../themes/theme_extension.dart';

/// 主题感知分割线 - 根据当前主题自动应用合适的分割线样式
/// 
/// 使用 ThemeExtension 中的 divider 属性：
/// - dividerColor: 分割线颜色
/// - dividerThickness: 分割线厚度
/// - useDivider: 是否显示分割线
/// 
/// 同时保留对特殊效果的支持（霓虹发光等）
class ThemedDivider extends StatelessWidget {
  /// 分割线区域的总高度（包含上下留白）
  final double height;
  
  /// 左侧缩进
  final double indent;
  
  /// 右侧缩进  
  final double endIndent;
  
  /// 是否为垂直分割线
  final bool vertical;

  const ThemedDivider({
    super.key,
    this.height = 16.0,
    this.indent = 0.0,
    this.endIndent = 0.0,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    // 如果主题设置不显示分割线，直接返回空
    if (extension != null && !extension.useDivider) {
      return const SizedBox.shrink();
    }

    // 根据主题扩展属性决定分割线样式
    if (extension != null) {
      // 霓虹发光效果主题 (RetroWave/CassetteFuturism)
      if (extension.enableNeonGlow && extension.glowColor != null) {
        return _buildGlowDivider(
          context,
          extension.glowColor!,
          isDark,
        );
      }
    }

    // 使用新的 divider 属性
    final dividerColor = extension?.dividerColor ?? 
        (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1));
    final thickness = extension?.dividerThickness ?? 1.0;

    return _buildSimpleDivider(context, dividerColor, thickness);
  }

  /// 简单分割线 - 使用 dividerColor 和 dividerThickness
  Widget _buildSimpleDivider(BuildContext context, Color color, double thickness) {
    return SizedBox(
      width: vertical ? height : null,
      height: vertical ? null : height,
      child: Center(
        child: Container(
          width: vertical ? thickness : null,
          height: vertical ? null : thickness,
          margin: EdgeInsetsDirectional.only(
            start: indent,
            end: endIndent,
            top: vertical ? indent : 0,
            bottom: vertical ? endIndent : 0,
          ),
          color: color,
        ),
      ),
    );
  }

  /// 霓虹发光分割线
  Widget _buildGlowDivider(BuildContext context, Color glowColor, bool isDark) {
    return SizedBox(
      width: vertical ? height : null,
      height: vertical ? null : height,
      child: Center(
        child: Container(
          width: vertical ? 1.0 : null,
          height: vertical ? null : 1.0,
          margin: EdgeInsetsDirectional.only(
            start: indent,
            end: endIndent,
            top: vertical ? indent : 0,
            bottom: vertical ? endIndent : 0,
          ),
          decoration: BoxDecoration(
            color: glowColor.withOpacity(0.8),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: glowColor.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
