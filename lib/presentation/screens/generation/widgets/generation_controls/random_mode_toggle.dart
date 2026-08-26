import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

/// 抽卡模式开关
class RandomModeToggle extends ConsumerStatefulWidget {
  final bool enabled;

  const RandomModeToggle({super.key, required this.enabled});

  @override
  ConsumerState<RandomModeToggle> createState() => _RandomModeToggleState();
}

class _RandomModeToggleState extends ConsumerState<RandomModeToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RandomModeToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return IconButton(
      tooltip: widget.enabled
          ? context.l10n.randomMode_enabledTip
          : context.l10n.randomMode_disabledTip,
      onPressed: () {
        ref.read(randomPromptModeProvider.notifier).toggle();
        if (!widget.enabled && !reducedMotion) {
          _controller.forward(from: 0);
        }
      },
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        backgroundColor: widget.enabled
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        foregroundColor: widget.enabled
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: AnimatedBuilder(
        animation: _rotateAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: reducedMotion ? 0 : _rotateAnimation.value * 3.14159,
            child: child,
          );
        },
        child: const Icon(Icons.casino_outlined, size: 20),
      ),
    );
  }
}
