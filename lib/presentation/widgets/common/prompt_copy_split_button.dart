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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveStyle =
        (theme.outlinedButtonTheme.style ?? const ButtonStyle()).merge(style);
    final outerShape =
        effectiveStyle.shape?.resolve(const <WidgetState>{}) ??
        const RoundedRectangleBorder();
    final segmentStyle = effectiveStyle.copyWith(
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
      side: const WidgetStatePropertyAll(BorderSide.none),
    );

    return SizedBox(
      height: 48,
      child: Material(
        type: MaterialType.transparency,
        shape: outerShape,
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: segmentStyle,
                onPressed: onPressed,
                icon: const Icon(Icons.content_copy_outlined, size: 18),
                label: Text(
                  primaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(
              width: 1,
              height: 24,
              child: ColoredBox(
                color: colorScheme.outlineVariant.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(
              width: 48,
              child: MenuAnchor(
                menuChildren: menuChildren,
                builder: (context, controller, child) => Tooltip(
                  message: menuTooltip,
                  child: OutlinedButton(
                    key: menuButtonKey,
                    style: segmentStyle.copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    ),
                    onPressed: menuChildren.isEmpty
                        ? null
                        : () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                    child: AnimatedRotation(
                      turns: controller.isOpen ? 0.5 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      child: const Icon(Icons.expand_more_rounded, size: 19),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
