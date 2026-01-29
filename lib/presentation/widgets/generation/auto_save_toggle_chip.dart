import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/image_save_settings_provider.dart';

/// 自动保存图像开关芯片
///
/// 精致的复选框样式，显示在生成控制栏左侧
/// 勾选后自动保存每次生成的图像到设置的保存路径
class AutoSaveToggleChip extends ConsumerStatefulWidget {
  const AutoSaveToggleChip({super.key});

  @override
  ConsumerState<AutoSaveToggleChip> createState() => _AutoSaveToggleChipState();
}

class _AutoSaveToggleChipState extends ConsumerState<AutoSaveToggleChip>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _checkController;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saveSettings = ref.watch(imageSaveSettingsNotifierProvider);
    final isEnabled = saveSettings.autoSave;

    // 同步动画状态
    if (isEnabled && !_checkController.isCompleted) {
      _checkController.forward();
    } else if (!isEnabled && _checkController.value > 0) {
      _checkController.reverse();
    }

    // 构建 Tooltip 消息
    final tooltipMessage = _buildTooltipMessage(context, saveSettings);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltipMessage,
        preferBelow: true,
        child: GestureDetector(
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _getBackgroundColor(theme, isEnabled),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEnabled
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : theme.colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 精致的复选框
                _buildCheckbox(theme, isEnabled),
                const SizedBox(width: 6),
                // 文字
                Text(
                  context.l10n.settings_autoSave,
                  style: TextStyle(
                    color: isEnabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(ThemeData theme, bool isEnabled) {
    if (isEnabled) {
      return _isHovering
          ? theme.colorScheme.primary.withOpacity(0.18)
          : theme.colorScheme.primary.withOpacity(0.12);
    }
    return _isHovering
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHigh;
  }

  Widget _buildCheckbox(ThemeData theme, bool isEnabled) {
    return AnimatedBuilder(
      animation: _checkAnimation,
      builder: (context, child) {
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isEnabled ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isEnabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: isEnabled
              ? Center(
                  child: Transform.scale(
                    scale: _checkAnimation.value,
                    child: Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  String _buildTooltipMessage(
    BuildContext context,
    ImageSaveSettings settings,
  ) {
    final statusText = settings.autoSave ? '已开启' : '已关闭';

    if (settings.autoSave && settings.hasCustomPath) {
      return '${context.l10n.settings_autoSaveSubtitle}\n$statusText\n${context.l10n.settings_imageSavePath}: ${settings.customPath}';
    }

    return '${context.l10n.settings_autoSaveSubtitle}\n$statusText';
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    ref.read(imageSaveSettingsNotifierProvider.notifier).toggleAutoSave();
  }
}
