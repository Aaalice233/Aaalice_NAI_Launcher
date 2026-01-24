import 'dart:ui';
import 'package:flutter/material.dart';
import '../../themes/design_tokens.dart';

/// 毛玻璃弹窗容器
///
/// 统一的毛玻璃样式弹窗，特性：
/// - BackdropFilter 模糊效果
/// - 半透明背景
/// - 发光边框
/// - 圆角
class GlassDialog extends StatelessWidget {
  /// 弹窗内容
  final Widget child;

  /// 弹窗宽度（null 时自适应）
  final double? width;

  /// 弹窗高度（null 时自适应）
  final double? height;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 是否使用全屏覆盖
  final bool fullScreen;

  const GlassDialog({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = ClipRRect(
      borderRadius:
          fullScreen ? BorderRadius.zero : DesignTokens.borderRadiusLg,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: DesignTokens.glassBlurRadius,
          sigmaY: DesignTokens.glassBlurRadius,
        ),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(DesignTokens.spacingMd),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface
                .withOpacity(DesignTokens.glassOpacity),
            borderRadius: fullScreen ? null : DesignTokens.borderRadiusLg,
            border: fullScreen
                ? null
                : Border.all(
                    color: theme.colorScheme.outline
                        .withOpacity(DesignTokens.glassBorderOpacity),
                  ),
            boxShadow: fullScreen
                ? null
                : [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.2),
                      blurRadius: DesignTokens.spacingLg,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );

    if (fullScreen) {
      return content;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: content,
    );
  }

  /// 显示毛玻璃弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black54,
      builder: (context) => GlassDialog(
        width: width,
        height: height,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// 毛玻璃确认弹窗
class GlassAlertDialog extends StatelessWidget {
  final String? title;
  final String content;
  final String? confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const GlassAlertDialog({
    super.key,
    this.title,
    required this.content,
    this.confirmText,
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassDialog(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingSm),
          ],
          Text(
            content,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DesignTokens.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (cancelText != null)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    onCancel?.call();
                  },
                  child: Text(cancelText!),
                ),
              const SizedBox(width: DesignTokens.spacingXs),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  onConfirm?.call();
                },
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      )
                    : null,
                child: Text(confirmText ?? '确定'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 显示确认弹窗
  static Future<bool?> show({
    required BuildContext context,
    String? title,
    required String content,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => GlassAlertDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      ),
    );
  }
}
