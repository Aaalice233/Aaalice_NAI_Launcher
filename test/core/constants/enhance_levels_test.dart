import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';

void main() {
  group('EnhanceLevels', () {
    test('should mirror the official 5-tier strength/noise table', () {
      // 网页端常量表：只有最高档带噪声。
      expect(EnhanceLevels.table.map((entry) => entry.strength).toList(), [
        0.2,
        0.4,
        0.5,
        0.6,
        0.7,
      ]);
      expect(EnhanceLevels.table.map((entry) => entry.noise).toList(), [
        0.0,
        0.0,
        0.0,
        0.0,
        0.1,
      ]);
    });

    test('should resolve levels and clamp out-of-range input', () {
      expect(EnhanceLevels.resolve(1), (strength: 0.2, noise: 0.0));
      expect(EnhanceLevels.resolve(5), (strength: 0.7, noise: 0.1));
      expect(EnhanceLevels.resolve(0), EnhanceLevels.resolve(1));
      expect(EnhanceLevels.resolve(9), EnhanceLevels.resolve(5));
      expect(
        EnhanceLevels.resolve(EnhanceLevels.defaultLevel),
        (strength: 0.5, noise: 0.0),
      );
    });

    test('should migrate legacy magnitudes to the nearest level', () {
      // 旧实现把 magnitude 直接当 strength，按 strength 取最近档。
      expect(EnhanceLevels.fromLegacyMagnitude(0.5), 3);
      expect(EnhanceLevels.fromLegacyMagnitude(0.72), 5);
      expect(EnhanceLevels.fromLegacyMagnitude(0.62), 4);
      expect(EnhanceLevels.fromLegacyMagnitude(0.35), 2);
      expect(EnhanceLevels.fromLegacyMagnitude(0.0), 1);
      expect(EnhanceLevels.fromLegacyMagnitude(1.0), 5);
    });
  });

  group('EnhanceLevels.applyPromptAddition', () {
    test('should append the down-weight tag verbatim', () {
      // 网页端原样拼接，首尾都留逗号，这里保持一致以便对比 token。
      expect(
        EnhanceLevels.applyPromptAddition('1girl, sunset'),
        equals('1girl, sunset, -2::upscaled, blurry::,'),
      );
    });

    test('should insert the tag ahead of a text: section', () {
      // 匹配把 text: 前面的分隔符也算进 match，插入点就落在分隔符之前。
      expect(
        EnhanceLevels.applyPromptAddition('1girl, text:hello'),
        equals('1girl,, -2::upscaled, blurry::, text:hello'),
      );
      // 转义冒号（text::）不是渲染标记，按普通文本走末尾追加
      expect(
        EnhanceLevels.applyPromptAddition('1girl, text::hello'),
        equals('1girl, text::hello, -2::upscaled, blurry::,'),
      );
    });

    test('should skip prompts that already carry the tag', () {
      const prompt = '1girl, -2::upscaled, blurry::,';
      expect(EnhanceLevels.applyPromptAddition(prompt), equals(prompt));
    });
  });

  group('EnhanceScales', () {
    test('should keep the fixed tiers for 832x1216', () {
      // 832×1.5=1248 过不了 64 对齐，网页端给这个尺寸开了口子
      expect(
        EnhanceScales.availableFactors(sourceWidth: 832, sourceHeight: 1216),
        [1.5, 1.0],
      );
      expect(
        EnhanceScales.availableFactors(sourceWidth: 1216, sourceHeight: 832),
        [1.5, 1.0],
      );
    });

    test('should offer 2x only while the result fits the area budget', () {
      // 768×1024 放大 2 倍正好等于面积上限
      expect(
        EnhanceScales.availableFactors(sourceWidth: 768, sourceHeight: 1024),
        [2.0, 1.5, 1.0],
      );
      // 1024×1024 放大 2 倍会超上限
      expect(
        EnhanceScales.availableFactors(sourceWidth: 1024, sourceHeight: 1024),
        [1.5, 1.0],
      );
      expect(
        EnhanceScales.availableFactors(sourceWidth: 1536, sourceHeight: 1536),
        [1.0],
      );
    });

    test('should fall back to 1x before the source size is known', () {
      expect(EnhanceScales.availableFactors(), [1.0]);
      expect(EnhanceScales.availableFactors(sourceWidth: 768), [1.0]);
    });

    test('should clamp a persisted factor to what the source allows', () {
      expect(
        EnhanceScales.resolveFactor(2.0, sourceWidth: 768, sourceHeight: 1024),
        2.0,
      );
      // 同一个 2x 偏好换到大图上回落到最大可用档
      expect(
        EnhanceScales.resolveFactor(2.0, sourceWidth: 1024, sourceHeight: 1024),
        1.5,
      );
      expect(
        EnhanceScales.resolveFactor(2.0, sourceWidth: 1536, sourceHeight: 1536),
        1.0,
      );
    });
  });
}
