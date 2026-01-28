import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/prompt_config.dart' as pc;
import '../../../widgets/common/themed_switch.dart';

/// 配置列表项组件
class ConfigListItem extends StatelessWidget {
  final pc.PromptConfig config;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggleEnabled;
  final VoidCallback onDelete;

  const ConfigListItem({
    super.key,
    required this.config,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onToggleEnabled,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      key: ValueKey(config.id),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 拖拽手柄
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(width: 8),
                // 启用开关
                ThemedSwitch(
                  value: config.enabled,
                  onChanged: (_) => onToggleEnabled(),
                  scale: 0.75,
                ),
                const SizedBox(width: 8),
                // 配置信息
                Expanded(
                  child: Opacity(
                    opacity: config.enabled ? 1.0 : 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getConfigSummary(context, config),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // 删除按钮
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.error.withOpacity(0.7),
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: context.l10n.common_delete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getConfigSummary(BuildContext context, pc.PromptConfig config) {
    final l10n = context.l10n;
    final parts = <String>[];
    if (config.contentType == pc.ContentType.string) {
      parts.add(l10n.preset_itemCount(config.stringContents.length.toString()));
    } else {
      parts.add(
        l10n.preset_subConfigCount(config.nestedConfigs.length.toString()),
      );
    }
    parts.add(_getSelectionModeShort(context, config.selectionMode));
    return parts.join(' · ');
  }

  String _getSelectionModeShort(
    BuildContext context,
    pc.SelectionMode mode,
  ) {
    final l10n = context.l10n;
    switch (mode) {
      case pc.SelectionMode.singleRandom:
        return l10n.preset_random;
      case pc.SelectionMode.singleSequential:
        return l10n.preset_sequential;
      case pc.SelectionMode.singleProbability:
        return l10n.preset_probability;
      case pc.SelectionMode.multipleCount:
        return l10n.preset_multiple;
      case pc.SelectionMode.multipleProbability:
        return l10n.preset_probability;
      case pc.SelectionMode.all:
        return l10n.preset_all;
    }
  }
}
