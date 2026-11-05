import 'package:flutter/foundation.dart';

import '../../data/models/user/user_subscription.dart';

/// 估价用到的订阅事实：是否 Opus，V5 配额池是否已透支。
@immutable
class SubscriptionBillingView {
  const SubscriptionBillingView({
    required this.isOpus,
    required this.opusQuotaExhausted,
  });

  factory SubscriptionBillingView.of(UserSubscription? subscription) =>
      SubscriptionBillingView(
        isOpus: subscription?.isOpus == true,
        opusQuotaExhausted: subscription?.usage?.isNegative ?? false,
      );

  factory SubscriptionBillingView.resolve(
    UserSubscription? subscription, {
    required bool unverified,
  }) => unverified
      ? SubscriptionBillingView.unverified
      : SubscriptionBillingView.of(subscription);

  /// 订阅数据过期又没能刷新时不承认任何 Opus 免费额度。
  static const unverified = SubscriptionBillingView(
    isOpus: false,
    opusQuotaExhausted: true,
  );

  final bool isOpus;
  final bool opusQuotaExhausted;

  @override
  bool operator ==(Object other) =>
      other is SubscriptionBillingView &&
      other.isOpus == isOpus &&
      other.opusQuotaExhausted == opusQuotaExhausted;

  @override
  int get hashCode => Object.hash(isOpus, opusQuotaExhausted);

  @override
  String toString() =>
      'SubscriptionBillingView(isOpus: $isOpus, '
      'opusQuotaExhausted: $opusQuotaExhausted)';
}
