import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../themes/design_tokens.dart';
import '../../themes/theme_extension.dart';

class MobileGenerationGestures extends StatelessWidget {
  const MobileGenerationGestures({
    super.key,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onScrollNotification,
    required this.pointerActive,
    required this.dragOffset,
    required this.showHint,
    required this.child,
  });

  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;
  final NotificationListenerCallback<ScrollNotification> onScrollNotification;
  final bool pointerActive;
  final double dragOffset;
  final bool showHint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Listener(
      key: const ValueKey('generation-vertical-shortcuts'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: onPointerDown,
      onPointerMove: onPointerMove,
      onPointerUp: onPointerUp,
      onPointerCancel: onPointerCancel,
      child: NotificationListener<ScrollNotification>(
        onNotification: onScrollNotification,
        child: AnimatedContainer(
          duration: pointerActive || disableAnimations
              ? Duration.zero
              : theme.appTheme.normalDuration,
          curve: theme.appTheme.standardCurve,
          transform: Matrix4.translationValues(
            0,
            disableAnimations ? 0 : dragOffset,
            0,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              MobileGenerationGestureFeedback(
                dragOffset: dragOffset,
                showHint: showHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileGenerationGestureFeedback extends StatelessWidget {
  const MobileGenerationGestureFeedback({
    super.key,
    required this.dragOffset,
    required this.showHint,
  });

  final double dragOffset;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTheme = theme.appTheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final duration = disableAnimations ? Duration.zero : appTheme.fastDuration;
    final progress = (dragOffset.abs() / 44).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              key: const ValueKey('generation-prompt-gesture-feedback'),
              opacity: dragOffset > 0 ? progress : 0,
              duration: duration,
              curve: appTheme.standardCurve,
              child: _GestureLabel(
                icon: Icons.keyboard_arrow_down_rounded,
                label: context.l10n.generation_gestureEditPrompt,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedOpacity(
              key: const ValueKey('generation-agent-gesture-feedback'),
              opacity: dragOffset < 0 ? progress : 0,
              duration: duration,
              curve: appTheme.standardCurve,
              child: _GestureLabel(
                icon: Icons.keyboard_arrow_up_rounded,
                label: context.l10n.generation_gestureOpenAgent,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.72),
            child: AnimatedOpacity(
              key: const ValueKey('generation-gesture-hint'),
              opacity: showHint && dragOffset == 0 ? 1 : 0,
              duration: duration,
              curve: appTheme.standardCurve,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingSm,
                  vertical: DesignTokens.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.76,
                  ),
                  borderRadius: BorderRadius.circular(appTheme.controlRadius),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: DesignTokens.spacingSm,
                  runSpacing: DesignTokens.spacingXxs,
                  children: [
                    Text(
                      context.l10n.generation_gestureEditPrompt,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                    Text(
                      context.l10n.generation_gestureOpenAgent,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MobileVerticalCloseGesture extends StatefulWidget {
  const MobileVerticalCloseGesture({
    super.key,
    required this.closeDirection,
    required this.onClose,
    required this.child,
  });

  final AxisDirection closeDirection;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<MobileVerticalCloseGesture> createState() =>
      _MobileVerticalCloseGestureState();
}

class _MobileVerticalCloseGestureState
    extends State<MobileVerticalCloseGesture> {
  static const double _distance = 88;
  static const double _velocity = 900;
  static const double _minimumFlingDistance = 24;
  static const double _axisAdvantage = 1.35;

  Offset? _start;
  Offset? _lastPosition;
  bool _hapticSent = false;

  bool _isClosingDirection(double value) =>
      widget.closeDirection == AxisDirection.up ? value < 0 : value > 0;

  bool _isCommitted(Offset delta, double velocity) {
    final vertical = delta.dy.abs();
    final verticalWins = vertical >= delta.dx.abs() * _axisAdvantage;
    final distanceCommitted = vertical >= _distance;
    final flingCommitted =
        vertical >= _minimumFlingDistance &&
        velocity.abs() >= _velocity &&
        velocity.sign == delta.dy.sign;
    return verticalWins &&
        _isClosingDirection(delta.dy) &&
        (distanceCommitted || flingCommitted);
  }

  void _handleUpdate(DragUpdateDetails details) {
    final start = _start;
    _lastPosition = details.globalPosition;
    if (start == null || _hapticSent) return;
    final delta = details.globalPosition - start;
    if (_isCommitted(delta, 0)) {
      _hapticSent = true;
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _handleEnd(DragEndDetails details) {
    final start = _start;
    final lastPosition = _lastPosition;
    if (start == null || lastPosition == null) return;
    final delta = lastPosition - start;
    final committed = _isCommitted(delta, details.primaryVelocity ?? 0);
    if (committed && !_hapticSent) {
      _hapticSent = true;
      unawaited(HapticFeedback.lightImpact());
    }
    _start = null;
    _lastPosition = null;
    if (committed) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: (details) {
        _start = details.globalPosition;
        _lastPosition = details.globalPosition;
        _hapticSent = false;
      },
      onVerticalDragUpdate: _handleUpdate,
      onVerticalDragEnd: _handleEnd,
      onVerticalDragCancel: () {
        _start = null;
        _lastPosition = null;
        _hapticSent = false;
      },
      child: widget.child,
    );
  }
}

class _GestureLabel extends StatelessWidget {
  const _GestureLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      minimum: const EdgeInsets.all(DesignTokens.spacingXs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingSm,
          vertical: DesignTokens.spacingXs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(theme.appTheme.controlRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: DesignTokens.spacingXxs),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
