import 'package:flutter/material.dart';
import '../../adaptive/interaction_policy.dart';

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
    final height = (MediaQuery.textScalerOf(context).scale(12) * 1.4 + 20)
        .clamp(
          context.interactionPolicy.minimumControlExtent.clamp(
            48.0,
            double.infinity,
          ),
          double.infinity,
        );
    final outerShape =
        effectiveStyle.shape?.resolve(const <WidgetState>{}) ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        );
    final segmentStyle = effectiveStyle.copyWith(
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
      side: const WidgetStatePropertyAll(BorderSide.none),
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      maximumSize: const WidgetStatePropertyAll(Size.infinite),
      fixedSize: WidgetStatePropertyAll(Size.fromHeight(height)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );

    return SizedBox(
      height: height,
      child: Material(
        type: MaterialType.transparency,
        shape: outerShape,
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Center(
              child: SizedBox(
                width: 1,
                height: 24,
                child: ColoredBox(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                ),
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
                      minimumSize: WidgetStatePropertyAll(Size(48, height)),
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
