import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_count_config.freezed.dart';
part 'character_count_config.g.dart';

/// 默认槽位选项
const List<String> defaultSlotOptions = [
  'girl',
  'boy',
  'other',
];

/// 角色槽位配置（多人场景中每个角色的标签）
@freezed
class CharacterSlotTag with _$CharacterSlotTag {
  const factory CharacterSlotTag({
    /// 槽位索引 (0-based)
    required int slotIndex,

    /// 角色标签（如 "girl", "boy"）
    required String characterTag,
  }) = _CharacterSlotTag;

  factory CharacterSlotTag.fromJson(Map<String, dynamic> json) =>
      _$CharacterSlotTagFromJson(json);
}

/// 角色标签项（人数类别下的一个选项，如 girl、boy、2girls等）
@freezed
class CharacterTagOption with _$CharacterTagOption {
  const CharacterTagOption._();

  const factory CharacterTagOption({
    /// 唯一ID
    required String id,

    /// 显示名称（如"女性"、"一女一男"）
    required String label,

    /// 主提示词标签（如 "solo", "2girls", "1girl, 1boy"）
    required String mainPromptTags,

    /// 每个角色槽位的标签配置
    /// 例如 girl+boy 组合: [{slotIndex: 0, characterTag: "girl"}, {slotIndex: 1, characterTag: "boy"}]
    @Default([]) List<CharacterSlotTag> slotTags,

    /// 权重
    @Default(50) int weight,

    /// 是否启用
    @Default(true) bool enabled,

    /// 是否为自定义（用户添加）
    @Default(false) bool isCustom,
  }) = _CharacterTagOption;

  factory CharacterTagOption.fromJson(Map<String, dynamic> json) =>
      _$CharacterTagOptionFromJson(json);

  /// 获取角色数量（根据槽位数量）
  int get characterCount => slotTags.length;
}

/// 人数类别配置（如单人、双人、三人、多人、无人）
@freezed
class CharacterCountCategory with _$CharacterCountCategory {
  const CharacterCountCategory._();

  const factory CharacterCountCategory({
    /// 唯一ID
    required String id,

    /// 人数 (0=无人, 1=单人, 2=双人, 3=三人, -1=多人容器)
    required int count,

    /// 显示名称（如"单人"、"双人"、"多人"）
    required String label,

    /// 该类别的权重
    @Default(50) int weight,

    /// 是否启用
    @Default(true) bool enabled,

    /// 角色标签选项列表
    @Default([]) List<CharacterTagOption> tagOptions,

    /// 是否为预设类别（单人、双人、三人、无人）
    @Default(true) bool isPreset,

    /// 是否为"多人"容器类别（用于容纳自定义人数）
    @Default(false) bool isMultiPersonContainer,
  }) = _CharacterCountCategory;

  factory CharacterCountCategory.fromJson(Map<String, dynamic> json) =>
      _$CharacterCountCategoryFromJson(json);

  /// 获取已启用的标签选项
  List<CharacterTagOption> get enabledTagOptions =>
      tagOptions.where((t) => t.enabled).toList();

  /// 计算启用选项的总权重
  int get totalEnabledWeight =>
      enabledTagOptions.fold(0, (sum, t) => sum + t.weight);
}

/// 完整人数类别配置
@freezed
class CharacterCountConfig with _$CharacterCountConfig {
  const CharacterCountConfig._();

  const factory CharacterCountConfig({
    /// 人数类别列表
    @Default([]) List<CharacterCountCategory> categories,

    /// 自定义角色槽位标签列表（如 "girl", "boy", "other", "trap" 等）
    @Default(defaultSlotOptions) List<String> customSlotOptions,
  }) = _CharacterCountConfig;

  factory CharacterCountConfig.fromJson(Map<String, dynamic> json) =>
      _$CharacterCountConfigFromJson(json);

  /// 获取已启用的类别
  List<CharacterCountCategory> get enabledCategories =>
      categories.where((c) => c.enabled && c.weight > 0).toList();

  /// 计算启用类别的总权重
  int get totalEnabledWeight =>
      enabledCategories.fold(0, (sum, c) => sum + c.weight);

  /// 根据ID查找类别
  CharacterCountCategory? findCategoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// NAI 默认配置
  static CharacterCountConfig get naiDefault => const CharacterCountConfig(
        categories: [
          // 单人 (70%)
          CharacterCountCategory(
            id: 'solo',
            count: 1,
            label: '单人',
            weight: 70,
            tagOptions: [
              CharacterTagOption(
                id: 'solo_girl',
                label: '女性',
                mainPromptTags: 'solo',
                slotTags: [
                  CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                ],
                weight: 50,
              ),
              CharacterTagOption(
                id: 'solo_boy',
                label: '男性',
                mainPromptTags: 'solo',
                slotTags: [CharacterSlotTag(slotIndex: 0, characterTag: 'boy')],
                weight: 50,
              ),
            ],
          ),
          // 双人 (20%)
          CharacterCountCategory(
            id: 'duo',
            count: 2,
            label: '双人',
            weight: 20,
            tagOptions: [
              CharacterTagOption(
                id: 'duo_2girls',
                label: '双女',
                mainPromptTags: '2girls',
                slotTags: [
                  CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                  CharacterSlotTag(slotIndex: 1, characterTag: 'girl'),
                ],
                weight: 40,
              ),
              CharacterTagOption(
                id: 'duo_mixed',
                label: '一女一男',
                mainPromptTags: '1girl, 1boy',
                slotTags: [
                  CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                  CharacterSlotTag(slotIndex: 1, characterTag: 'boy'),
                ],
                weight: 50,
              ),
              CharacterTagOption(
                id: 'duo_2boys',
                label: '双男',
                mainPromptTags: '2boys',
                slotTags: [
                  CharacterSlotTag(slotIndex: 0, characterTag: 'boy'),
                  CharacterSlotTag(slotIndex: 1, characterTag: 'boy'),
                ],
                weight: 10,
                enabled: false,
              ),
            ],
          ),
          // 三人 (7%)
          CharacterCountCategory(
            id: 'trio',
            count: 3,
            label: '三人',
            weight: 7,
            tagOptions: [
              CharacterTagOption(
                id: 'trio_3girls',
                label: '三女',
                mainPromptTags: '3girls',
                slotTags: [
                  CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                  CharacterSlotTag(slotIndex: 1, characterTag: 'girl'),
                  CharacterSlotTag(slotIndex: 2, characterTag: 'girl'),
                ],
                weight: 30,
              ),
              CharacterTagOption(
                id: 'trio_2g1b',
                label: '二女一男',
                mainPromptTags: '2girls, 1boy',
                slotTags: [
                  CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                  CharacterSlotTag(slotIndex: 1, characterTag: 'girl'),
                  CharacterSlotTag(slotIndex: 2, characterTag: 'boy'),
                ],
                weight: 40,
              ),
              CharacterTagOption(
                id: 'trio_1g2b',
                label: '一女二男',
                mainPromptTags: '1girl, 2boys',
                slotTags: [
                  CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                  CharacterSlotTag(slotIndex: 1, characterTag: 'boy'),
                  CharacterSlotTag(slotIndex: 2, characterTag: 'boy'),
                ],
                weight: 20,
              ),
              CharacterTagOption(
                id: 'trio_3boys',
                label: '三男',
                mainPromptTags: '3boys',
                slotTags: [
                  CharacterSlotTag(slotIndex: 0, characterTag: 'boy'),
                  CharacterSlotTag(slotIndex: 1, characterTag: 'boy'),
                  CharacterSlotTag(slotIndex: 2, characterTag: 'boy'),
                ],
                weight: 10,
                enabled: false,
              ),
            ],
          ),
          // 无人 (3%)
          CharacterCountCategory(
            id: 'no_humans',
            count: 0,
            label: '无人',
            weight: 3,
            tagOptions: [
              CharacterTagOption(
                id: 'no_humans_scene',
                label: '无人场景',
                mainPromptTags: 'no humans',
                slotTags: [],
                weight: 100,
              ),
            ],
          ),
          // 多人（容器类别，默认权重0，用户可添加自定义多人组合）
          CharacterCountCategory(
            id: 'multi_person',
            count: -1,
            label: '多人',
            weight: 0,
            tagOptions: [],
            isPreset: true,
            isMultiPersonContainer: true,
          ),
        ],
      );
}
