import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../widgets/common/surface_ink_well.dart';

/// 选项卡片组件
class VibeExportOptionCard extends StatelessWidget {
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;

  const VibeExportOptionCard({
    super.key,
    required this.isSelected,
    this.isDisabled = false,
    this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceInkWell(
      borderRadius: BorderRadius.circular(12),
      color: isDisabled
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.16)
          : theme.colorScheme.surfaceContainerLow,
      onTap: isDisabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDisabled
                          ? theme.colorScheme.outline.withValues(alpha: 0.3)
                          : isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: isDisabled
                        ? theme.colorScheme.surface
                        : isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                  ),
                  child: isSelected && !isDisabled
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: isDisabled
                                ? theme.colorScheme.outline.withValues(
                                    alpha: 0.5,
                                  )
                                : isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDisabled
                                    ? theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      )
                                    : isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDisabled
                              ? theme.colorScheme.outline.withValues(alpha: 0.5)
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

/// 导出选项复选框行
class VibeExportCheckboxRow extends StatelessWidget {
  const VibeExportCheckboxRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 导出进度视图
class VibeExportProgressView extends StatelessWidget {
  const VibeExportProgressView({
    super.key,
    required this.progress,
    required this.statusMessage,
  });

  final double progress;
  final String statusMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              statusMessage,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (progress > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 高级导出错误提示条
class VibeExportErrorBanner extends StatelessWidget {
  const VibeExportErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 高级导出对话框底部操作按钮栏
class VibeExportDialogActions extends StatelessWidget {
  const VibeExportDialogActions({
    super.key,
    required this.canExport,
    required this.onCancel,
    required this.onExport,
  });

  final bool canExport;
  final VoidCallback onCancel;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final cancel = TextButton(
      onPressed: onCancel,
      child: Text(context.l10n.common_cancel),
    );
    final export = FilledButton.icon(
      onPressed: canExport ? onExport : null,
      icon: const Icon(Icons.file_upload),
      label: Text(context.l10n.common_export),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            key: const Key('vibe-export-advanced-compact-actions'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cancel, const SizedBox(height: 8), export],
          );
        }
        return Row(
          key: const Key('vibe-export-advanced-actions'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [cancel, const SizedBox(width: 12), export],
        );
      },
    );
  }
}
