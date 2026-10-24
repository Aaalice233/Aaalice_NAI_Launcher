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

  group('OpusUsageInfo extra usage pool', () {
    OpusUsageInfo parseUsage(Map<String, dynamic> usage) =>
        UserSubscription.fromJson({'tier': 3, 'usage': usage}).usage!;

    test('reads purchasedPercent next to the regular allowance', () {
      final usage = parseUsage({
        'percent': 45,
        'isNegative': false,
        'timeUntilNextPercent': 6048,
        'purchasedPercent': 200,
      });

      expect(usage.percent, 45);
      expect(usage.purchasedPercent, 200);
      expect(usage.regularDisplayPercent, 45);
      expect(usage.extraPercent, 200);
      expect(usage.hasExtraUsage, isTrue);
      expect(usage.availablePercent, 245);
    });

    test('keeps fractional extra usage values', () {
      final usage = parseUsage({'percent': 0, 'purchasedPercent': 37.5});

      expect(usage.extraPercent, 37.5);
      expect(usage.availablePercent, 37.5);
    });

    test('treats missing, null and negative extra usage as zero', () {
      final legacy = parseUsage({
        'percent': 50,
        'isNegative': false,
        'timeUntilNextPercent': 4800,
      });
      final nullExtra = parseUsage({'percent': 50, 'purchasedPercent': null});
      final negativeExtra = parseUsage({'percent': 50, 'purchasedPercent': -3});

      for (final usage in [legacy, nullExtra]) {
        expect(usage.purchasedPercent, 0);
        expect(usage.hasExtraUsage, isFalse);
        expect(usage.availablePercent, 50);
      }
      expect(negativeExtra.extraPercent, 0);
      expect(negativeExtra.hasExtraUsage, isFalse);
      expect(negativeExtra.availablePercent, 50);
    });

    test('treats non-numeric and non-finite extra usage as zero', () {
      for (final raw in <Object?>[
        '200',
        true,
        <String, Object?>{'value': 200},
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final subscription = UserSubscription.fromJson({
          'tier': 3,
          'trainingStepsLeft': {
            'fixedTrainingStepsLeft': 80,
            'purchasedTrainingSteps': 25,
          },
          'usage': {'percent': 50, 'purchasedPercent': raw},
        });
        final usage = subscription.usage!;

        expect(subscription.anlasBalance, 105, reason: '$raw');
        expect(usage.percent, 50, reason: '$raw');
        expect(usage.purchasedPercent, 0, reason: '$raw');
        expect(usage.hasExtraUsage, isFalse, reason: '$raw');
        expect(usage.availablePercent, 50, reason: '$raw');
      }
    });

    test('clamps negative extra usage to zero while parsing', () {
      expect(
        parseUsage({'percent': 50, 'purchasedPercent': -3}).purchasedPercent,
        0,
      );
    });

    test('never rounds a non-empty extra usage pool down to zero', () {
      expect(const OpusUsageInfo().extraDisplayPercent, 0);
      for (final (raw, shown) in const [
        (0.01, 1),
        (0.4, 1),
        (0.5, 1),
        (1.4, 1),
        (1.5, 2),
        (199.6, 200),
      ]) {
        final usage = OpusUsageInfo(purchasedPercent: raw);
        expect(usage.hasExtraUsage, isTrue, reason: '$raw');
        expect(usage.extraDisplayPercent, shown, reason: '$raw');
      }
    });

    test('keeps responses without a usage object parseable', () {
      final subscription = UserSubscription.fromJson({
        'tier': 3,
        'active': true,
      });

      expect(subscription.usage, isNull);
    });

    test('mirrors the web display rules for the regular allowance', () {
      expect(const OpusUsageInfo(percent: 192).regularDisplayPercent, 192);
      expect(
        const OpusUsageInfo(
          percent: -4,
          purchasedPercent: 120,
        ).regularDisplayPercent,
        0,
      );
      expect(
        const OpusUsageInfo(
          percent: 30,
          isNegative: true,
          purchasedPercent: 80,
        ).regularDisplayPercent,
        0,
      );
      expect(
        const OpusUsageInfo(
          percent: -4,
          purchasedPercent: 120,
        ).availablePercent,
        120,
      );
    });

    test('round-trips purchasedPercent through toJson', () {
      const usage = OpusUsageInfo(percent: 12, purchasedPercent: 300);

      expect(OpusUsageInfo.fromJson(usage.toJson()), usage);
    });
  });
}
