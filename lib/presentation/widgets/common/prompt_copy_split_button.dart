import 'package:flutter/material.dart';

/// Shared high-frequency copy action with a compact secondary menu.
class PromptCopySplitButton extends StatelessWidget {
  const PromptCopySplitButton({
    super.key,
    required this.primaryLabel,
    required this.menuTooltip,
    required this.onPressed,
    required this.menuChildren,
    this.style,
    this.menuButtonKey,
  });

  final String primaryLabel;
  final String menuTooltip;
  final VoidCallback? onPressed;
  final List<Widget> menuChildren;
  final ButtonStyle? style;
  final Key? menuButtonKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: style,
            onPressed: onPressed,
            icon: const Icon(Icons.content_copy_outlined, size: 18),
            label: Text(
              primaryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 4),
        MenuAnchor(
          menuChildren: menuChildren,
          builder: (context, controller, child) => IconButton.outlined(
            key: menuButtonKey,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: EdgeInsets.zero,
            tooltip: menuTooltip,
            onPressed: menuChildren.isEmpty
                ? null
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
            icon: const Icon(Icons.arrow_drop_down, size: 20),
          ),
        ),
      ],
    );
  }
}
