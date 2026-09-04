import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import 'adaptive_dialog_frame.dart';

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
    String? confirmText,
    String? cancelText,
    ThemedConfirmDialogType type = ThemedConfirmDialogType.normal,
    IconData? icon,
  }) async {
    final l10n = context.l10n;
    final resolvedConfirmText = confirmText ?? l10n.common_confirm;
    final resolvedCancelText = type == ThemedConfirmDialogType.info
        ? null
        : cancelText ?? l10n.common_cancel;
    final view = View.of(context);
    final windowWidth = view.physicalSize.width / view.devicePixelRatio;
    if (windowWidth < 600) {
      final result = await AdaptivePresenter.showForm<bool>(
        context: context,
        titleBuilder: (context) =>
            _CompactConfirmTitle(title: title, type: type, icon: icon),
        builder: (context, scrollController) => _CompactConfirmBody(
          content: content,
          confirmText: resolvedConfirmText,
          cancelText: resolvedCancelText,
          type: type,
          scrollController: scrollController,
        ),
      );
      return result ?? false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemedConfirmDialog(
        title: title,
        content: content,
        confirmText: resolvedConfirmText,
        cancelText: resolvedCancelText,
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
    String? confirmText,
    String? cancelText,
  }) {
    final l10n = context.l10n;
    return show(
      context: context,
      title: title ?? l10n.common_confirmDelete,
      content: content ?? l10n.common_deleteItemConfirm(itemName),
      confirmText: confirmText ?? l10n.common_delete,
      cancelText: cancelText ?? l10n.common_cancel,
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
    String? confirmText,
    String? cancelText,
  }) {
    final l10n = context.l10n;
    return show(
      context: context,
      title: title ?? l10n.common_confirmClear,
      content: content ?? l10n.common_clearAllItemsConfirm(count, itemType),
      confirmText: confirmText ?? l10n.common_clear,
      cancelText: cancelText ?? l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_sweep_outlined,
    );
  }

  /// 显示信息提示对话框（仅确认按钮）
  static Future<bool> showInfo({
    required BuildContext context,
    required String title,
    required String content,
    String? confirmText,
    IconData? icon,
  }) async {
    return show(
      context: context,
      title: title,
      content: content,
      confirmText: confirmText ?? context.l10n.common_gotIt,
      cancelText: null,
      type: ThemedConfirmDialogType.info,
      icon: icon ?? Icons.info_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;
    final accentColor = switch (type) {
      ThemedConfirmDialogType.danger => colors.error,
      ThemedConfirmDialogType.warning => colors.tertiary,
      ThemedConfirmDialogType.info ||
      ThemedConfirmDialogType.normal => colors.primary,
    };
    final actionMaxWidth = MediaQuery.sizeOf(context).width - 80;
    final (Color?, Color?) confirmColors = switch (type) {
      ThemedConfirmDialogType.danger => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      ThemedConfirmDialogType.warning => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      ThemedConfirmDialogType.info ||
      ThemedConfirmDialogType.normal => (null, null),
    };

    return AlertDialog(
      scrollable: true,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      content: AdaptiveDialogFrame(
        maxWidth: 420,
        maxHeight: 240,
        reservedVerticalSpace: 120,
        scaleReservedVerticalSpace: true,
        child: SingleChildScrollView(
          child: Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ),
      actions: [
        // 取消按钮（info 类型不显示）
        if (cancelText != null && type != ThemedConfirmDialogType.info)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              maximumSize: Size(actionMaxWidth, double.infinity),
            ),
            child: Text(
              cancelText!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        // 确认按钮
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: confirmColors.$1,
            foregroundColor: confirmColors.$2,
            maximumSize: Size(actionMaxWidth, double.infinity),
          ),
          child: Text(confirmText, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _CompactConfirmTitle extends StatelessWidget {
  const _CompactConfirmTitle({
    required this.title,
    required this.type,
    required this.icon,
  });

  final String title;
  final ThemedConfirmDialogType type;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accentColor = switch (type) {
      ThemedConfirmDialogType.danger => colors.error,
      ThemedConfirmDialogType.warning => colors.tertiary,
      ThemedConfirmDialogType.info ||
      ThemedConfirmDialogType.normal => colors.primary,
    };
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: accentColor),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(title)),
      ],
    );
  }
}

class _CompactConfirmBody extends StatelessWidget {
  const _CompactConfirmBody({
    required this.content,
    required this.confirmText,
    required this.cancelText,
    required this.type,
    required this.scrollController,
  });

  final String content;
  final String confirmText;
  final String? cancelText;
  final ThemedConfirmDialogType type;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (Color?, Color?) confirmColors = switch (type) {
      ThemedConfirmDialogType.danger => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      ThemedConfirmDialogType.warning => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      ThemedConfirmDialogType.info ||
      ThemedConfirmDialogType.normal => (null, null),
    };
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (cancelText != null)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelText!, textAlign: TextAlign.center),
                ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: confirmColors.$1,
                  foregroundColor: confirmColors.$2,
                ),
                child: Text(confirmText, textAlign: TextAlign.center),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
