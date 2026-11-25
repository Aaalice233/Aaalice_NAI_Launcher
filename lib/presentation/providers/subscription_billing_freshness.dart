import 'dart:async';

/// 记录当前账号的订阅核实时间与计费落库窗口。
final class SubscriptionBillingFreshness {
  SubscriptionBillingFreshness(this._onSettled);

  /// 订阅数据成功取回后，这段时间内可以直接拿来判定免费。
  // 两个定时刷新周期；期间配额池在别的设备上被耗尽的残余风险可以接受，本应用自己的计费请求会让数据立即失效
  static const Duration window = Duration(seconds: 60);

  final void Function() _onSettled;
  DateTime? _verifiedAt;
  int _epoch = 0;
  Completer<void>? _settling;
  Timer? _settleTimer;

  /// 计费请求已结束、扣点可能还没落库。
  bool get isSettling => _settling != null;

  Future<void> whenSettled() => _settling?.future ?? Future<void>.value();

  bool isFresh(DateTime now) {
    final verifiedAt = _verifiedAt;
    return verifiedAt != null && now.difference(verifiedAt) <= window;
  }

  /// 发出订阅请求前取号；扣点落库前发出的请求读到的可能是扣点前的数据，不算核实。
  int? requestToken() => isSettling ? null : _epoch;

  /// 只登记在当前计费窗口结束后发出的请求。
  void recordVerified(int? token, DateTime now) {
    if (token == null || token != _epoch) return;
    _verifiedAt = now;
  }

  /// 每次可能扣点的请求结束都使核实时间失效，并重新计时 [settleDelay]。
  void billingRequestEnded(Duration settleDelay) {
    _epoch += 1;
    _verifiedAt = null;
    _settling ??= Completer<void>();
    _settleTimer?.cancel();
    _settleTimer = Timer(settleDelay, _finishWindow);
  }

  void _finishWindow() {
    _settle();
    _onSettled();
  }

  void _settle() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _settling?.complete();
    _settling = null;
  }

  /// 订阅 Notifier 重建或销毁时停表；未落定的窗口保持未落定，等 [resume] 从头计时。
  void suspend() {
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  void resume(Duration settleDelay) {
    if (_settling == null || _settleTimer != null) return;
    _settleTimer = Timer(settleDelay, _finishWindow);
  }

  /// 切换账号或登出时释放等待者，旧账号的刷新随会话丢弃。
  void reset() {
    _epoch += 1;
    _verifiedAt = null;
    _settle();
  }
}
