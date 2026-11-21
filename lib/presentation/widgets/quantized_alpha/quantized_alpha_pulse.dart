import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'quantized_alpha_schedule.dart';

class QuantizedAlphaClock {
  QuantizedAlphaClock({required this.schedule})
    : _alpha = schedule.alphaAt(Duration.zero);

  final QuantizedAlphaSchedule schedule;
  final _pulses = <QuantizedAlphaPulse>{};
  Timer? _wakeTimer;
  Duration? _origin;
  Duration? _lastSample;
  double _alpha;

  @visibleForTesting
  bool get hasPendingWake => _wakeTimer != null;

  void _attach(QuantizedAlphaPulse pulse) {
    _pulses.add(pulse);
    pulse._publish(_alpha);
    if (_wakeTimer == null) pulse._wake();
  }

  void _detach(QuantizedAlphaPulse pulse) {
    _pulses.remove(pulse);
    if (_pulses.isNotEmpty) return;
    _wakeTimer?.cancel();
    _wakeTimer = null;
    _origin = null;
    _lastSample = null;
    _alpha = schedule.alphaAt(Duration.zero);
  }

  void _sample(QuantizedAlphaPulse pulse) {
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_lastSample == now) {
      pulse._publish(_alpha);
      return;
    }
    _lastSample = now;
    final elapsed = now - (_origin ??= now);
    _alpha = schedule.alphaAt(elapsed);
    for (final subscriber in _pulses) {
      if (!subscriber._isMuted) subscriber._publish(_alpha);
    }

    // 只由帧回调续期，全部静音后最后一次唤醒不会留下新计时器。
    _wakeTimer?.cancel();
    final next = schedule.nextChangeAfter(elapsed);
    _wakeTimer = next == null ? null : Timer(next - elapsed, _wake);
  }

  void _wake() {
    _wakeTimer = null;
    for (final pulse in _pulses) {
      pulse._wake();
    }
  }
}

/// 由共享时钟发布透明度，保留卡片自己的 Ticker 以接受 TickerMode 静音。
class QuantizedAlphaPulse extends ChangeNotifier
    implements ValueListenable<double> {
  QuantizedAlphaPulse({required TickerProvider vsync, required this.clock})
    : _value = clock.schedule.initialAlpha {
    _ticker = vsync.createTicker(_handleTick);
  }

  final QuantizedAlphaClock clock;
  late final Ticker _ticker;
  double _value;

  @override
  double get value => _value;

  bool get _isMuted => _ticker.muted;

  void repeat() {
    clock._attach(this);
  }

  void reset() {
    clock._detach(this);
    _ticker.stop();
    _publish(clock.schedule.initialAlpha);
  }

  void _handleTick(Duration _) {
    _ticker.stop();
    clock._sample(this);
  }

  void _wake() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _publish(double value) {
    if (value == _value) return;
    _value = value;
    if (!_isMuted) notifyListeners();
  }

  @override
  void dispose() {
    clock._detach(this);
    _ticker.dispose();
    super.dispose();
  }
}
