import 'package:uuid/uuid.dart';

import '../../services/wordlist_service.dart';
import 'random_category.dart';
import 'random_tag_group.dart';
import 'tag_category.dart';
import 'tag_scope.dart';

/// 默认类别配置
///
/// 为新用户提供预配置的类别和分组，使用 NAI 内置词库
/// 各类别概率基于 NAI 官方逻辑设置
class DefaultCategories {
  static const _uuid = Uuid();

  /// 创建默认类别列表
  ///
  /// 每个类别包含一个或多个内置词库分组，从 TagLibrary 动态获取标签
  /// 类别概率基于 NAI 逻辑：
  /// - 角色特征（发色、瞳色、服装）: 100%
  /// - 背景: 90%
  /// - 风格、身体特征: 30%
  /// - 其他: 50%
  static List<RandomCategory> createDefault() {
    return [
      // 发色 - 100% 概率（角色核心特征）
      RandomCategory(
        id: _uuid.v4(),
        name: '发色',
        key: 'hairColor',
        emoji: '🎨',
        isBuiltin: true,
        probability: 1.0,
        scope: TagScope.character,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '发色',
            builtinCategoryKey: TagSubCategory.hairColor.name,
            emoji: '🎨',
          ),
        ],
      ),
      // 瞳色 - 100% 概率（角色核心特征）
      RandomCategory(
        id: _uuid.v4(),
        name: '瞳色',
        key: 'eyeColor',
        emoji: '👁️',
        isBuiltin: true,
        probability: 1.0,
        scope: TagScope.character,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '瞳色',
            builtinCategoryKey: TagSubCategory.eyeColor.name,
            emoji: '👁️',
          ),
        ],
      ),
      // 发型 - 50% 概率
      RandomCategory(
        id: _uuid.v4(),
        name: '发型',
        key: 'hairStyle',
        emoji: '✂️',
        isBuiltin: true,
        probability: 0.5,
        scope: TagScope.character,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '发型',
            builtinCategoryKey: TagSubCategory.hairStyle.name,
            emoji: '✂️',
          ),
        ],
      ),
      // 表情 - 50% 概率
      RandomCategory(
        id: _uuid.v4(),
        name: '表情',
        key: 'expression',
        emoji: '😊',
        isBuiltin: true,
        probability: 0.5,
        scope: TagScope.character,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '表情',
            builtinCategoryKey: TagSubCategory.expression.name,
            emoji: '😊',
          ),
        ],
      ),
      // 姿势 - 50% 概率
      RandomCategory(
        id: _uuid.v4(),
        name: '姿势',
        key: 'pose',
        emoji: '🧘',
        isBuiltin: true,
        probability: 0.5,
        scope: TagScope.all,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '姿势',
            builtinCategoryKey: TagSubCategory.pose.name,
            emoji: '🧘',
          ),
        ],
      ),
      // 服装 - 100% 概率（拆分为 3 个词组）
      RandomCategory(
        id: _uuid.v4(),
        name: '服装',
        key: 'clothing',
        emoji: '👗',
        isBuiltin: true,
        probability: 1.0,
        scope: TagScope.character,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '女性服装',
            builtinCategoryKey: TagSubCategory.clothingFemale.name,
            emoji: '👗',
          ).copyWith(
            genderRestrictionEnabled: true,
            applicableGenders: ['girl'],
            scope: TagScope.character,
          ),
          RandomTagGroup.fromBuiltin(
            name: '男性服装',
            builtinCategoryKey: TagSubCategory.clothingMale.name,
            emoji: '👔',
          ).copyWith(
            genderRestrictionEnabled: true,
            applicableGenders: ['boy'],
            scope: TagScope.character,
          ),
          RandomTagGroup.fromBuiltin(
            name: '通用服装',
            builtinCategoryKey: TagSubCategory.clothingGeneral.name,
            emoji: '🎽',
          ).copyWith(
            genderRestrictionEnabled: false,
            scope: TagScope.character,
          ),
        ],
      ),
      // 配饰 - 50% 概率
      RandomCategory(
        id: _uuid.v4(),
        name: '配饰',
        key: 'accessory',
        emoji: '💍',
        isBuiltin: true,
        probability: 0.5,
        scope: TagScope.character,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '配饰',
            builtinCategoryKey: TagSubCategory.accessory.name,
            emoji: '💍',
          ),
        ],
      ),
      // 身体特征 - 30% 概率（拆分为 3 个词组）
      RandomCategory(
        id: _uuid.v4(),
        name: '身体特征',
        key: 'bodyFeature',
        emoji: '💃',
        isBuiltin: true,
        probability: 0.3,
        scope: TagScope.character,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '女性体型',
            builtinCategoryKey: TagSubCategory.bodyFeatureFemale.name,
            emoji: '👙',
          ).copyWith(
            genderRestrictionEnabled: true,
            applicableGenders: ['girl'],
            scope: TagScope.character,
          ),
          RandomTagGroup.fromBuiltin(
            name: '男性体型',
            builtinCategoryKey: TagSubCategory.bodyFeatureMale.name,
            emoji: '💪',
          ).copyWith(
            genderRestrictionEnabled: true,
            applicableGenders: ['boy'],
            scope: TagScope.character,
          ),
          RandomTagGroup.fromBuiltin(
            name: '通用体型',
            builtinCategoryKey: TagSubCategory.bodyFeatureGeneral.name,
            emoji: '🧍',
          ).copyWith(
            genderRestrictionEnabled: false,
            scope: TagScope.character,
          ),
        ],
      ),
      // 背景 - 90% 概率（NAI 使用 90%）
      RandomCategory(
        id: _uuid.v4(),
        name: '背景',
        key: 'background',
        emoji: '🌄',
        isBuiltin: true,
        probability: 0.9,
        scope: TagScope.global,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '背景',
            builtinCategoryKey: TagSubCategory.background.name,
            emoji: '🌄',
          ),
        ],
      ),
      // 场景 - 50% 概率
      RandomCategory(
        id: _uuid.v4(),
        name: '场景',
        key: 'scene',
        emoji: '🏞️',
        isBuiltin: true,
        probability: 0.5,
        scope: TagScope.global,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '场景',
            builtinCategoryKey: TagSubCategory.scene.name,
            emoji: '🏞️',
          ),
        ],
      ),
      // 风格 - 30% 概率（NAI 使用 30%）
      RandomCategory(
        id: _uuid.v4(),
        name: '风格',
        key: 'style',
        emoji: '🎭',
        isBuiltin: true,
        probability: 0.3,
        scope: TagScope.global,
        groups: [
          RandomTagGroup.fromBuiltin(
            name: '风格',
            builtinCategoryKey: TagSubCategory.style.name,
            emoji: '🎭',
          ),
        ],
      ),
    ];
  }

  /// 创建默认类别列表的深拷贝
  ///
  /// 用于恢复默认配置时使用
  static List<RandomCategory> createDefaultCopy() {
    return createDefault().map((c) => c.deepCopy()).toList();
  }

  /// 根据词库版本创建默认类别
  ///
  /// 不同版本的词库可能有不同的类别配置
  /// - V4: 完整 11 类别配置
  /// - Legacy: 简化配置（无多角色支持）
  /// - Furry: 特化配置（兽人角色）
  static List<RandomCategory> createDefaultForVersion(WordlistType version) {
    switch (version) {
      case WordlistType.v4:
        return createDefault();
      case WordlistType.legacy:
        return _createLegacyDefault();
      case WordlistType.furry:
        return _createFurryDefault();
    }
  }

  /// Legacy 版本的默认类别（简化配置）
  static List<RandomCategory> _createLegacyDefault() {
    // Legacy 版本使用相同的基础类别，但不支持多角色
    return createDefault();
  }

  /// Furry 版本的默认类别（兽人特化）
  static List<RandomCategory> _createFurryDefault() {
    // Furry 版本目前使用相同的基础类别
    // 未来可以添加兽人特有的类别如 fur_color, species 等
    return createDefault();
  }
}
