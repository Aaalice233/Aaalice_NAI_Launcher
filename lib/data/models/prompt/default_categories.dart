import '../../services/wordlist_service.dart';
import 'random_category.dart';
import 'random_tag_group.dart';
import 'tag_category.dart';
import 'tag_scope.dart';

/// Default random-prompt stages backed by the complete offline catalog.
class DefaultCategories {
  static List<RandomCategory> createDefault() => [
    _category(
      id: 'default_hairColor',
      name: '发色',
      key: 'hairColor',
      emoji: '🎨',
      probability: 1,
      scope: TagScope.character,
      groups: [_group(TagSubCategory.hairColor, '发色', '🎨')],
    ),
    _category(
      id: 'default_eyeColor',
      name: '眼睛',
      key: 'eyeColor',
      emoji: '👁️',
      probability: 0.9,
      scope: TagScope.character,
      groups: [
        _group(TagSubCategory.eyeColor, '瞳色', '👁️'),
        _group(TagSubCategory.eyeFeature, '眼睛特征', '✨', probability: 0.25),
      ],
    ),
    _category(
      id: 'default_hairStyle',
      name: '发型',
      key: 'hairStyle',
      emoji: '✂️',
      probability: 0.9,
      scope: TagScope.character,
      groups: [
        _group(TagSubCategory.hairLength, '发长', '📏', probability: 0.8),
        _group(TagSubCategory.hairStyle, '发型', '✂️', probability: 0.8),
        _group(TagSubCategory.hairTexture, '发质', '〰️', probability: 0.3),
        _group(TagSubCategory.bangs, '刘海', '💇', probability: 0.45),
      ],
    ),
    _category(
      id: 'default_expression',
      name: '表情',
      key: 'expression',
      emoji: '😊',
      probability: 0.65,
      scope: TagScope.character,
      groups: [_group(TagSubCategory.expression, '表情', '😊')],
    ),
    _category(
      id: 'default_pose',
      name: '姿势',
      key: 'pose',
      emoji: '🧘',
      probability: 0.65,
      scope: TagScope.character,
      groups: [_group(TagSubCategory.pose, '姿势', '🧘')],
    ),
    _category(
      id: 'default_clothing',
      name: '服装',
      key: 'clothing',
      emoji: '👗',
      probability: 1,
      scope: TagScope.character,
      groups: [
        _group(
          TagSubCategory.clothingFemale,
          '女性服装',
          '👗',
          probability: 0.65,
          genders: const ['girl'],
        ),
        _group(
          TagSubCategory.clothingMale,
          '男性服装',
          '👔',
          probability: 0.65,
          genders: const ['boy'],
        ),
        _group(TagSubCategory.clothingGeneral, '通用服装', '🎽', probability: 0.75),
      ],
    ),
    _category(
      id: 'default_bodyFeature',
      name: '身体特征',
      key: 'bodyFeature',
      emoji: '🧍',
      probability: 0.45,
      scope: TagScope.character,
      groups: [
        _group(TagSubCategory.skinTone, '肤色', '🎨', probability: 0.4),
        _group(
          TagSubCategory.bodyFeatureFemale,
          '女性体型',
          '👙',
          probability: 0.6,
          genders: const ['girl'],
        ),
        _group(
          TagSubCategory.bodyFeatureMale,
          '男性体型',
          '💪',
          probability: 0.6,
          genders: const ['boy'],
        ),
        _group(
          TagSubCategory.bodyFeatureGeneral,
          '通用体型',
          '🧍',
          probability: 0.45,
        ),
        _group(TagSubCategory.species, '物种', '🐾', probability: 0.08),
      ],
    ),
    _category(
      id: 'default_accessory',
      name: '配饰',
      key: 'accessory',
      emoji: '💍',
      probability: 0.55,
      scope: TagScope.character,
      groups: [
        _group(TagSubCategory.headwear, '帽子', '🎩', probability: 0.25),
        _group(TagSubCategory.hairAccessory, '发饰', '🎀', probability: 0.25),
        _group(TagSubCategory.accessory, '配饰', '💍', probability: 0.45),
      ],
    ),
    _category(
      id: 'default_style',
      name: '风格',
      key: 'style',
      emoji: '🎭',
      probability: 0.5,
      scope: TagScope.global,
      groups: [_group(TagSubCategory.style, '风格', '🎭')],
    ),
    _category(
      id: 'default_background',
      name: '背景',
      key: 'background',
      emoji: '🌄',
      probability: 0.8,
      scope: TagScope.global,
      groups: [_group(TagSubCategory.background, '背景', '🌄')],
    ),
    _category(
      id: 'default_scene',
      name: '场景',
      key: 'scene',
      emoji: '🏞️',
      probability: 0.5,
      scope: TagScope.global,
      groups: [_group(TagSubCategory.scene, '场景', '🏞️')],
    ),
    _category(
      id: 'default_composition',
      name: '构图',
      key: 'composition',
      emoji: '📷',
      probability: 1,
      scope: TagScope.global,
      groups: [
        _group(TagSubCategory.camera, '视角', '📐', probability: 0.3),
        _group(TagSubCategory.framing, '景别', '🖼️', probability: 0.7),
        _group(TagSubCategory.focus, '焦点', '🎯', probability: 0.1),
      ],
    ),
    _category(
      id: 'default_prop',
      name: '道具',
      key: 'prop',
      emoji: '🧰',
      probability: 0.2,
      scope: TagScope.global,
      groups: [_group(TagSubCategory.prop, '道具', '🧰')],
    ),
    _category(
      id: 'default_effect',
      name: '特效',
      key: 'effect',
      emoji: '✨',
      probability: 0.25,
      scope: TagScope.global,
      groups: [_group(TagSubCategory.effect, '特效', '✨')],
    ),
    _category(
      id: 'default_year',
      name: '年代',
      key: 'year',
      emoji: '📅',
      probability: 0.2,
      scope: TagScope.global,
      groups: [_group(TagSubCategory.year, '年代', '📅')],
    ),
    _category(
      id: 'default_detail',
      name: '创意细节',
      key: 'detail',
      emoji: '🎲',
      probability: 0.12,
      scope: TagScope.global,
      groups: [_group(TagSubCategory.detail, '完整细节池', '🎲')],
    ),
  ];

  /// Adds new built-in stages without replacing user-adjusted settings.
  static List<RandomCategory> mergeMissingBuiltins(
    List<RandomCategory> existing,
  ) {
    final merged = [...existing];
    for (final canonical in createDefault()) {
      final index = merged.indexWhere(
        (category) =>
            category.id == canonical.id || category.key == canonical.key,
      );
      if (index < 0) {
        merged.add(canonical);
        continue;
      }
      final current = merged[index];
      if (!current.isBuiltin) continue;
      final sourceIds = current.groups.map((group) => group.sourceId).toSet();
      final missingGroups = canonical.groups
          .where((group) => !sourceIds.contains(group.sourceId))
          .toList();
      if (missingGroups.isNotEmpty) {
        merged[index] = current.copyWith(
          groups: [...current.groups, ...missingGroups],
        );
      }
    }
    return merged;
  }

  static List<RandomCategory> createDefaultCopy() =>
      createDefault().map((category) => category.deepCopy()).toList();

  static List<RandomCategory> createDefaultForVersion(WordlistType version) {
    return switch (version) {
      WordlistType.v4 => createDefault(),
      WordlistType.legacy => createDefault(),
      WordlistType.furry => _createFurryDefault(),
    };
  }

  static List<RandomCategory> _createFurryDefault() {
    return createDefault().map((category) {
      if (category.key != 'bodyFeature') return category;
      return category.copyWith(
        groups: category.groups.map((group) {
          if (group.sourceId != TagSubCategory.species.name) return group;
          return group.copyWith(probability: 0.65);
        }).toList(),
      );
    }).toList();
  }

  static RandomCategory _category({
    required String id,
    required String name,
    required String key,
    required String emoji,
    required double probability,
    required TagScope scope,
    required List<RandomTagGroup> groups,
  }) {
    return RandomCategory(
      id: id,
      name: name,
      key: key,
      emoji: emoji,
      isBuiltin: true,
      probability: probability,
      groupSelectionMode: SelectionMode.all,
      scope: scope,
      groups: groups,
    );
  }

  static RandomTagGroup _group(
    TagSubCategory category,
    String name,
    String emoji, {
    double probability = 1,
    List<String> genders = const [],
  }) {
    return RandomTagGroup.fromBuiltin(
      name: name,
      builtinCategoryKey: category.name,
      emoji: emoji,
    ).copyWith(
      probability: probability,
      genderRestrictionEnabled: genders.isNotEmpty,
      applicableGenders: genders,
      scope:
          category == TagSubCategory.camera ||
              category == TagSubCategory.framing ||
              category == TagSubCategory.focus ||
              category == TagSubCategory.background ||
              category == TagSubCategory.scene ||
              category == TagSubCategory.style ||
              category == TagSubCategory.prop ||
              category == TagSubCategory.effect ||
              category == TagSubCategory.year ||
              category == TagSubCategory.detail
          ? TagScope.global
          : TagScope.character,
    );
  }
}
