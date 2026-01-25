import 'package:flutter/material.dart';

/// Animation configuration constants for tag chip animations
class TagChipAnimationConfig {
  // Timing constants
  static const Duration hoverDuration = Duration(milliseconds: 150);
  static const Duration entranceDuration = Duration(milliseconds: 300);
  static const Duration staggerDelay = Duration(milliseconds: 50);
  static const Duration rippleDuration = Duration(milliseconds: 200);
  static const Duration weightChangeDuration = Duration(milliseconds: 300);
  static const Duration selectionDuration = Duration(milliseconds: 175);
  static const Duration dragDuration = Duration(milliseconds: 200);
  static const Duration heartJumpDuration = Duration(milliseconds: 400);
  static const Duration deleteDuration = Duration(milliseconds: 250);

  // Scale ranges
  static const double hoverScaleStart = 1.0;
  static const double hoverScaleEnd = 1.05;
  static const double dragScale = 1.05;
  static const double heartJumpScale = 1.3;

  // Opacity ranges
  static const double entranceOpacityStart = 0.0;
  static const double entranceOpacityEnd = 1.0;
  static const double deleteOpacityStart = 1.0;
  static const double deleteOpacityEnd = 0.0;

  // Offset ranges
  static const double entranceOffsetStart = -20.0;
  static const double entranceOffsetEnd = 0.0;

  // Curves
  static const Curve hoverCurve = Curves.easeOut;
  static const Curve entranceCurve = Curves.easeOutCubic;
  static const Curve selectionCurve = Curves.easeInOut;
  static const Curve dragCurve = Curves.easeOut;
  static const Curve weightChangeCurve = Curves.easeOutCubic;
  static const Curve heartJumpCurve = Curves.elasticOut;
  static const Curve deleteCurve = Curves.easeIn;

  // Shadow blur ranges
  static const double normalShadowBlur = 8.0;
  static const double hoverShadowBlur = 12.0;
  static const double dragShadowBlur = 16.0;

  // Shadow opacity ranges
  static const double normalShadowOpacity = 0.15;
  static const double hoverShadowOpacity = 0.25;
  static const double dragShadowOpacity = 0.4;
}

/// Creates a hover scale animation for tag chips
///
/// Returns an Animation<double> that scales from 1.0 to 1.05
/// Used with AnimatedBuilder and Transform.scale
Animation<double> createHoverScaleAnimation(AnimationController controller) {
  return Tween<double>(
    begin: TagChipAnimationConfig.hoverScaleStart,
    end: TagChipAnimationConfig.hoverScaleEnd,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: TagChipAnimationConfig.hoverCurve,
    ),
  );
}

/// Creates a shadow animation for hover effects
///
/// Returns an Animation<double> that controls shadow blur and opacity
/// Used with AnimatedBuilder to animate boxShadow
Animation<double> createHoverShadowAnimation(AnimationController controller) {
  return Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: TagChipAnimationConfig.hoverCurve,
    ),
  );
}

/// Creates a brightness animation for hover effects
///
/// Returns an Animation<double> that controls color brightness (0.0 to 0.1)
/// Used to increase brightness by 5-10% during hover
Animation<double> createHoverBrightnessAnimation(AnimationController controller) {
  return Tween<double>(
    begin: 0.0,
    end: 0.1,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: TagChipAnimationConfig.hoverCurve,
    ),
  );
}

/// Creates an entrance animation for tag loading
///
/// Returns an Animation<double> for fade-in effect
/// Combine with slide animation for full entrance effect
Animation<double> createEntranceOpacityAnimation(AnimationController controller) {
  return Tween<double>(
    begin: TagChipAnimationConfig.entranceOpacityStart,
    end: TagChipAnimationConfig.entranceOpacityEnd,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: TagChipAnimationConfig.entranceCurve,
    ),
  );
}

/// Creates a slide-up animation for tag entrance
///
/// Returns an Animation<Offset> that slides from -20 to 0 pixels vertically
/// Combine with opacity animation for full entrance effect
Animation<Offset> createEntranceSlideAnimation(AnimationController controller) {
  return Tween<Offset>(
    begin: const Offset(0, TagChipAnimationConfig.entranceOffsetStart),
    end: const Offset(0, TagChipAnimationConfig.entranceOffsetEnd),
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: TagChipAnimationConfig.entranceCurve,
    ),
  );
}

/// Creates a staggered entrance animation for a list of tags
///
/// [index] - The tag's index in the list
/// [controller] - The animation controller to use
///
/// Returns an Animation<double> with delay based on index (50ms * index)
Animation<double> createStaggeredEntranceAnimation({
  required int index,
  required AnimationController controller,
}) {
  final staggeredCurve = Interval(
    (index * 0.05).clamp(0.0, 0.95),
    ((index * 0.05) + 0.15).clamp(0.05, 1.0),
    curve: TagChipAnimationConfig.entranceCurve,
  );

  return Tween<double>(
    begin: TagChipAnimationConfig.entranceOpacityStart,
    end: TagChipAnimationConfig.entranceOpacityEnd,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: staggeredCurve,
    ),
  );
}

/// Creates a weight change animation (number rolling effect)
///
/// [beginValue] - Starting weight value
/// [endValue] - Ending weight value
/// [controller] - The animation controller to use
///
/// Returns an Animation<double> that interpolates between weight values
Animation<double> createWeightChangeAnimation({
  required double beginValue,
  required double endValue,
  required AnimationController controller,
}) {
  return Tween<double>(
    begin: beginValue,
    end: endValue,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: TagChipAnimationConfig.weightChangeCurve,
    ),
  );
}

/// Creates a heart jump animation for favorite button
///
/// Returns an Animation<double> that scales up to 1.3 and back with elastic effect
Animation<double> createHeartJumpAnimation(AnimationController controller) {
  return Tween<double>(
    begin: 1.0,
    end: TagChipAnimationConfig.heartJumpScale,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: TagChipAnimationConfig.heartJumpCurve,
    ),
  );
}

/// Creates a delete shrink animation
///
/// Returns an Animation<double> that controls both scale and opacity
Animation<double> createDeleteShrinkAnimation(AnimationController controller) {
  return Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: TagChipAnimationConfig.deleteCurve,
    ),
  );
}

/// Creates a drag lift animation
///
/// Returns an Animation<double> that scales to 1.05 for drag feedback
Animation<double> createDragLiftAnimation(AnimationController controller) {
  return Tween<double>(
    begin: 1.0,
    end: TagChipAnimationConfig.dragScale,
  ).animate(
    CurvedAnimation(
      parent: controller,
      curve: TagChipAnimationConfig.dragCurve,
    ),
  );
}

/// Builder for hover effect with scale and shadow
///
/// Wraps a child widget with animated scale and shadow on hover
/// Use this in conjunction with MouseRegion to trigger animation
class TagChipHoverBuilder extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final Animation<double> shadowAnimation;
  final Widget child;
  final Color tagColor;

  const TagChipHoverBuilder({
    super.key,
    required this.scaleAnimation,
    required this.shadowAnimation,
    required this.child,
    required this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scaleAnimation, shadowAnimation]),
      builder: (context, child) {
        final shadowBlur = TagChipAnimationConfig.normalShadowBlur +
            (TagChipAnimationConfig.hoverShadowBlur -
                    TagChipAnimationConfig.normalShadowBlur) *
                shadowAnimation.value;

        final shadowOpacity = TagChipAnimationConfig.normalShadowOpacity +
            (TagChipAnimationConfig.hoverShadowOpacity -
                    TagChipAnimationConfig.normalShadowOpacity) *
                shadowAnimation.value;

        return Transform.scale(
          scale: scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: tagColor.withOpacity(shadowOpacity),
                  blurRadius: shadowBlur,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Builder for entrance animation with fade and slide
///
/// Wraps a child widget with fade-in and slide-up animation
/// Use this for tag loading animations
class TagChipEntranceBuilder extends StatelessWidget {
  final Animation<double> opacityAnimation;
  final Animation<Offset>? slideAnimation;
  final Widget child;

  const TagChipEntranceBuilder({
    super.key,
    required this.opacityAnimation,
    this.slideAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (slideAnimation != null) {
      return AnimatedBuilder(
        animation: Listenable.merge([opacityAnimation, slideAnimation!]),
        builder: (context, child) {
          return Opacity(
            opacity: opacityAnimation.value,
            child: Transform.translate(
              offset: slideAnimation!.value,
              child: child,
            ),
          );
        },
        child: child,
      );
    }

    return AnimatedBuilder(
      animation: opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: opacityAnimation.value,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Builder for weight change animation with number interpolation
///
/// Displays animated weight value as it changes
/// Use this to show smooth transitions between weight values
class TagChipWeightAnimationBuilder extends StatelessWidget {
  final Animation<double> weightAnimation;
  final Widget Function(double weight) builder;

  const TagChipWeightAnimationBuilder({
    super.key,
    required this.weightAnimation,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: weightAnimation,
      builder: (context, child) {
        return builder(weightAnimation.value);
      },
    );
  }
}

/// Builder for favorite heart jump animation
///
/// Wraps the favorite icon with a jump animation on tap
class TagChipHeartJumpBuilder extends StatelessWidget {
  final Animation<double> jumpAnimation;
  final Widget child;

  const TagChipHeartJumpBuilder({
    super.key,
    required this.jumpAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: jumpAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: jumpAnimation.value,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Builder for delete shrink and fade animation
///
/// Wraps the tag chip with shrink and fade animation on delete
class TagChipDeleteAnimationBuilder extends StatelessWidget {
  final Animation<double> shrinkAnimation;
  final Widget child;

  const TagChipDeleteAnimationBuilder({
    super.key,
    required this.shrinkAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shrinkAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: shrinkAnimation.value,
          child: Opacity(
            opacity: shrinkAnimation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Controller factory for creating animation controllers with proper lifecycle
///
/// Provides a convenient way to create and dispose animation controllers
/// with the correct vsync and duration
class TagChipAnimationControllerFactory {
  /// Creates an animation controller for hover effects
  static AnimationController createHoverController(TickerProvider vsync) {
    return AnimationController(
      duration: TagChipAnimationConfig.hoverDuration,
      vsync: vsync,
    );
  }

  /// Creates an animation controller for entrance animations
  static AnimationController createEntranceController(TickerProvider vsync) {
    return AnimationController(
      duration: TagChipAnimationConfig.entranceDuration,
      vsync: vsync,
    );
  }

  /// Creates an animation controller for weight change animations
  static AnimationController createWeightChangeController(TickerProvider vsync) {
    return AnimationController(
      duration: TagChipAnimationConfig.weightChangeDuration,
      vsync: vsync,
    );
  }

  /// Creates an animation controller for heart jump animations
  static AnimationController createHeartJumpController(TickerProvider vsync) {
    return AnimationController(
      duration: TagChipAnimationConfig.heartJumpDuration,
      vsync: vsync,
    );
  }

  /// Creates an animation controller for delete animations
  static AnimationController createDeleteController(TickerProvider vsync) {
    return AnimationController(
      duration: TagChipAnimationConfig.deleteDuration,
      vsync: vsync,
    );
  }

  /// Creates an animation controller for drag lift animations
  static AnimationController createDragController(TickerProvider vsync) {
    return AnimationController(
      duration: TagChipAnimationConfig.dragDuration,
      vsync: vsync,
    );
  }

  /// Creates an animation controller for shimmer loading animation
  static AnimationController createShimmerController(TickerProvider vsync) {
    return AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: vsync,
    );
  }
}

/// Builder for skeleton loading shimmer animation
///
/// Displays a shimmering loading placeholder that mimics tag chip appearance
/// Use this for loading states in tag views
class TagChipShimmerBuilder extends StatelessWidget {
  final Animation<double> shimmerAnimation;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const TagChipShimmerBuilder({
    super.key,
    required this.shimmerAnimation,
    this.width = 80,
    this.height = 32,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultBaseColor = baseColor ?? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3);
    final defaultHighlightColor = highlightColor ?? theme.colorScheme.onSurface.withOpacity(0.1);

    return AnimatedBuilder(
      animation: shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                -1.0,
                shimmerAnimation.value - 0.3,
                shimmerAnimation.value,
                shimmerAnimation.value + 0.3,
                1.0,
              ],
              colors: [
                defaultBaseColor,
                defaultBaseColor,
                defaultHighlightColor,
                defaultBaseColor,
                defaultBaseColor,
              ],
            ),
          ),
        );
      },
    );
  }
}
