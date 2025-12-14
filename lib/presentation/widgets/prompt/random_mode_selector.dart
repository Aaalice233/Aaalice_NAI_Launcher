import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/random_prompt_result.dart';
import '../../providers/random_mode_provider.dart';

/// 随机模式选择器
///
/// 用于选择随机提示词的生成模式（官网/自定义）
class RandomModeSelector extends ConsumerWidget {
  final VoidCallback? onModeChanged;

  const RandomModeSelector({
    super.key,
    this.onModeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(randomModeNotifierProvider);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: RandomGenerationMode.values
          .where((mode) => mode != RandomGenerationMode.hybrid) // 暂时隐藏混合模式
          .map(
            (mode) => _buildModeOption(
              context,
              ref,
              mode,
              currentMode,
              theme,
            ),
          )
          .toList(),
    );
  }

  Widget _buildModeOption(
    BuildContext context,
    WidgetRef ref,
    RandomGenerationMode mode,
    RandomGenerationMode currentMode,
    ThemeData theme,
  ) {
    final isSelected = mode == currentMode;

    return InkWell(
      onTap: () {
        ref.read(randomModeNotifierProvider.notifier).setMode(mode);
        onModeChanged?.call();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.5)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _getModeIcon(mode),
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getModeName(context, mode),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : null,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  Text(
                    _getModeDescription(context, mode),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getModeIcon(RandomGenerationMode mode) {
    return switch (mode) {
      RandomGenerationMode.naiOfficial => Icons.auto_awesome,
      RandomGenerationMode.custom => Icons.tune,
      RandomGenerationMode.hybrid => Icons.merge_type,
    };
  }

  String _getModeName(BuildContext context, RandomGenerationMode mode) {
    return switch (mode) {
      RandomGenerationMode.naiOfficial => context.l10n.randomMode_naiOfficial,
      RandomGenerationMode.custom => context.l10n.randomMode_custom,
      RandomGenerationMode.hybrid => context.l10n.randomMode_hybrid,
    };
  }

  String _getModeDescription(BuildContext context, RandomGenerationMode mode) {
    return switch (mode) {
      RandomGenerationMode.naiOfficial => context.l10n.randomMode_naiOfficialDesc,
      RandomGenerationMode.custom => context.l10n.randomMode_customDesc,
      RandomGenerationMode.hybrid => context.l10n.randomMode_hybridDesc,
    };
  }
}

/// 随机模式选择弹出菜单
class RandomModePopupMenu extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onModeChanged;

  const RandomModePopupMenu({
    super.key,
    required this.child,
    this.onModeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(randomModeNotifierProvider);

    return PopupMenuButton<RandomGenerationMode>(
      tooltip: context.l10n.randomMode_title,
      onSelected: (mode) {
        ref.read(randomModeNotifierProvider.notifier).setMode(mode);
        onModeChanged?.call();
      },
      itemBuilder: (context) => [
        _buildMenuItem(
          context,
          RandomGenerationMode.naiOfficial,
          currentMode,
        ),
        _buildMenuItem(
          context,
          RandomGenerationMode.custom,
          currentMode,
        ),
      ],
      child: child,
    );
  }

  PopupMenuItem<RandomGenerationMode> _buildMenuItem(
    BuildContext context,
    RandomGenerationMode mode,
    RandomGenerationMode currentMode,
  ) {
    final theme = Theme.of(context);
    final isSelected = mode == currentMode;

    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(
            _getModeIcon(mode),
            size: 20,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getModeName(context, mode),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : null,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
                Text(
                  _getModeDescription(context, mode),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check,
              size: 20,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }

  IconData _getModeIcon(RandomGenerationMode mode) {
    return switch (mode) {
      RandomGenerationMode.naiOfficial => Icons.auto_awesome,
      RandomGenerationMode.custom => Icons.tune,
      RandomGenerationMode.hybrid => Icons.merge_type,
    };
  }

  String _getModeName(BuildContext context, RandomGenerationMode mode) {
    return switch (mode) {
      RandomGenerationMode.naiOfficial => context.l10n.randomMode_naiOfficial,
      RandomGenerationMode.custom => context.l10n.randomMode_custom,
      RandomGenerationMode.hybrid => context.l10n.randomMode_hybrid,
    };
  }

  String _getModeDescription(BuildContext context, RandomGenerationMode mode) {
    return switch (mode) {
      RandomGenerationMode.naiOfficial => context.l10n.randomMode_naiOfficialDesc,
      RandomGenerationMode.custom => context.l10n.randomMode_customDesc,
      RandomGenerationMode.hybrid => context.l10n.randomMode_hybridDesc,
    };
  }
}

/// 随机模式选择底部表单
class RandomModeBottomSheet extends StatelessWidget {
  final VoidCallback? onModeChanged;

  const RandomModeBottomSheet({
    super.key,
    this.onModeChanged,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onModeChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => RandomModeBottomSheet(onModeChanged: onModeChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.casino, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.randomMode_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: RandomModeSelector(
              onModeChanged: () {
                Navigator.of(context).pop();
                onModeChanged?.call();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前模式指示器（紧凑型）
class RandomModeIndicator extends ConsumerWidget {
  final VoidCallback? onTap;

  const RandomModeIndicator({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(randomModeNotifierProvider);
    final theme = Theme.of(context);

    return Tooltip(
      message: _getModeDescription(context, currentMode),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getModeIcon(currentMode),
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                currentMode == RandomGenerationMode.naiOfficial
                    ? context.l10n.randomMode_naiIndicator
                    : context.l10n.randomMode_customIndicator,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon(RandomGenerationMode mode) {
    return switch (mode) {
      RandomGenerationMode.naiOfficial => Icons.auto_awesome,
      RandomGenerationMode.custom => Icons.tune,
      RandomGenerationMode.hybrid => Icons.merge_type,
    };
  }

  String _getModeDescription(BuildContext context, RandomGenerationMode mode) {
    return switch (mode) {
      RandomGenerationMode.naiOfficial => context.l10n.randomMode_naiOfficialDesc,
      RandomGenerationMode.custom => context.l10n.randomMode_customDesc,
      RandomGenerationMode.hybrid => context.l10n.randomMode_hybridDesc,
    };
  }
}
