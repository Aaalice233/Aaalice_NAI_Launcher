import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../core/utils/localization_extension.dart';
import '../../providers/image_save_settings_provider.dart';

/// 自动保存图像开关芯片
///
/// Q萌可爱的胶囊样式，显示在生成控制栏左侧
/// 勾选后自动保存每次生成的图像到设置的保存路径
class AutoSaveToggleChip extends ConsumerStatefulWidget {
  const AutoSaveToggleChip({super.key});

  @override
  ConsumerState<AutoSaveToggleChip> createState() => _AutoSaveToggleChipState();
}

class _AutoSaveToggleChipState extends ConsumerState<AutoSaveToggleChip>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isPressed = false;
  late AnimationController _checkController;
  late Animation<double> _checkAnimation;

  // Q萌配色
  static const _cuteOrange = Color(0xFFFF9F6B);
  static const _cuteOrangeDark = Color(0xFFFF8C4A);
  static const _cuteOrangeLight = Color(0xFFFFE4D4);
  static const _cuteOrangeBg = Color(0xFFFFF5EE);
  static const _sparkleColor = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
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
    final isDark = theme.brightness == Brightness.dark;
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
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _handleTap();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: isEnabled
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                _cuteOrangeDark.withOpacity(0.25),
                                _cuteOrange.withOpacity(0.18),
                              ]
                            : [_cuteOrangeLight, _cuteOrangeBg],
                      )
                    : null,
                color: isEnabled
                    ? null
                    : (_isHovering
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.surfaceContainerHigh),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isEnabled
                      ? (_isHovering ? _cuteOrangeDark : _cuteOrange)
                          .withOpacity(isDark ? 0.5 : 0.6)
                      : theme.colorScheme.outline
                          .withOpacity(_isHovering ? 0.3 : 0.15),
                  width: isEnabled ? 1.5 : 1,
                ),
                boxShadow: isEnabled && _isHovering
                    ? [
                        BoxShadow(
                          color: _cuteOrange.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Q萌复选框
                  _buildCuteCheckbox(theme, isEnabled, isDark),
                  const SizedBox(width: 7),
                  // 文字
                  Text(
                    context.l10n.settings_autoSave,
                    style: TextStyle(
                      color: isEnabled
                          ? (isDark ? _cuteOrange : _cuteOrangeDark)
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                  // 启用时显示可爱的小星星
                  if (isEnabled) ...[
                    const SizedBox(width: 4),
                    _buildSparkle(isDark),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCuteCheckbox(ThemeData theme, bool isEnabled, bool isDark) {
    return AnimatedBuilder(
      animation: _checkAnimation,
      builder: (context, child) {
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            gradient: isEnabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_cuteOrange, _cuteOrangeDark],
                  )
                : null,
            color: isEnabled ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isEnabled
                  ? Colors.transparent
                  : theme.colorScheme.outline.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: _cuteOrange.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: isEnabled
              ? Center(
                  child: Transform.scale(
                    scale: _checkAnimation.value,
                    child: Transform.rotate(
                      angle: (1 - _checkAnimation.value) * 0.3,
                      child: const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildSparkle(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Transform.rotate(
            angle: (1 - value) * math.pi * 0.5,
            child: Icon(
              Icons.auto_awesome,
              size: 12,
              color: isDark ? _sparkleColor : _cuteOrangeDark.withOpacity(0.8),
            ),
          ),
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
