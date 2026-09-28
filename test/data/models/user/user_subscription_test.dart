import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';

void main() {
  group('UserSubscription balance parsing', () {
    test(
      'supports both current object and legacy numeric balance payloads',
      () {
        final current = UserSubscription.fromJson({
          'trainingStepsLeft': {
            'fixedTrainingStepsLeft': 80,
            'purchasedTrainingSteps': 25,
          },
        });
        final legacy = UserSubscription.fromJson({'trainingStepsLeft': 70});

        expect(current.anlasBalance, 105);
        expect(legacy.anlasBalance, 70);
      },
    );
  });

  group('UserSubscription Opus eligibility', () {
    test('uses the server expiry timestamp when it is available', () {
      final nowInSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      expect(
        UserSubscription(
          tier: 3,
          active: false,
          expiresAt: nowInSeconds + 60,
        ).isOpus,
        isTrue,
      );
      expect(
        UserSubscription(
          tier: 3,
          active: true,
          expiresAt: nowInSeconds - 60,
        ).isOpus,
        isFalse,
      );
    });

    test('keeps privileged accounts active and supports legacy responses', () {
      expect(
        const UserSubscription(tier: 3, accountType: 4, expiresAt: 0).isOpus,
        isTrue,
      );
      expect(const UserSubscription(tier: 3, active: true).isOpus, isTrue);
    });
  });
}
