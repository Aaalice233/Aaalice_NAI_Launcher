import 'package:flutter/material.dart';
import '../../themes/theme_extension.dart';

/// 主题感知分割线 - 根据当前主题自动应用合适的分割线样式
/// 
/// 根据不同主题类型选择对应的分割线风格：
/// - 霓虹效果主题: 发光边框
/// - CRT/点阵效果主题: 复古扫描线
/// - 高亮边框主题: 强调色分割
/// - 默认: 柔和凹槽效果
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
      
      // CRT 扫描线效果主题 (Motorola)
      if (extension.enableCrtEffect) {
        return _buildRetroScanline(context, isDark);
      }
      
      // 强调色分割条 (Herding)
      if (extension.accentBarColor != null) {
        return _buildAccentDivider(context, extension.accentBarColor!);
      }
    }

    // 默认: 柔和凹槽分割线
    return _buildSoftDivider(context, isDark);
  }

  /// 柔和凹槽分割线 - 默认样式
  Widget _buildSoftDivider(BuildContext context, bool isDark) {
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.5)
        : Colors.black.withOpacity(0.05);

    final highlightColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white;

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
            gradient: LinearGradient(
              begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
              end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
              colors: [
                Colors.transparent,
                shadowColor,
                shadowColor,
                Colors.transparent,
              ],
              stops: const [0.0, 0.15, 0.85, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: highlightColor,
                offset: vertical ? const Offset(1, 0) : const Offset(0, 1),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
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

  /// 复古扫描线分割线
  Widget _buildRetroScanline(BuildContext context, bool isDark) {
    final lineColor = isDark 
        ? const Color(0xFF00FF41).withOpacity(0.6)  // 复古绿
        : Colors.black.withOpacity(0.2);

    return SizedBox(
      width: vertical ? height : null,
      height: vertical ? null : height,
      child: Center(
        child: Container(
          width: vertical ? 2.0 : null,
          height: vertical ? null : 2.0,
          margin: EdgeInsetsDirectional.only(
            start: indent,
            end: endIndent,
            top: vertical ? indent : 0,
            bottom: vertical ? endIndent : 0,
          ),
          decoration: BoxDecoration(
            color: lineColor,
            boxShadow: [
              BoxShadow(
                color: lineColor.withOpacity(0.5),
                blurRadius: 2,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 强调色分割条
  Widget _buildAccentDivider(BuildContext context, Color accentColor) {
    return SizedBox(
      width: vertical ? height : null,
      height: vertical ? null : height,
      child: Center(
        child: Container(
          width: vertical ? 2.0 : null,
          height: vertical ? null : 2.0,
          margin: EdgeInsetsDirectional.only(
            start: indent,
            end: endIndent,
            top: vertical ? indent : 0,
            bottom: vertical ? endIndent : 0,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
              end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
              colors: [
                accentColor.withOpacity(0.0),
                accentColor,
                accentColor,
                accentColor.withOpacity(0.0),
              ],
              stops: const [0.0, 0.2, 0.8, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
