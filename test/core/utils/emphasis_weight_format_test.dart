import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/emphasis_weight_format.dart';

void main() {
  test('drops trailing zeros and a bare decimal point', () {
    expect(formatEmphasisWeight(0.5), '0.5');
    expect(formatEmphasisWeight(1), '1');
    expect(formatEmphasisWeight(2), '2');
    expect(formatEmphasisWeight(10), '10');
    expect(formatEmphasisWeight(1.1), '1.1');
  });

  test('keeps significant digits after rounding', () {
    expect(formatEmphasisWeight(0.95), '0.95');
    expect(formatEmphasisWeight(1.05), '1.05');
    expect(formatEmphasisWeight(1.1025), '1.1');
    expect(formatEmphasisWeight(0.999), '1');
  });

  test('honours a custom precision', () {
    expect(formatEmphasisWeight(1.21551, fractionDigits: 5), '1.21551');
    expect(formatEmphasisWeight(1.2, fractionDigits: 5), '1.2');
  });

  test('negative weights and zero', () {
    expect(formatEmphasisWeight(-0.5), '-0.5');
    expect(formatEmphasisWeight(-1), '-1');
    expect(formatEmphasisWeight(0), '0');
    expect(formatEmphasisWeight(-0.001), '0');
  });
}
