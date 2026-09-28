import '../constants/api_constants.dart';
import '../constants/model_capabilities.dart';
import 'novelai_auto_text.dart';
import 'prompt_edit_document.dart';

/// 提示词语义快照
///
/// - basePrompt/baseNegativePrompt: 结构化元数据中保留的基础文本
/// - effectivePrompt/effectiveNegativePrompt: 当前实际送给模型时的等效文本
class PromptSemanticsSnapshot {
  const PromptSemanticsSnapshot({
    required this.basePrompt,
    required this.baseNegativePrompt,
    required this.effectivePrompt,
    required this.effectiveNegativePrompt,
    this.autoTextBlock,
  });

  final String basePrompt;
  final String baseNegativePrompt;
  final String effectivePrompt;
  final String effectiveNegativePrompt;
  final String? autoTextBlock;
}

PromptSemanticsSnapshot buildPromptSemanticsSnapshot({
  required String prompt,
  required String negativePrompt,
  required String model,
  required bool qualityToggle,
  required int ucPreset,
  bool isEnhanceRequest = false,
  bool transparentBackground = false,
  String qualityTier = QualityTags.standardTier,
  List<NovelAiAutoTextCharacter> characters = const [],
  bool useCoords = false,
}) {
  final basePrompt = prompt;
  final baseNegativePrompt = negativePrompt;
  prompt = PromptEditDocument.effectiveText(prompt);
  negativePrompt = PromptEditDocument.effectiveText(negativePrompt);
  characters = characters
      .map(
        (character) => NovelAiAutoTextCharacter(
          prompt: PromptEditDocument.effectiveText(character.prompt),
          centerX: character.centerX,
          centerY: character.centerY,
          enabled: character.enabled,
        ),
      )
      .toList(growable: false);
  final capabilities = ModelCapabilityRegistry.of(model);
  // 自定义质量预设在到这一步之前就已经并进 prompt（qualityToggle=false），
  // 因此 `transparent background` 会落在自定义质量词之后；官网没有自定义
  // 预设这一路，NAI 默认质量词的顺序与官网一致。
  var effectivePrompt = QualityTags.applySuffix(
    prompt,
    QualityTags.composeSuffix(
      model,
      qualityToggle: qualityToggle,
      transparentBackground:
          transparentBackground && capabilities.supportsTransparentBackground,
      qualityTier: qualityTier,
    ),
    capabilities,
  );
  if (isEnhanceRequest && capabilities.supportsEnhancePromptAdd) {
    effectivePrompt = EnhanceLevels.applyPromptAddition(effectivePrompt);
  }

  String? autoTextBlock;
  if (capabilities.supportsAutoText) {
    autoTextBlock = NovelAiAutoText.buildBlock(
      effectivePrompt,
      characters: characters,
      useCoords: useCoords,
    );
    effectivePrompt = NovelAiAutoText.apply(
      effectivePrompt,
      characters: characters,
      useCoords: useCoords,
    );
  }

  final effectiveNegativePrompt = UcPresets.applyPresetWithNsfwCheck(
    negativePrompt,
    prompt,
    model,
    ucPreset,
  );

  return PromptSemanticsSnapshot(
    basePrompt: basePrompt,
    baseNegativePrompt: baseNegativePrompt,
    effectivePrompt: effectivePrompt,
    effectiveNegativePrompt: effectiveNegativePrompt,
    autoTextBlock: autoTextBlock,
  );
}
