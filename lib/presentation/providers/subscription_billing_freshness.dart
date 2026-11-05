import 'dart:async';

/// 记录订阅数据能否直接用来判定免费；由 SubscriptionNotifier 独占持有。
final class SubscriptionBillingFreshness {
  /// 订阅数据成功取回后，这段时间内可以直接拿来判定免费。
  // 两个定时刷新周期；期间配额池在别的设备上被耗尽的残余风险可以接受，本应用自己的计费请求会让数据立即失效
  static const Duration window = Duration(seconds: 60);

  DateTime? _verifiedAt;
  int _epoch = 0;
  Completer<void>? _settling;
  Timer? _settleTimer;
  bool _unverified = false;

  /// 过期数据没能刷新时为 true，直到再次成功核实。
  bool get unverified => _unverified;

  /// 计费请求已结束、扣点可能还没落库。
  bool get isSettling => _settling != null;

  Future<void> whenSettled() => _settling?.future ?? Future<void>.value();

  bool isFresh(DateTime now) {
    final verifiedAt = _verifiedAt;
    return verifiedAt != null && now.difference(verifiedAt) <= window;
  }

  /// 发出订阅请求前取号；扣点落库前发出的请求读到的可能是扣点前的数据，不算核实。
  int? requestToken() => isSettling ? null : _epoch;

  /// 用发请求时取的号登记一次成功取回；返回 [unverified] 是否因此改变。
  bool recordVerified(int? token, DateTime now) {
    if (token == null || token != _epoch) return false;
    _verifiedAt = now;
    return _setUnverified(false);
  }

  /// 每次可能扣点的请求结束都调用：之前取回的数据一律不再用于判定免费，
  /// [settleDelay] 内取回的也不算核实；其间再有请求结束就重新计时。
  void billingRequestEnded(Duration settleDelay) {
    _epoch += 1;
    _verifiedAt = null;
    _settling ??= Completer<void>();
    _settleTimer?.cancel();
    _settleTimer = Timer(settleDelay, _settle);
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
    _settleTimer = Timer(settleDelay, _settle);
  }

  bool markUnverified() => _setUnverified(true);

  /// 切换账号或登出；返回 [unverified] 是否因此改变。
  bool reset() {
    _epoch += 1;
    _verifiedAt = null;
    _settle();
    return _setUnverified(false);
  }

  bool _setUnverified(bool value) {
    if (_unverified == value) return false;
    _unverified = value;
    return true;
  }
}
