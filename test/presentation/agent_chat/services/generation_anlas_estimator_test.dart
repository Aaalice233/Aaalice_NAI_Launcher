import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_anlas_estimator.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

class _SubscriptionStub extends SubscriptionNotifier {
  _SubscriptionStub(this._state);

  final SubscriptionState _state;

  @override
  SubscriptionState build() => _state;
}

final _estimatorProvider = Provider<GenerationAnlasEstimator>(
  GenerationAnlasEstimator.new,
);

int _estimateWith(OpusUsageInfo usage) {
  final container = ProviderContainer(
    overrides: [
      subscriptionNotifierProvider.overrideWith(
        () => _SubscriptionStub(
          SubscriptionState.loaded(
            UserSubscription(
              tier: AnlasCalculator.opusTier,
              active: true,
              usage: usage,
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  return container
      .read(_estimatorProvider)
      .estimate(
        const ImageParams(model: ImageModels.animeDiffusionV5Curated),
        requestCount: 1,
        batchSize: 1,
      );
}

void main() {
  group('GenerationAnlasEstimator Opus quota', () {
    test('keeps V5 free while only the extra usage pool remains', () {
      expect(
        _estimateWith(const OpusUsageInfo(percent: 0, purchasedPercent: 200)),
        0,
      );
    });

    test('charges once the server reports the quota as negative', () {
      expect(
        _estimateWith(
          const OpusUsageInfo(
            percent: -1,
            isNegative: true,
            purchasedPercent: 200,
          ),
        ),
        greaterThan(0),
      );
    });
  });
}
