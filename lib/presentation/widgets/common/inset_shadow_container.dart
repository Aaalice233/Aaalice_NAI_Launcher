import 'input_surface_container.dart';

/// Backward-compatible alias for the former recessed input surface.
///
/// New code should use [InputSurfaceContainer]. Shadow parameters are retained
/// only so existing callers compile; resting surfaces remain borderless and
/// only focus/error state paints an inward glow.
@Deprecated(
  'Use InputSurfaceContainer; editable controls no longer use resting shadows.',
)
class InsetShadowContainer extends InputSurfaceContainer {
  const InsetShadowContainer({
    super.key,
    required super.child,
    super.borderRadius,
    super.width,
    super.height,
    super.constraints,
    this.shadowDepth,
    this.shadowBlur,
    super.enabled,
    super.backgroundColor,
    super.borderColor,
    super.borderWidth,
    super.padding,
    super.hasError,
    super.isFocused,
  });

  @Deprecated('No longer used; only focus/error state renders an inner glow.')
  final double? shadowDepth;

  @Deprecated('No longer used; only focus/error state renders an inner glow.')
  final double? shadowBlur;
}
