import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/image/image_postprocess_phase.dart';

String imagePostprocessLabel(
  BuildContext context,
  ImagePostprocessPhase phase,
) => switch (phase) {
  ImagePostprocessPhase.preparing =>
    context.l10n.generation_enhancementPreparing,
  ImagePostprocessPhase.enhancing => context.l10n.generation_enhancementRunning,
  ImagePostprocessPhase.finalizing =>
    context.l10n.generation_enhancementFinalizing,
};

class ImagePostprocessIndicator extends StatefulWidget {
  const ImagePostprocessIndicator({super.key, required this.phase});
  final ImagePostprocessPhase phase;

  @override
  State<ImagePostprocessIndicator> createState() =>
      _ImagePostprocessIndicatorState();
}

class _ImagePostprocessIndicatorState extends State<ImagePostprocessIndicator>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .64),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) => ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => SweepGradient(
                    transform: GradientRotation(_animation.value * math.pi * 2),
                    colors: const [
                      Colors.white38,
                      Colors.white,
                      Colors.white38,
                    ],
                  ).createShader(bounds),
                  child: child,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 32,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.white54, blurRadius: 14)],
                ),
              ),
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  imagePostprocessLabel(context, widget.phase),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
