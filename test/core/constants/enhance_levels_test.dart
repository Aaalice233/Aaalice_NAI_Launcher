import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/model_capabilities.dart';

void main() {
  group('EnhanceLevels', () {
    test('should mirror the official 5-tier strength/noise table', () {
      // 官网 bundle 常量表：只有最高档带噪声。
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
      expect(EnhanceLevels.resolve(EnhanceLevels.defaultLevel), (
        strength: 0.5,
        noise: 0.0,
      ));
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
      // 官网原样拼接，首尾都留逗号，这里保持一致以便对比 token。
      expect(
        EnhanceLevels.applyPromptAddition('1girl, sunset'),
        equals('1girl, sunset, -2::upscaled, blurry::,'),
      );
    });

    test('should insert the tag ahead of a text: section', () {
      // 官网的匹配把 text: 前面的分隔符也算进 match，插入点就落在分隔符之前
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

    test('should only update the base prompt of inline character prompts', () {
      expect(
        EnhanceLevels.applyPromptAddition(
          '2girls, indoors | girl, red hair | girl, blue hair',
        ),
        equals(
          '2girls, indoors, -2::upscaled, blurry::,'
          '| girl, red hair | girl, blue hair',
        ),
      );
    });

    test('should preserve text markers and randomizer pipes', () {
      expect(
        EnhanceLevels.applyPromptAddition(
          'scene ||day|night||, text:hello | girl, red hair',
        ),
        equals(
          'scene ||day|night||,, -2::upscaled, blurry::, text:hello'
          ' | girl, red hair',
        ),
      );
      expect(
        EnhanceLevels.applyPromptAddition(
          'scene | girl, upscaled, blurry jacket',
        ),
        equals('scene, -2::upscaled, blurry::,| girl, upscaled, blurry jacket'),
      );
      expect(
        EnhanceLevels.applyPromptAddition(
          'scene ||red, text:hello|blue|| | girl, red hair',
        ),
        equals(
          'scene ||red, text:hello|blue||, -2::upscaled, blurry::,'
          '| girl, red hair',
        ),
      );
    });
  });

  group('EnhanceScales', () {
    test('should keep the fixed tiers for 832x1216', () {
      // 832×1.5=1248 过不了 64 对齐，官网给这个尺寸开了口子
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

  group('E2eUpscale.allowsMaxEnhance', () {
    test('should require a model that supports the max tier', () {
      expect(
        E2eUpscale.allowsMaxEnhance(
          ModelCapabilityRegistry.of(ImageModels.animeDiffusionV45Full),
          sourceWidth: 832,
          sourceHeight: 1216,
        ),
        isFalse,
      );
      expect(
        E2eUpscale.allowsMaxEnhance(
          ModelCapabilityRegistry.of(ImageModels.animeDiffusionV5Curated),
          sourceWidth: 832,
          sourceHeight: 1216,
        ),
        isTrue,
      );
    });

    test('should hide the max tier once the source fills the area budget', () {
      final v5 = ModelCapabilityRegistry.of(
        ImageModels.animeDiffusionV5Curated,
      );

      // 1600×1600 = 2560000 已超过 0.8 × 3.14MP 的阈值
      expect(
        E2eUpscale.allowsMaxEnhance(v5, sourceWidth: 1600, sourceHeight: 1600),
        isFalse,
      );
      expect(
        E2eUpscale.allowsMaxEnhance(v5, sourceWidth: 1536, sourceHeight: 1536),
        isTrue,
      );
    });

    test('should hide the max tier before the source size is known', () {
      final v5 = ModelCapabilityRegistry.of(
        ImageModels.animeDiffusionV5Curated,
      );

      expect(E2eUpscale.allowsMaxEnhance(v5), isFalse);
      expect(
        E2eUpscale.allowsMaxEnhance(v5, sourceWidth: 832, sourceHeight: null),
        isFalse,
      );
    });
  });
}
