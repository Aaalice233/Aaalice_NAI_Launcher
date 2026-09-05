import 'package:flutter/material.dart';

/// Keeps the glow on the glyph while the entire button is the hover target.
class PromptAssistantHoverIcon extends StatefulWidget {
  const PromptAssistantHoverIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.buttonBuilder,
  });

  final IconData icon;
  final double size;
  final Widget Function(Widget icon) buttonBuilder;

  @override
  State<PromptAssistantHoverIcon> createState() =>
      _PromptAssistantHoverIconState();
}

class _PromptAssistantHoverIconState extends State<PromptAssistantHoverIcon>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _hovered = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_hovered && !_reduceMotion) {
      _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0;
    }
  }

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) return;
    setState(() => _hovered = value);
    _syncAnimation();
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _setHovered(true),
    onExit: (_) => _setHovered(false),
    child: widget.buttonBuilder(
      AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          final intensity = _reduceMotion
              ? 0.5
              : Curves.easeInOut.transform(_breath.value);
          final glow = Theme.of(context).colorScheme.primary;
          return Icon(
            widget.icon,
            size: widget.size,
            shadows: _hovered
                ? [
                    Shadow(
                      color: glow.withValues(alpha: 0.5 + intensity * 0.25),
                      blurRadius: 2 + intensity * 2,
                    ),
                    Shadow(
                      color: glow.withValues(alpha: 0.25 + intensity * 0.3),
                      blurRadius: 5 + intensity * 5,
                    ),
                  ]
                : null,
          );
        },
      ),
    ),
  );
}
