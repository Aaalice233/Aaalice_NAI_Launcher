import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'quantized_alpha_schedule.dart';

/// 按 [QuantizedAlphaSchedule] 往复的透明度，只在台阶变化的那一帧唤醒 Ticker。
///
/// 持续运行的 Ticker 每个 vsync 都会让整窗重新合成；两次台阶之间改由计时器等待，
/// 不排帧。仍用 Ticker 取帧时间并接受 TickerMode 静音，后台页面不会被唤醒。
class QuantizedAlphaPulse extends ChangeNotifier
    implements ValueListenable<double> {
  QuantizedAlphaPulse({required TickerProvider vsync, required this.schedule})
    : _value = schedule.initialAlpha {
    _ticker = vsync.createTicker(_handleTick);
  }

  final QuantizedAlphaSchedule schedule;
  late final Ticker _ticker;
  Timer? _wakeTimer;
  Duration _elapsed = Duration.zero;
  Duration? _origin;
  bool _isRunning = false;
  double _value;

  @override
  double get value => _value;

  bool get isRunning => _isRunning;

  @visibleForTesting
  bool get hasPendingWake => _wakeTimer != null;

  /// 从当前进度继续往复，停止期间的时长不计入。
  void repeat() {
    if (_isRunning) return;
    _isRunning = true;
    _origin = null;
    _ticker.start();
    _setValue(schedule.alphaAt(_elapsed));
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _wakeTimer?.cancel();
    _wakeTimer = null;
    _ticker.stop();
  }

  /// 停止并回到起始进度。
  void reset() {
    stop();
    _elapsed = Duration.zero;
    _setValue(schedule.initialAlpha);
  }

  void _handleTick(Duration _) {
    _ticker.stop();
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final origin = _origin ??= now - _elapsed;
    _elapsed = now - origin;
    _setValue(schedule.alphaAt(_elapsed));
    final next = schedule.nextChangeAfter(_elapsed);
    if (next != null) _wakeTimer = Timer(next - _elapsed, _wake);
  }

  void _wake() {
    _wakeTimer = null;
    if (_isRunning) _ticker.start();
  }

  void _setValue(double value) {
    if (value == _value) return;
    _value = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _wakeTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }
}
