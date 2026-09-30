import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';

/// 词库加载中提示
class PromptConfigLoadingState extends StatelessWidget {
  const PromptConfigLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.common_loading,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 词库加载失败提示，可重试
class PromptConfigErrorState extends StatelessWidget {
  const PromptConfigErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return PromptConfigEmptyState(
      icon: Icons.error_outline_rounded,
      title: context.l10n.randomManager_libraryUnavailable,
      message: message,
      action: FilledButton.tonalIcon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(context.l10n.common_retry),
      ),
    );
  }
}

/// 图标、标题、说明与可选操作组成的居中提示
class PromptConfigEmptyState extends StatelessWidget {
  const PromptConfigEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
