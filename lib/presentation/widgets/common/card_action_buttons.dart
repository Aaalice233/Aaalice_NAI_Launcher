import 'package:flutter/material.dart';

import '../../../core/platform/platform_capabilities.dart';

/// 卡片操作按钮配置
class CardActionButtonConfig {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;
  final bool isLoading;

  const CardActionButtonConfig({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.isLoading = false,
  });
}

/// 卡片操作按钮组。高频悬浮操作必须即时响应，不做延迟或出现动画。
class CardActionButtons extends StatelessWidget {
  final List<CardActionButtonConfig> buttons;
  final bool visible;
  final Axis direction;

  const CardActionButtons({
    super.key,
    required this.buttons,
    required this.visible,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();

    // Touch users cannot reveal hover-only controls. Keep one compact, persistent
    // entry point and expose every existing card action through a 48dp menu.
    if (PlatformCapabilities.current.hasTouchInput) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: PopupMenuButton<CardActionButtonConfig>(
          tooltip: MaterialLocalizations.of(context).showMenuTooltip,
          constraints: const BoxConstraints(minWidth: 220),
          onSelected: (button) => button.onPressed(),
          itemBuilder: (context) => [
            for (final button in buttons)
              PopupMenuItem<CardActionButtonConfig>(
                value: button,
                enabled: !button.isLoading,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: button.isLoading
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(button.icon, color: button.iconColor),
                  title: Text(button.tooltip),
                ),
              ),
          ],
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
        ),
      );
    }

    // Remove hidden tooltips from the overlay together with their card. Keeping
    // transparent buttons mounted lets a tooltip linger while the pointer has
    // already moved to another card, producing duplicate labels.
    if (!visible) return const SizedBox.shrink();

    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final button in buttons)
          Padding(
            padding: EdgeInsets.only(
              left: direction == Axis.horizontal ? 4 : 0,
              top: direction == Axis.vertical ? 4 : 0,
            ),
            child: _CardActionButton(config: button),
          ),
      ],
    );
  }
}

/// 单个卡片操作按钮（仅保留即时颜色反馈）
class _CardActionButton extends StatefulWidget {
  final CardActionButtonConfig config;

  const _CardActionButton({required this.config});

  @override
  State<_CardActionButton> createState() => _CardActionButtonState();
}

class _CardActionButtonState extends State<_CardActionButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.config.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.config.isLoading ? null : widget.config.onPressed,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isHovering
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: widget.config.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    widget.config.icon,
                    color: widget.config.iconColor ?? Colors.white,
                    size: 16,
                  ),
          ),
        ),
      ),
    );
  }
}
