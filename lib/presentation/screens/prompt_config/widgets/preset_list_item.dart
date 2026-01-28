import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_preset.dart';

/// 预设列表项组件
class PresetListItem extends ConsumerWidget {
  final RandomPreset preset;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const PresetListItem({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.6)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.6)
                : theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 8 : 3,
              offset: Offset(0, isSelected ? 2 : 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Row(
                children: [
                  // 选中指示器（左侧竖条）
                  if (isSelected)
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: isSelected ? 8 : 12,
                        right: 12,
                        top: 10,
                        bottom: 10,
                      ),
                      child: Row(
                        children: [
                          // 图标
                          Icon(
                            preset.isDefault
                                ? Icons.auto_awesome
                                : Icons.tune_outlined,
                            size: 18,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : (preset.isDefault
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface
                                        .withOpacity(0.7)),
                          ),
                          const SizedBox(width: 8),
                          // 预设信息
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preset.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight:
                                        isSelected ? FontWeight.w600 : null,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : (preset.isDefault
                                            ? theme.colorScheme.primary
                                            : null),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  preset.isDefault
                                      ? context.l10n.naiMode_totalTags(
                                          preset.enabledCategoryCount
                                              .toString(),
                                        )
                                      : context.l10n.preset_configGroupCount(
                                          preset.categoryCount.toString(),
                                        ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 操作按钮（仅非默认预设）
                          if (!preset.isDefault) ...[
                            if (onRename != null)
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                                onPressed: onRename,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: context.l10n.preset_rename,
                              ),
                            if (onDelete != null)
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color:
                                      theme.colorScheme.error.withOpacity(0.7),
                                ),
                                onPressed: onDelete,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: context.l10n.common_delete,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
