import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/image_save_settings_provider.dart';

/// 自动保存图像开关芯片
///
/// Q萌可爱的胶囊样式，显示在生成控制栏左侧
/// 勾选后自动保存每次生成的图像到设置的保存路径
class AutoSaveToggleChip extends ConsumerStatefulWidget {
  /// 官网式布局的窄栏会压缩内边距和字号，但保留文字以便识别。
  final bool compact;

  const AutoSaveToggleChip({super.key, this.compact = false});

  @override
  ConsumerState<AutoSaveToggleChip> createState() => _AutoSaveToggleChipState();
}

class _AutoSaveToggleChipState extends ConsumerState<AutoSaveToggleChip>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isPressed = false;
  late AnimationController _checkController;
  late Animation<double> _checkAnimation;
  bool _disableAnimations = false;

  // Q萌配色
  static const _cuteOrange = Color(0xFFFF9F6B);
  static const _cuteOrangeDark = Color(0xFFFF8C4A);
  static const _cuteOrangeLight = Color(0xFFFFE4D4);
  static const _cuteOrangeBg = Color(0xFFFFF5EE);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (_disableAnimations == disableAnimations) return;
    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _checkController.stop();
      _checkController.value =
          ref.read(imageSaveSettingsNotifierProvider).autoSave ? 1 : 0;
    }
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
    if (_disableAnimations) {
      _checkController.value = isEnabled ? 1 : 0;
    } else if (isEnabled && !_checkController.isCompleted) {
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
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 8 : 12,
                vertical: widget.compact ? 5 : 7,
              ),
              decoration: BoxDecoration(
                gradient: isEnabled
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                _cuteOrangeDark.withValues(alpha: 0.25),
                                _cuteOrange.withValues(alpha: 0.18),
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
                            .withValues(alpha: isDark ? 0.5 : 0.6)
                      : theme.colorScheme.outline.withValues(
                          alpha: _isHovering ? 0.3 : 0.15,
                        ),
                  width: isEnabled ? 1.5 : 1,
                ),
                boxShadow: isEnabled && _isHovering
                    ? [
                        BoxShadow(
                          color: _cuteOrange.withValues(alpha: 0.25),
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
                  _buildCuteCheckbox(
                    theme,
                    isEnabled,
                    isDark,
                    compact: widget.compact,
                  ),
                  SizedBox(width: widget.compact ? 5 : 7),
                  // 文字
                  Text(
                    context.l10n.settings_autoSave,
                    style: TextStyle(
                      color: isEnabled
                          ? (isDark ? _cuteOrange : _cuteOrangeDark)
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: widget.compact ? 11.5 : 12.5,
                      letterSpacing: widget.compact ? 0.1 : 0.3,
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

  Widget _buildCuteCheckbox(
    ThemeData theme,
    bool isEnabled,
    bool isDark, {
    required bool compact,
  }) {
    Widget buildCheckbox(double progress) => Container(
      width: compact ? 16 : 18,
      height: compact ? 16 : 18,
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
              : theme.colorScheme.outline.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: _cuteOrange.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: isEnabled
          ? Center(
              child: Transform.scale(
                scale: progress,
                child: Transform.rotate(
                  angle: (1 - progress) * 0.3,
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

    if (_disableAnimations) return buildCheckbox(isEnabled ? 1 : 0);
    return AnimatedBuilder(
      animation: _checkAnimation,
      builder: (context, child) => buildCheckbox(_checkAnimation.value),
    );
  }

  String _buildTooltipMessage(
    BuildContext context,
    ImageSaveSettings settings,
  ) {
    final statusText = settings.autoSave
        ? context.l10n.common_enabled
        : context.l10n.common_disabled;

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
