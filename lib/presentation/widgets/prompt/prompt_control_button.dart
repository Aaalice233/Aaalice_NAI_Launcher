import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
import '../../themes/prompt_control_colors.dart';
import '../../themes/theme_extension.dart';

/// Common interaction and tonal states for prompt tabs and source selectors.
/// The caller owns the action and content; keyboard, focus and touch feedback
/// use the same Material button behavior across all five entry points.
class PromptControlButton extends StatefulWidget {
  const PromptControlButton({
    super.key,
    required this.color,
    required this.active,
    required this.onPressed,
    required this.builder,
    required this.padding,
    this.onLongPress,
    this.selected,
  });

  final Color color;
  final bool active;
  final bool? selected;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Widget Function(PromptControlColors colors) builder;

  @override
  State<PromptControlButton> createState() => _PromptControlButtonState();
}

class _PromptControlButtonState extends State<PromptControlButton> {
  final _states = WidgetStatesController();

  @override
  void initState() {
    super.initState();
    _states.addListener(_stateChanged);
  }

  void _stateChanged() => setState(() {});

  @override
  void dispose() {
    _states.removeListener(_stateChanged);
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final states = _states.value;
    final tokens = Theme.of(context).appTheme;
    final colors = PromptControlColors(
      Theme.of(context),
      widget.color,
      active: widget.active,
      hovered:
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed),
    );
    final extent = context.interactionPolicy.minimumControlExtent.clamp(
      44.0,
      double.infinity,
    );
    return Semantics(
      selected: widget.selected,
      child: TextButton(
        statesController: _states,
        onPressed: widget.onPressed,
        onLongPress: widget.onLongPress,
        style: TextButton.styleFrom(
          minimumSize: Size.square(extent),
          padding: widget.padding,
          backgroundColor: colors.background,
          foregroundColor: colors.foreground,
          overlayColor: Colors.transparent,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : tokens.fastDuration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.controlRadius),
          ),
          side: states.contains(WidgetState.focused)
              ? BorderSide(color: colors.accent)
              : BorderSide.none,
        ),
        child: widget.builder(colors),
      ),
    );
  }
}
