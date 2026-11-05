import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../utils/app_background_return.dart';
import '../utils/app_lifecycle_visibility.dart';

enum InteractiveWorkPriority { userVisible, normal, maintenance }

/// Keeps non-essential work out of active interaction and hidden windows.
///
/// A visible window without focus has no interaction of its own: the user is
/// working in another window, so earlier input no longer delays queued work.
class InteractiveWorkGate {
  InteractiveWorkGate._();

  @visibleForTesting
  InteractiveWorkGate.forTesting();

  static final InteractiveWorkGate instance = InteractiveWorkGate._();

  DateTime _lastInteraction = DateTime.fromMillisecondsSinceEpoch(0);
  // Windows scrolls an unfocused window under the cursor; that input counts.
  DateTime _lastUnfocusedInteraction = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_PendingIdleWork> _pending = <_PendingIdleWork>[];
  final AppBackgroundReturnTracker _backgroundReturn =
      AppBackgroundReturnTracker();
  bool _draining = false;
  bool _windowFocused = true;
  Completer<void>? _queueChanged;

  void markInteraction() {
    final now = DateTime.now();
    _lastInteraction = now;
    if (!_isFocused) _lastUnfocusedInteraction = now;
    _signalStateChanged();
  }

  /// Regaining focus alone is not an interaction.
  void setWindowFocused(bool isFocused) {
    _windowFocused = isFocused;
    _signalStateChanged();
  }

  void handleLifecycleStateChanged(AppLifecycleState state) {
    // Returning from the background counts even before focus; refocus does not.
    if (_backgroundReturn.returnedToView(state)) {
      markInteraction();
    } else {
      _signalStateChanged();
    }
  }

  void _signalStateChanged() {
    _queueChanged?.complete();
    _queueChanged = null;
  }

  /// Admits one task at a time after its delay and a genuine interaction-free
  /// period. Tasks are ordered by readiness and priority rather than by caller
  /// registration order.
  Future<void> runWhenIdle({
    Duration minimumDelay = Duration.zero,
    Duration quietPeriod = const Duration(seconds: 2),
    Duration pollInterval = const Duration(milliseconds: 200),
    InteractiveWorkPriority priority = InteractiveWorkPriority.normal,
    required Future<void> Function() action,
  }) {
    final work = _PendingIdleWork(
      notBefore: DateTime.now().add(minimumDelay),
      quietPeriod: quietPeriod,
      pollInterval: pollInterval,
      priority: priority,
      action: action,
    );
    _pending.add(work);
    _signalStateChanged();
    unawaited(_drain());
    return work.completer.future;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final now = DateTime.now();
        _pending.sort((a, b) => _eligibleAt(a).compareTo(_eligibleAt(b)));
        final remaining = _eligibleAt(_pending.first).difference(now);
        if (remaining > Duration.zero) {
          final changed = Completer<void>();
          _queueChanged = changed;
          final due = Timer(remaining, _signalStateChanged);
          await changed.future;
          due.cancel();
          continue;
        }

        final pollInterval = _pending
            .map((work) => work.pollInterval)
            .reduce((a, b) => a < b ? a : b);
        if (!await _waitForAdmission(pollInterval)) continue;

        final selectionTime = DateTime.now();
        final ready =
            _pending
                .where((work) => _isAdmissible(work, selectionTime))
                .toList()
              ..sort((a, b) {
                final priorityOrder = a.priority.index.compareTo(
                  b.priority.index,
                );
                if (priorityOrder != 0) return priorityOrder;
                return _eligibleAt(a).compareTo(_eligibleAt(b));
              });
        if (ready.isEmpty) continue;
        final work = ready.first;
        _pending.remove(work);
        try {
          await work.action();
          work.completer.complete();
        } catch (error, stackTrace) {
          work.completer.completeError(error, stackTrace);
        }
      }
    } finally {
      _draining = false;
      if (_pending.isNotEmpty) unawaited(_drain());
    }
  }

  /// Returns false once nothing pending is due any more, so the caller can
  /// sleep until the next task becomes due instead of polling.
  Future<bool> _waitForAdmission(Duration pollInterval) async {
    while (true) {
      final now = DateTime.now();
      if (_pending.any((work) => _isAdmissible(work, now))) return true;
      if (_pending.every((work) => _eligibleAt(work).isAfter(now))) {
        return false;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  bool _isAdmissible(_PendingIdleWork work, DateTime now) =>
      !_eligibleAt(work).isAfter(now) && _isIdle;

  DateTime _eligibleAt(_PendingIdleWork work) {
    final lastInteraction = _isFocused
        ? _lastInteraction
        : _lastUnfocusedInteraction;
    final quietAt = lastInteraction.add(work.quietPeriod);
    return quietAt.isAfter(work.notBefore) ? quietAt : work.notBefore;
  }

  bool get _isFocused {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        _windowFocused;
  }

  // Animations count only while focused, or a looping one stalls work forever.
  bool get _isIdle {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!AppLifecycleVisibility.isVisible(lifecycle)) return false;
    return !_isFocused || SchedulerBinding.instance.transientCallbackCount == 0;
  }
}

class _PendingIdleWork {
  _PendingIdleWork({
    required this.notBefore,
    required this.quietPeriod,
    required this.pollInterval,
    required this.priority,
    required this.action,
  });

  final DateTime notBefore;
  final Duration quietPeriod;
  final Duration pollInterval;
  final InteractiveWorkPriority priority;
  final Future<void> Function() action;
  final Completer<void> completer = Completer<void>();
}

/// Records pointer, scroll, keyboard and lifecycle activity at the application
/// boundary.
class InteractiveActivityObserver extends StatefulWidget {
  const InteractiveActivityObserver({super.key, required this.child});

  final Widget child;

  @override
  State<InteractiveActivityObserver> createState() =>
      _InteractiveActivityObserverState();
}

class _InteractiveActivityObserverState
    extends State<InteractiveActivityObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    InteractiveWorkGate.instance.handleLifecycleStateChanged(state);
  }

  bool _handleKeyEvent(KeyEvent event) {
    InteractiveWorkGate.instance.markInteraction();
    return false;
  }

  void _markPointerActivity(PointerEvent event) {
    InteractiveWorkGate.instance.markInteraction();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _markPointerActivity,
      onPointerMove: _markPointerActivity,
      onPointerSignal: _markPointerActivity,
      child: widget.child,
    );
  }
}
