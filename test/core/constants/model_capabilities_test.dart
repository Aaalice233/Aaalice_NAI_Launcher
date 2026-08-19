import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/model_capabilities.dart';

void main() {
  group('ModelCapabilityRegistry.of', () {
    test('maps inpainting variants onto their base family', () {
      expect(
        ModelCapabilityRegistry.of(ImageModels.animeDiffusionV45FullInpainting),
        same(ModelCapabilityRegistry.of(ImageModels.animeDiffusionV45Full)),
      );
      expect(
        ModelCapabilityRegistry.of(ImageModels.furryDiffusionV3Inpainting),
        same(ModelCapabilityRegistry.of(ImageModels.furryDiffusionV3)),
      );
    });

    test('keeps unregistered ids in the closest family instead of V1', () {
      // 带后缀的新 ID 仍然要走 V4 结构，而不是静默降级到 legacy 路径。
      final unknownV45 = ModelCapabilityRegistry.of(
        'nai-diffusion-4-5-curated-next',
      );

      expect(unknownV45.promptStructure, PromptStructure.v4);
      expect(unknownV45.id, ImageModels.animeDiffusionV45Curated);
    });

    test('does not confuse V4.5 ids with the V4 family', () {
      // 判断顺序必须从长到短，nai-diffusion-4-5-full 同时包含 diffusion-4。
      expect(
        ModelCapabilityRegistry.of('nai-diffusion-4-5-full-preview').id,
        ImageModels.animeDiffusionV45Full,
      );
    });

    test('falls back to the legacy family for unrecognised ids', () {
      final caps = ModelCapabilityRegistry.of('totally-unknown-model');

      expect(caps.promptStructure, PromptStructure.legacy);
      expect(caps.anlasFormula, AnlasFormula.legacy);
    });
  });

  group('capability facts', () {
    test('the modern anlas formula covers V3 and newer', () {
      for (final model in [
        ImageModels.animeDiffusionV3,
        ImageModels.furryDiffusionV3,
        ImageModels.animeDiffusionV4Full,
        ImageModels.animeDiffusionV45Full,
      ]) {
        expect(
          ModelCapabilityRegistry.of(model).anlasFormula,
          AnlasFormula.modern,
          reason: '$model should use the modern pricing formula',
        );
      }

      expect(
        ModelCapabilityRegistry.of(ImageModels.animeV2).anlasFormula,
        AnlasFormula.legacy,
      );
    });

    test('isV4Model covers every v4-structure family', () {
      expect(ImageModels.isV4Model(ImageModels.animeDiffusionV4Full), isTrue);
      expect(ImageModels.isV4Model(ImageModels.animeDiffusionV45Full), isTrue);
      expect(ImageModels.isV4Model(ImageModels.animeDiffusionV3), isFalse);
    });

    test('precise reference stays limited to the V4.5 family', () {
      // 面板门控之前用 isV4Model，V4 用户看得见却点不动。
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV45Full,
        ).supportsPreciseReference,
        isTrue,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV4Full,
        ).supportsPreciseReference,
        isFalse,
      );
    });

    test('vibe transfer is limited to the V4 families', () {
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV45Full,
        ).supportsVibeTransfer,
        isTrue,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV3,
        ).supportsVibeTransfer,
        isFalse,
      );
    });

    test('character positioning follows the character limit', () {
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV45Full,
        ).supportsCharacterPositioning,
        isTrue,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV3,
        ).supportsCharacterPositioning,
        isFalse,
      );
    });
  });

  group('resolveModelSwitchFollowUps', () {
    final v4 = ModelCapabilityRegistry.of(ImageModels.animeDiffusionV4Full);
    final v45 = ModelCapabilityRegistry.of(ImageModels.animeDiffusionV45Full);

    test('follows the new defaults when the user has not touched them', () {
      final followUps = resolveModelSwitchFollowUps(
        from: v4,
        to: v45,
        currentScale: v4.defaultScale,
        currentSteps: v4.defaultSteps,
      );

      expect(followUps.scale, v45.defaultScale);
      expect(followUps.steps, isNull, reason: '两者步数默认值相同，不需要改动');
    });

    test('keeps values the user adjusted', () {
      final followUps = resolveModelSwitchFollowUps(
        from: v4,
        to: v45,
        currentScale: 7.5,
        currentSteps: 40,
      );

      expect(followUps.isEmpty, isTrue);
    });

    test('does nothing when the defaults are identical', () {
      final followUps = resolveModelSwitchFollowUps(
        from: v45,
        to: v45,
        currentScale: v45.defaultScale,
        currentSteps: v45.defaultSteps,
      );

      expect(followUps.isEmpty, isTrue);
    });
  });
}
