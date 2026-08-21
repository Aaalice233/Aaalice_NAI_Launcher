import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/model_capabilities.dart';

void main() {
  group('ModelCapabilityRegistry.of', () {
    test('resolves the V5 staging key to the curated family', () {
      final caps = ModelCapabilityRegistry.of(ImageModels.v5StagingKey);

      expect(caps.id, ImageModels.animeDiffusionV5Curated);
      expect(caps.tokenLimit, 703);
    });

    test('resolves the official V5 ids', () {
      // 正式版把 Full 的上限从测试期的 1406 提到 1471。
      expect(
        ModelCapabilityRegistry.of(ImageModels.animeDiffusionV5Full).tokenLimit,
        1471,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV5Curated,
        ).tokenLimit,
        703,
      );
    });

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
      // 正式 ID 一旦带上后缀，仍然要走 V4 结构而不是静默降级到 legacy 路径。
      final unknownV5 = ModelCapabilityRegistry.of('nai-diffusion-5-full-next');
      expect(unknownV5.promptStructure, PromptStructure.v4);
      expect(unknownV5.tokenLimit, 1471);

      expect(
        ModelCapabilityRegistry.of('nai-diffusion-4-5-curated-next').tokenLimit,
        512,
      );
    });

    test('does not confuse V4.5 ids with the V4 family', () {
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
    test('V5 uses the V4 prompt structure with params_version 4', () {
      final caps = ModelCapabilityRegistry.of(ImageModels.v5StagingKey);

      expect(caps.promptStructure, PromptStructure.v4);
      expect(caps.paramsVersion, 4);
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV45Full,
        ).paramsVersion,
        3,
      );
    });

    test('V5 inpainting maps to the official weights', () {
      // 正式版：Full 有独立 inpainting；Curated 的重绘权重尚未就绪，
      // 网页端映射到 V4.5 Curated Inpainting；测试站键继续走自身。
      expect(
        ImageModels.resolveInpaintingModel(ImageModels.animeDiffusionV5Full),
        ImageModels.animeDiffusionV5FullInpainting,
      );
      expect(
        ImageModels.resolveInpaintingModel(ImageModels.animeDiffusionV5Curated),
        ImageModels.animeDiffusionV45CuratedInpainting,
      );
      expect(
        ImageModels.resolveInpaintingModel(ImageModels.v5StagingKey),
        ImageModels.v5StagingKey,
      );
      expect(
        ImageModels.resolveBaseModel(
          ImageModels.animeDiffusionV5FullInpainting,
        ),
        ImageModels.animeDiffusionV5Full,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV5FullInpainting,
        ),
        same(ModelCapabilityRegistry.of(ImageModels.animeDiffusionV5Full)),
      );
    });

    test('V5 keeps vibe transfer and precise reference hidden', () {
      final caps = ModelCapabilityRegistry.of(ImageModels.v5StagingKey);

      expect(caps.supportsVibeTransfer, isFalse);
      expect(caps.supportsPreciseReference, isFalse);
      expect(ImageModels.isV45Model(ImageModels.v5StagingKey), isFalse);
    });

    test('V5 exposes the production feature set', () {
      final caps = ModelCapabilityRegistry.of(ImageModels.v5StagingKey);

      expect(caps.supportsTransparentBackground, isTrue);
      // 端到端 ×2 放大正式版未上线；增强 max 档保留。
      expect(caps.supportsE2eUpscale, isFalse);
      expect(caps.supportsMaxEnhance, isTrue);
      expect(caps.maxCharacters, 32);
      // 正式版专属：噪声调度不可选、Variety+ 不支持、计价 1.5 倍、
      // Opus 免费受配额池限制。
      expect(caps.supportsNoiseSchedule, isFalse);
      expect(caps.supportsVarietyPlus, isFalse);
      expect(caps.anlasMultiplier, 1.5);
      expect(caps.hasOpusUsageLimit, isTrue);
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV45Full,
        ).supportsVarietyPlus,
        isTrue,
      );
    });

    test('the modern anlas formula covers V3 and newer', () {
      for (final model in [
        ImageModels.animeDiffusionV3,
        ImageModels.furryDiffusionV3,
        ImageModels.animeDiffusionV4Full,
        ImageModels.animeDiffusionV45Full,
        ImageModels.v5StagingKey,
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
      expect(ImageModels.isV4Model(ImageModels.v5StagingKey), isTrue);
      expect(ImageModels.isV4Model(ImageModels.animeDiffusionV3), isFalse);
    });

    test('precise reference stays limited to the V4.5 family', () {
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

    test('separates traditional V3 Vibe from V4 encoded Vibes', () {
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
        isTrue,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.furryDiffusionV3,
        ).supportsVibeTransfer,
        isTrue,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV3,
        ).supportsEncodedVibeTransfer,
        isFalse,
      );
      expect(
        ModelCapabilityRegistry.of(
          ImageModels.animeDiffusionV45Full,
        ).supportsEncodedVibeTransfer,
        isTrue,
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

  group('visibleModels', () {
    test('hides the V5 staging entry unless the switch is on', () {
      expect(
        ImageModels.visibleModels(showV5TestModels: false),
        isNot(contains(ImageModels.v5StagingKey)),
      );
      expect(
        ImageModels.visibleModels(showV5TestModels: true).first,
        ImageModels.v5StagingKey,
      );
    });

    test('always keeps the current selection in the list', () {
      final models = ImageModels.visibleModels(
        showV5TestModels: false,
        current: ImageModels.v5StagingKey,
      );

      expect(models.first, ImageModels.v5StagingKey);
      expect(
        models.where((model) => model == ImageModels.v5StagingKey).length,
        1,
      );
    });

    test('does not duplicate a selection that is already visible', () {
      final models = ImageModels.visibleModels(
        showV5TestModels: true,
        current: ImageModels.animeDiffusionV45Full,
      );

      expect(
        models
            .where((model) => model == ImageModels.animeDiffusionV45Full)
            .length,
        1,
      );
    });
  });

  group('resolveModelSwitchFollowUps', () {
    final v4 = ModelCapabilityRegistry.of(ImageModels.animeDiffusionV4Full);
    final v45 = ModelCapabilityRegistry.of(ImageModels.animeDiffusionV45Full);
    final v5 = ModelCapabilityRegistry.of(ImageModels.v5StagingKey);

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

    test('follows V5 defaults when the V4.5 values are untouched', () {
      final followUps = resolveModelSwitchFollowUps(
        from: v45,
        to: v5,
        currentScale: v45.defaultScale,
        currentSteps: v45.defaultSteps,
      );

      expect(followUps.scale, v5.defaultScale);
      expect(followUps.steps, isNull, reason: '两者步数默认值相同，不需要改动');
    });

    test('keeps adjusted values when switching from V4.5 to V5', () {
      final followUps = resolveModelSwitchFollowUps(
        from: v45,
        to: v5,
        currentScale: 7.5,
        currentSteps: 40,
      );

      expect(followUps.isEmpty, isTrue);
    });

    test('is empty when both models share the same defaults', () {
      final followUps = resolveModelSwitchFollowUps(
        from: v45,
        to: ModelCapabilityRegistry.of(ImageModels.animeDiffusionV45Curated),
        currentScale: v45.defaultScale,
        currentSteps: v45.defaultSteps,
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

    test('tolerates float noise on the current scale', () {
      final followUps = resolveModelSwitchFollowUps(
        from: v45,
        to: v5,
        currentScale: v45.defaultScale + 0.0000001,
        currentSteps: v45.defaultSteps,
      );

      expect(followUps.scale, v5.defaultScale);
    });
  });
}
