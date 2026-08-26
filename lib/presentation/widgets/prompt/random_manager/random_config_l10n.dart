import 'package:nai_launcher/data/models/prompt/character_count_config.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

extension RandomConfigDisplayL10n on AppLocalizations {
  String randomCategoryName(RandomCategory category) {
    if (!category.isBuiltin) return category.name;

    return switch (category.key) {
      'hairColor' => globalSettings_category_hairColor,
      'eyeColor' => globalSettings_category_eyeColor,
      'hairStyle' => globalSettings_category_hairStyle,
      'expression' => globalSettings_category_expression,
      'pose' => globalSettings_category_pose,
      'clothing' => globalSettings_category_clothing,
      'accessory' => globalSettings_category_accessory,
      'bodyFeature' => globalSettings_category_bodyFeature,
      'background' => globalSettings_category_background,
      'scene' => globalSettings_category_scene,
      'style' => globalSettings_category_style,
      'composition' => randomManager_category_composition,
      'prop' => randomManager_category_prop,
      'effect' => randomManager_category_effect,
      'year' => randomManager_category_year,
      'detail' => randomManager_category_detail,
      _ => category.name,
    };
  }

  String randomTagGroupName(RandomTagGroup group) {
    if (group.sourceType != TagGroupSourceType.builtin) return group.name;

    return switch (group.sourceId) {
      'hairColor' => globalSettings_category_hairColor,
      'eyeColor' => globalSettings_category_eyeColor,
      'hairStyle' => globalSettings_category_hairStyle,
      'hairLength' => randomManager_category_hairLength,
      'hairTexture' => randomManager_category_hairTexture,
      'bangs' => randomManager_category_bangs,
      'eyeFeature' => randomManager_category_eyeFeature,
      'expression' => globalSettings_category_expression,
      'pose' => globalSettings_category_pose,
      'clothing' => globalSettings_category_clothing,
      'clothingFemale' => randomManager_femaleClothing,
      'clothingMale' => randomManager_maleClothing,
      'clothingGeneral' => randomManager_generalClothing,
      'accessory' => globalSettings_category_accessory,
      'bodyFeature' => globalSettings_category_bodyFeature,
      'bodyFeatureFemale' => randomManager_femaleBodyType,
      'bodyFeatureMale' => randomManager_maleBodyType,
      'bodyFeatureGeneral' => randomManager_generalBodyType,
      'skinTone' => randomManager_category_skinTone,
      'species' => randomManager_category_species,
      'headwear' => randomManager_category_headwear,
      'hairAccessory' => randomManager_category_hairAccessory,
      'background' => globalSettings_category_background,
      'scene' => globalSettings_category_scene,
      'style' => globalSettings_category_style,
      'camera' => randomManager_category_camera,
      'framing' => randomManager_category_framing,
      'focus' => randomManager_category_focus,
      'prop' => randomManager_category_prop,
      'effect' => randomManager_category_effect,
      'year' => randomManager_category_year,
      'detail' => randomManager_category_detail,
      _ => group.name,
    };
  }

  String characterCountLabel(CharacterCountCategory category) {
    return switch (category.id) {
      'solo' => characterCountConfig_solo,
      'duo' => characterCountConfig_duo,
      'trio' => characterCountConfig_trio,
      'no_humans' => characterCountConfig_noHumans,
      'multi_person' => characterCountConfig_multiPerson,
      _ => category.label,
    };
  }

  String characterTagOptionLabel(CharacterTagOption option) {
    return switch (option.id) {
      'solo_girl' => randomManager_soloFemale,
      'solo_boy' => randomManager_soloMale,
      'duo_2girls' => randomManager_duoGirls,
      'duo_mixed' => randomManager_duoMixed,
      'duo_2boys' => randomManager_duoBoys,
      'trio_3girls' => randomManager_trioGirls,
      'trio_2g1b' => randomManager_trioTwoGirlsOneBoy,
      'trio_1g2b' => randomManager_trioOneGirlTwoBoys,
      'trio_3boys' => randomManager_trioBoys,
      'no_humans_scene' => randomManager_noHumanScene,
      _ => option.label,
    };
  }

  String presetDisplayName(RandomPreset preset) {
    if (!preset.isDefault) return preset.name;

    return switch (preset.algorithmConfig.wordlistType) {
      'legacy' => randomManager_defaultPresetLegacy,
      'furry' => randomManager_defaultPresetFurry,
      _ => randomManager_defaultPresetV4,
    };
  }

  String? presetDisplayDescription(RandomPreset preset) {
    if (!preset.isDefault) {
      return _localizedKnownPresetDescription(preset.description);
    }

    return switch (preset.algorithmConfig.wordlistType) {
      'legacy' => randomManager_defaultPresetLegacyDescription,
      'furry' => randomManager_defaultPresetFurryDescription,
      _ => randomManager_defaultPresetV4Description,
    };
  }

  String? _localizedKnownPresetDescription(String? description) {
    return switch (description) {
      '基于 NAI 官网的随机算法配置' => randomManager_defaultPresetOfficialDescription,
      '基于 NAI V4 模型的随机算法配置，支持多角色' => randomManager_defaultPresetV4Description,
      '基于 NAI Legacy 模型的随机算法配置' => randomManager_defaultPresetLegacyDescription,
      '基于 NAI Furry 模型的随机算法配置' => randomManager_defaultPresetFurryDescription,
      _ => description,
    };
  }
}
