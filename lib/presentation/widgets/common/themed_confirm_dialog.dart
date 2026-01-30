import 'package:flutter/material.dart';

/// 确认对话框类型
enum ThemedConfirmDialogType {
  /// 普通确认（使用主题色）
  normal,

  /// 危险操作确认（红色警示）
  danger,

  /// 警告确认（橙色警示）
  warning,

  /// 信息提示（仅确认按钮）
  info,
}

/// 通用确认对话框
///
/// 用于删除确认、清空确认等简单的二选一场景。
/// 支持四种类型：普通、危险、警告、信息提示。
///
/// 使用示例:
/// ```dart
/// final confirmed = await ThemedConfirmDialog.show(
///   context: context,
///   title: '删除确认',
///   content: '确定要删除吗？',
///   confirmText: '删除',
///   type: ThemedConfirmDialogType.danger,
/// );
/// if (confirmed) { ... }
/// ```
class ThemedConfirmDialog extends StatelessWidget {
  /// 对话框标题
  final String title;

  /// 对话框内容
  final String content;

  /// 确认按钮文字
  final String confirmText;

  /// 取消按钮文字（info 类型时不显示）
  final String? cancelText;

  /// 对话框类型
  final ThemedConfirmDialogType type;

  /// 自定义图标（可选）
  final IconData? icon;

  const ThemedConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.confirmText,
    this.cancelText,
    this.type = ThemedConfirmDialogType.normal,
    this.icon,
  });

  /// 显示确认对话框
  ///
  /// 返回 `true` 表示用户点击了确认，`false` 表示取消
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '确定',
    String cancelText = '取消',
    ThemedConfirmDialogType type = ThemedConfirmDialogType.normal,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemedConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        type: type,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  /// 显示删除确认对话框
  static Future<bool> showDelete({
    required BuildContext context,
    required String itemName,
    String? title,
    String? content,
    String confirmText = '删除',
    String cancelText = '取消',
  }) {
    return show(
      context: context,
      title: title ?? '删除确认',
      content: content ?? '确定要删除「$itemName」吗？此操作不可撤销。',
      confirmText: confirmText,
      cancelText: cancelText,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
  }

  /// 显示清空确认对话框
  static Future<bool> showClearAll({
    required BuildContext context,
    required int count,
    required String itemType,
    String? title,
    String? content,
    String confirmText = '清空',
    String cancelText = '取消',
  }) {
    return show(
      context: context,
      title: title ?? '清空确认',
      content: content ?? '确定要清空所有 $count 个$itemType吗？此操作不可撤销。',
      confirmText: confirmText,
      cancelText: cancelText,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_sweep_outlined,
    );
  }

  /// 显示信息提示对话框（仅确认按钮）
  static Future<bool> showInfo({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '知道了',
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemedConfirmDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: null,
        type: ThemedConfirmDialogType.info,
        icon: icon ?? Icons.info_outline,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 根据类型确定颜色
    final Color accentColor;
    switch (type) {
      case ThemedConfirmDialogType.danger:
        accentColor = theme.colorScheme.error;
      case ThemedConfirmDialogType.warning:
        accentColor = Colors.orange;
      case ThemedConfirmDialogType.info:
        accentColor = theme.colorScheme.primary;
      case ThemedConfirmDialogType.normal:
        accentColor = theme.colorScheme.primary;
    }

    return AlertDialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: accentColor, size: 24),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      actions: [
        // 取消按钮（info 类型不显示）
        if (cancelText != null && type != ThemedConfirmDialogType.info)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText!,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        // 确认按钮
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: type == ThemedConfirmDialogType.danger ||
                    type == ThemedConfirmDialogType.warning
                ? accentColor
                : null,
            foregroundColor: type == ThemedConfirmDialogType.danger ||
                    type == ThemedConfirmDialogType.warning
                ? theme.colorScheme.onError
                : null,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
