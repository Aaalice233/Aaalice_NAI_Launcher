import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/token_count_format.dart';

void main() {
  test('keeps counts under a thousand exact', () {
    expect(formatTokenCount(0), '0');
    expect(formatTokenCount(999), '999');
  });

  test('switches to k at a thousand', () {
    expect(formatTokenCount(1000), '1.0k');
    expect(formatTokenCount(12345), '12.3k');
  });

  test('drops the decimal once three digits are shown', () {
    expect(formatTokenCount(99900), '99.9k');
    expect(formatTokenCount(128000), '128k');
  });

  test('switches to m at a million', () {
    expect(formatTokenCount(1000000), '1.0m');
    expect(formatTokenCount(2500000), '2.5m');
  });
}
