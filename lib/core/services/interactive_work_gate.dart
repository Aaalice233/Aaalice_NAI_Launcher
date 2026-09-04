import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum InteractiveWorkPriority { userVisible, normal, maintenance }

/// Keeps non-essential work out of active interaction and backgrounded windows.
class InteractiveWorkGate {
  InteractiveWorkGate._();

  @visibleForTesting
  InteractiveWorkGate.forTesting();

  static final InteractiveWorkGate instance = InteractiveWorkGate._();

  DateTime _lastInteraction = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_PendingIdleWork> _pending = <_PendingIdleWork>[];
  bool _draining = false;
  bool _windowFocused = true;
  Completer<void>? _queueChanged;

  void markInteraction() {
    _lastInteraction = DateTime.now();
    _signalStateChanged();
  }

  void setWindowFocused(bool isFocused) {
    _windowFocused = isFocused;
    if (isFocused) _lastInteraction = DateTime.now();
    _signalStateChanged();
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
    _queueChanged?.complete();
    _queueChanged = null;
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
          await Future.any<void>(<Future<void>>[
            Future<void>.delayed(remaining),
            changed.future,
          ]);
          if (identical(_queueChanged, changed)) _queueChanged = null;
          continue;
        }

        final pollInterval = _pending
            .map((work) => work.pollInterval)
            .reduce((a, b) => a < b ? a : b);
        await waitForIdle(
          quietPeriod: Duration.zero,
          pollInterval: pollInterval,
        );

        final selectionTime = DateTime.now();
        final ready =
            _pending
                .where((work) => !_eligibleAt(work).isAfter(selectionTime))
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

  DateTime _eligibleAt(_PendingIdleWork work) {
    final quietAt = _lastInteraction.add(work.quietPeriod);
    return quietAt.isAfter(work.notBefore) ? quietAt : work.notBefore;
  }

  Future<void> waitForIdle({
    Duration quietPeriod = const Duration(seconds: 2),
    Duration pollInterval = const Duration(milliseconds: 200),
  }) async {
    while (true) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      final isForeground =
          lifecycle == null || lifecycle == AppLifecycleState.resumed;
      final hasBeenQuiet =
          DateTime.now().difference(_lastInteraction) >= quietPeriod;
      final schedulerIdle =
          SchedulerBinding.instance.transientCallbackCount == 0;
      if (isForeground && _windowFocused && hasBeenQuiet && schedulerIdle) {
        return;
      }
      await Future<void>.delayed(pollInterval);
    }
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

/// Records pointer, scroll, and keyboard activity at the application boundary.
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
    if (state == AppLifecycleState.resumed) {
      InteractiveWorkGate.instance.markInteraction();
    }
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
