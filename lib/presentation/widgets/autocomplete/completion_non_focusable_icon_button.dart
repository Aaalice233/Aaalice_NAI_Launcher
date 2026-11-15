import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';

class CompletionNonFocusableIconButton extends StatefulWidget {
  const CompletionNonFocusableIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  State<CompletionNonFocusableIconButton> createState() =>
      _CompletionNonFocusableIconButtonState();
}

class _CompletionNonFocusableIconButtonState
    extends State<CompletionNonFocusableIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final precisePointerAvailable =
        context.interactionPolicy.precisePointerAvailable;
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: precisePointerAvailable
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: precisePointerAvailable
            ? (_) => setState(() => _hovered = false)
            : null,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered || widget.active
                ? colors.primary.withValues(alpha: widget.active ? 0.2 : 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            tooltip: widget.tooltip,
            visualDensity: context.interactionPolicy.touchAvailable
                ? VisualDensity.standard
                : VisualDensity.compact,
            constraints: BoxConstraints.tightFor(
              width: context.interactionPolicy.touchAvailable
                  ? context.interactionPolicy.minimumControlExtent
                  : 28,
              height: context.interactionPolicy.touchAvailable
                  ? context.interactionPolicy.minimumControlExtent
                  : 28,
            ),
            padding: EdgeInsets.zero,
            iconSize: context.interactionPolicy.touchAvailable ? 20 : 16,
            color: _hovered || widget.active
                ? colors.primary
                : colors.onSurfaceVariant,
            onPressed: widget.onPressed,
            icon: Icon(widget.icon),
          ),
        ),
      ),
    );
  }
}
