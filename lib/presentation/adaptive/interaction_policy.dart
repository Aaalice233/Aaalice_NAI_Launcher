import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

enum InteractionModality { unknown, touch, pointer, keyboard }

/// Presentation policy derived only from input observed during this session.
@immutable
class InteractionPolicy {
  const InteractionPolicy({
    required this.modality,
    required this.touchAvailable,
    required this.precisePointerAvailable,
  });

  static const neutral = InteractionPolicy(
    modality: InteractionModality.unknown,
    touchAvailable: false,
    precisePointerAvailable: false,
  );

  static const touchFirst = InteractionPolicy(
    modality: InteractionModality.touch,
    touchAvailable: true,
    precisePointerAvailable: false,
  );

  final InteractionModality modality;
  final bool touchAvailable;
  final bool precisePointerAvailable;

  bool get prefersTouchPresentation => modality == InteractionModality.touch;
  bool get usesAnchoredMenus =>
      precisePointerAvailable && !prefersTouchPresentation;

  /// Touch-equivalent entry points stay mounted after touch is observed even
  /// when the user later switches to a mouse or keyboard.
  bool get shouldExposeTouchAlternatives => touchAvailable;
  bool get keyboardNavigationActive => modality == InteractionModality.keyboard;

  /// Stable target geometry: once touch is observed, later mouse/keyboard input
  /// keeps touch-safe hit areas instead of making the interface jump in size.
  double get minimumControlExtent => touchAvailable ? 48 : 40;

  InteractionPolicy withPointerDevice(PointerDeviceKind kind) {
    return switch (kind) {
      PointerDeviceKind.touch ||
      PointerDeviceKind.stylus ||
      PointerDeviceKind.invertedStylus => InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: precisePointerAvailable,
      ),
      PointerDeviceKind.mouse ||
      PointerDeviceKind.trackpad => InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: touchAvailable,
        precisePointerAvailable: true,
      ),
      _ => this,
    };
  }

  InteractionPolicy withModality(InteractionModality value) {
    if (value == modality) return this;
    return InteractionPolicy(
      modality: value,
      touchAvailable: touchAvailable,
      precisePointerAvailable: precisePointerAvailable,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is InteractionPolicy &&
        other.modality == modality &&
        other.touchAvailable == touchAvailable &&
        other.precisePointerAvailable == precisePointerAvailable;
  }

  @override
  int get hashCode =>
      Object.hash(modality, touchAvailable, precisePointerAvailable);
}

/// Tracks the current input modality for the whole presentation tree while
/// retaining every input capability observed during the session.
class InteractionPolicyScope extends StatefulWidget {
  const InteractionPolicyScope({
    super.key,
    required this.child,
    this.initialPolicy,
  });

  final Widget child;
  final InteractionPolicy? initialPolicy;

  static InteractionPolicy of(BuildContext context) {
    return maybeOf(context) ?? InteractionPolicy.neutral;
  }

  static InteractionPolicy? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InteractionPolicyInherited>()
        ?.readPolicy();
  }

  @override
  State<InteractionPolicyScope> createState() => _InteractionPolicyScopeState();
}

class _InteractionPolicyScopeState extends State<InteractionPolicyScope> {
  late InteractionPolicy _policy;
  InteractionModality? _lastPointerModality;

  @override
  void initState() {
    super.initState();
    _policy = widget.initialPolicy ?? InteractionPolicy.neutral;
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void didUpdateWidget(InteractionPolicyScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPolicy != oldWidget.initialPolicy &&
        widget.initialPolicy != null) {
      _policy = widget.initialPolicy!;
      _lastPointerModality = switch (_policy.modality) {
        InteractionModality.touch ||
        InteractionModality.pointer => _policy.modality,
        InteractionModality.unknown || InteractionModality.keyboard => null,
      };
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    super.dispose();
  }

  void _handlePointer(PointerEvent event) {
    final next = _policy.withPointerDevice(event.kind);
    if (next == _policy) return;
    _lastPointerModality = next.modality;
    setState(() => _policy = next);
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    if (!mounted) return;
    final nextModality = mode == FocusHighlightMode.traditional
        ? InteractionModality.keyboard
        : (_lastPointerModality ?? _policy.modality);
    final next = _policy.withModality(nextModality);
    if (next == _policy) return;
    setState(() => _policy = next);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointer,
      onPointerHover: _handlePointer,
      child: _InteractionPolicyInherited(
        policySnapshot: _policy,
        readPolicy: () => _policy,
        child: widget.child,
      ),
    );
  }
}

class _InteractionPolicyInherited extends InheritedWidget {
  const _InteractionPolicyInherited({
    required this.policySnapshot,
    required this.readPolicy,
    required super.child,
  });

  final InteractionPolicy policySnapshot;
  final InteractionPolicy Function() readPolicy;

  @override
  bool updateShouldNotify(_InteractionPolicyInherited oldWidget) {
    return policySnapshot != oldWidget.policySnapshot;
  }
}

extension InteractionPolicyBuildContext on BuildContext {
  InteractionPolicy get interactionPolicy => InteractionPolicyScope.of(this);
}
