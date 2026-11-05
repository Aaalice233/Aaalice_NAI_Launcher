import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

enum StaleOpusRefreshOutcome { stillFresh, quotaExhausted, failed }

UserSubscription opusSubscription({required bool quotaExhausted}) =>
    UserSubscription(
      tier: 3,
      active: true,
      usage: OpusUsageInfo(
        percent: quotaExhausted ? 0 : 40,
        isNegative: quotaExhausted,
      ),
    );

// 本地数据仍显示配额充足；放行前的刷新结果由 [outcome] 决定
class StaleOpusSubscription extends SubscriptionNotifier {
  StaleOpusSubscription(this.outcome);

  final StaleOpusRefreshOutcome outcome;
  int billingChecks = 0;

  @override
  SubscriptionState build() =>
      SubscriptionState.loaded(opusSubscription(quotaExhausted: false));

  @override
  Future<bool> ensureFreshForBilling() async {
    billingChecks++;
    switch (outcome) {
      case StaleOpusRefreshOutcome.stillFresh:
        return true;
      case StaleOpusRefreshOutcome.quotaExhausted:
        state = SubscriptionState.loaded(
          opusSubscription(quotaExhausted: true),
        );
        return true;
      case StaleOpusRefreshOutcome.failed:
        return false;
    }
  }
}
