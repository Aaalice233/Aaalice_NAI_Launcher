import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/model_capabilities.dart';
import 'package:nai_launcher/core/utils/enhance_request_plan.dart';

void main() {
  final v5 = ModelCapabilityRegistry.of(ImageModels.animeDiffusionV5Curated);
  final v45 = ModelCapabilityRegistry.of(ImageModels.animeDiffusionV45Full);

  EnhanceRequestPlan plan({
    ModelCapabilities? capabilities,
    int width = 832,
    int height = 1216,
    int level = 3,
    double factor = 1.0,
    bool maxScale = false,
    ({double strength, double noise})? individual,
  }) => EnhanceRequestPlan.resolve(
    capabilities: capabilities ?? v5,
    sourceWidth: width,
    sourceHeight: height,
    level: level,
    factor: factor,
    maxScale: maxScale,
    individual: individual,
  );

  test('each level maps to the web strength and noise table', () {
    for (var level = 1; level <= 5; level++) {
      final resolved = plan(level: level);
      expect(
        (strength: resolved.strength, noise: resolved.noise),
        EnhanceLevels.resolve(level),
        reason: 'level $level',
      );
    }
  });

  test('a factor scales the source onto the 64 grid', () {
    final resolved = plan(factor: 1.5);

    expect((resolved.width, resolved.height), (1280, 1856));
    expect(resolved.factor, 1.5);
    expect(resolved.maxScale, isFalse);
  });

  test(
    'a factor that exceeds the area limit falls back to the largest fit',
    () {
      final resolved = plan(width: 1024, height: 1536, factor: 2.0);

      expect(resolved.factor, 1.0);
      expect((resolved.width, resolved.height), (1024, 1536));
    },
  );

  test('max keeps the source size on models that support it', () {
    final resolved = plan(factor: 2.0, maxScale: true);

    expect(resolved.maxScale, isTrue);
    expect(resolved.factor, 1.0);
    expect((resolved.width, resolved.height), (832, 1216));
  });

  test('max falls back to the factor where it is unavailable', () {
    final unsupported = plan(capabilities: v45, factor: 1.5, maxScale: true);
    final tooLarge = plan(
      width: 1472,
      height: 1856,
      factor: 1.0,
      maxScale: true,
    );

    expect(unsupported.maxScale, isFalse);
    expect(unsupported.factor, 1.5);
    expect(tooLarge.maxScale, isFalse);
  });

  test('individual strength and noise replace the level preset', () {
    final resolved = plan(level: 5, individual: (strength: 0.33, noise: 0.02));

    expect(resolved.strength, 0.33);
    expect(resolved.noise, 0.02);
  });
}
