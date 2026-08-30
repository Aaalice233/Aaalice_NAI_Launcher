import 'dart:async';

import 'package:flutter/material.dart';

/// Keeps the Android root route in the app until a second committed back
/// action occurs within [exitWindow].
class AndroidRootBackGuard extends StatefulWidget {
  const AndroidRootBackGuard({
    super.key,
    required this.enabled,
    required this.resetKey,
    required this.onExitHint,
    required this.child,
    this.exitWindow = const Duration(seconds: 3),
  });

  final bool enabled;
  final Object? resetKey;
  final VoidCallback onExitHint;
  final Widget child;
  final Duration exitWindow;

  @override
  State<AndroidRootBackGuard> createState() => _AndroidRootBackGuardState();
}

class _AndroidRootBackGuardState extends State<AndroidRootBackGuard> {
  Timer? _resetTimer;
  bool _exitArmed = false;

  @override
  void didUpdateWidget(AndroidRootBackGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || oldWidget.resetKey != widget.resetKey) {
      _resetWithoutRebuild();
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handlePop(bool didPop) {
    if (didPop || !widget.enabled || _exitArmed) return;

    setState(() => _exitArmed = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(widget.exitWindow, _reset);
    widget.onExitHint();
  }

  void _reset() {
    if (!mounted || !_exitArmed) return;
    setState(() => _exitArmed = false);
    _resetTimer = null;
  }

  void _resetWithoutRebuild() {
    _resetTimer?.cancel();
    _resetTimer = null;
    _exitArmed = false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      // PopScope reads this before predictive back starts. Repeated callbacks
      // from the blocked attempt cannot turn that same attempt into an exit.
      canPop: !widget.enabled || _exitArmed,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: widget.child,
    );
  }
}
