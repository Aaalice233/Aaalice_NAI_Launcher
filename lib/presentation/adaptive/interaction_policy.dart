import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
  // A previously observed touch must not replace mouse/keyboard accelerators
  // with a persistent menu after the user returns to a precise pointer.
  bool get usesTouchActionMenu => touchAvailable && !usesAnchoredMenus;
  bool get keyboardNavigationActive => modality == InteractionModality.keyboard;

  bool isFocusVisible(Set<WidgetState> states) =>
      keyboardNavigationActive && states.contains(WidgetState.focused);

  bool isControlHighlighted(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.pressed) ||
      isFocusVisible(states);

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
  late final FocusHighlightStrategy _previousHighlightStrategy;

  @override
  void initState() {
    super.initState();
    _policy = widget.initialPolicy ?? InteractionPolicy.neutral;
    _previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.addEarlyKeyEventHandler(_handleKeyEvent);
    if (_policy.prefersTouchPresentation) {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
    }
  }

  @override
  void didUpdateWidget(InteractionPolicyScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPolicy != oldWidget.initialPolicy &&
        widget.initialPolicy != null) {
      _policy = widget.initialPolicy!;
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKeyEvent);
    FocusManager.instance.highlightStrategy = _previousHighlightStrategy;
    super.dispose();
  }

  void _handlePointer(PointerEvent event) {
    final next = _policy.withPointerDevice(event.kind);
    if (next.modality == InteractionModality.pointer ||
        next.modality == InteractionModality.touch) {
      // Flutter's desktop automatic mode groups mouse and keyboard together.
      // Keep the logical focus for navigation, but hide its keyboard-only ink
      // after pointer input, including focus restored by a closing menu route.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
    }
    if (next == _policy) return;
    setState(() => _policy = next);
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (!mounted) return KeyEventResult.ignored;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // The FocusManager has classified this key before early handlers run.
      // Reuse that classification so Android IME events are not mistaken for
      // an external keyboard, and never consume navigation or shortcut keys.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
      if (FocusManager.instance.highlightMode ==
          FocusHighlightMode.traditional) {
        final next = _policy.withModality(InteractionModality.keyboard);
        if (next != _policy) setState(() => _policy = next);
      }
    }
    return KeyEventResult.ignored;
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
