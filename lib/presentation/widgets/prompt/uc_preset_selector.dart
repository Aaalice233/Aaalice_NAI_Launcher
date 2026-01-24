import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/image_generation_provider.dart';

/// UC 预设选择器组件
class UcPresetSelector extends ConsumerStatefulWidget {
  /// 当前选择的模型
  final String model;

  const UcPresetSelector({
    super.key,
    required this.model,
  });

  @override
  ConsumerState<UcPresetSelector> createState() => _UcPresetSelectorState();
}

class _UcPresetSelectorState extends ConsumerState<UcPresetSelector> {
  bool _isHovering = false;

  String _getPresetDisplayName(BuildContext context, UcPresetType type) {
    switch (type) {
      case UcPresetType.heavy:
        return context.l10n.ucPreset_heavy;
      case UcPresetType.light:
        return context.l10n.ucPreset_light;
      case UcPresetType.furryFocus:
        return context.l10n.ucPreset_furryFocus;
      case UcPresetType.humanFocus:
        return context.l10n.ucPreset_humanFocus;
      case UcPresetType.none:
        return context.l10n.ucPreset_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPreset = ref.watch(ucPresetSettingsProvider);
    final presetContent =
        UcPresets.getPresetContent(widget.model, currentPreset);
    final isEnabled = currentPreset != UcPresetType.none;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        richMessage: WidgetSpan(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: _buildTooltipWidget(theme, presetContent, isEnabled),
          ),
        ),
        preferBelow: true,
        verticalOffset: 20,
        waitDuration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: PopupMenuButton<UcPresetType>(
          tooltip: '',
          offset: const Offset(0, 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (type) {
            ref.read(ucPresetSettingsProvider.notifier).set(type);
          },
          itemBuilder: (context) => UcPresetType.values.map((type) {
            final isSelected = type == currentPreset;
            return PopupMenuItem<UcPresetType>(
              value: type,
              child: Row(
                children: [
                  if (isSelected)
                    Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(
                    _getPresetDisplayName(context, type),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isEnabled
                  ? (_isHovering
                      ? theme.colorScheme.secondary.withOpacity(0.2)
                      : theme.colorScheme.secondary.withOpacity(0.1))
                  : (_isHovering
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isEnabled
                    ? theme.colorScheme.secondary.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isEnabled ? Icons.block : Icons.block_outlined,
                  size: 14,
                  color: isEnabled
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  _getPresetDisplayName(context, currentPreset),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w500,
                    color: isEnabled
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down,
                  size: 14,
                  color: isEnabled
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTooltipWidget(
      ThemeData theme, String presetContent, bool isEnabled,) {
    if (!isEnabled) {
      return Text(
        context.l10n.ucPreset_disabled,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 12,
        ),
      );
    }

    // 检查预设内容是否包含 nsfw
    final hasNsfw = presetContent.toLowerCase().contains('nsfw');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.ucPreset_addToNegative,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          presetContent,
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontSize: 11,
          ),
        ),
        // 如果包含 nsfw，显示提示信息
        if (hasNsfw) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Text(
              context.l10n.ucPreset_nsfwHint,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
