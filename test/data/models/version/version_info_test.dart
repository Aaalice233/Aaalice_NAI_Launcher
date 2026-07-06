import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';

void main() {
  group('VersionInfoComparator', () {
    test('compares stable versions', () {
      expect(VersionInfoComparator.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(VersionInfoComparator.isNewer('1.0.0', '1.0.1'), isFalse);
    });

    test('compares prerelease versions', () {
      expect(
        VersionInfoComparator.isNewer('1.0.0-beta14', '1.0.0-beta13'),
        isTrue,
      );
      expect(VersionInfoComparator.isNewer('1.0.0-beta13', '1.0.0'), isFalse);
    });

    test('uses numeric build metadata as a tie-breaker', () {
      expect(
        VersionInfoComparator.isNewer('1.0.0-beta13+17', '1.0.0-beta13+16'),
        isTrue,
      );
      expect(
        VersionInfoComparator.isNewer('1.0.0-beta13+16', '1.0.0-beta13+17'),
        isFalse,
      );
    });

    test('detects prerelease versions', () {
      expect(VersionInfoComparator.isPrerelease('v1.0.0-beta13+16'), isTrue);
      expect(VersionInfoComparator.isPrerelease('v1.0.0'), isFalse);
    });
  });
}
