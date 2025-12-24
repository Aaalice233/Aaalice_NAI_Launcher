import 'random_category.dart';
import 'random_tag_group.dart';
import 'weighted_tag.dart';

/// 默认类别配置
///
/// 为新用户提供预配置的类别和分组，包含 NAI 内置标签
class DefaultCategories {
  /// 创建默认类别列表
  ///
  /// 每个类别包含一个"NAI内置"分组，默认启用，并预填充标签数据
  static List<RandomCategory> createDefault() {
    return [
      // 发色
      RandomCategory.create(
        name: '发色',
        key: 'hairColor',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'blonde hair', weight: 5),
              WeightedTag(tag: 'blue hair', weight: 4),
              WeightedTag(tag: 'black hair', weight: 6),
              WeightedTag(tag: 'brown hair', weight: 5),
              WeightedTag(tag: 'red hair', weight: 3),
              WeightedTag(tag: 'white hair', weight: 3),
              WeightedTag(tag: 'pink hair', weight: 2),
              WeightedTag(tag: 'green hair', weight: 2),
              WeightedTag(tag: 'purple hair', weight: 2),
              WeightedTag(tag: 'silver hair', weight: 2),
              WeightedTag(tag: 'grey hair', weight: 2),
              WeightedTag(tag: 'orange hair', weight: 2),
              WeightedTag(tag: 'multicolored hair', weight: 1),
            ],
          ),
        ],
      ),
      // 瞳色
      RandomCategory.create(
        name: '瞳色',
        key: 'eyeColor',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'blue eyes', weight: 6),
              WeightedTag(tag: 'red eyes', weight: 5),
              WeightedTag(tag: 'green eyes', weight: 4),
              WeightedTag(tag: 'brown eyes', weight: 4),
              WeightedTag(tag: 'purple eyes', weight: 3),
              WeightedTag(tag: 'yellow eyes', weight: 3),
              WeightedTag(tag: 'golden eyes', weight: 3),
              WeightedTag(tag: 'amber eyes', weight: 3),
              WeightedTag(tag: 'heterochromia', weight: 1),
            ],
          ),
        ],
      ),
      // 发型
      RandomCategory.create(
        name: '发型',
        key: 'hairStyle',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'long hair', weight: 8),
              WeightedTag(tag: 'short hair', weight: 6),
              WeightedTag(tag: 'medium hair', weight: 5),
              WeightedTag(tag: 'twintails', weight: 4),
              WeightedTag(tag: 'ponytail', weight: 4),
              WeightedTag(tag: 'braid', weight: 3),
              WeightedTag(tag: 'twin braids', weight: 2),
              WeightedTag(tag: 'bun', weight: 2),
              WeightedTag(tag: 'side ponytail', weight: 2),
              WeightedTag(tag: 'drill hair', weight: 1),
            ],
          ),
        ],
      ),
      // 表情
      RandomCategory.create(
        name: '表情',
        key: 'expression',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'smile', weight: 10),
              WeightedTag(tag: 'blush', weight: 8),
              WeightedTag(tag: 'open mouth', weight: 6),
              WeightedTag(tag: 'closed eyes', weight: 4),
              WeightedTag(tag: 'grin', weight: 3),
              WeightedTag(tag: 'expressionless', weight: 2),
              WeightedTag(tag: 'frown', weight: 2),
              WeightedTag(tag: 'crying', weight: 1),
              WeightedTag(tag: 'angry', weight: 1),
            ],
          ),
        ],
      ),
      // 姿势
      RandomCategory.create(
        name: '姿势',
        key: 'pose',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'looking at viewer', weight: 10),
              WeightedTag(tag: 'standing', weight: 8),
              WeightedTag(tag: 'sitting', weight: 7),
              WeightedTag(tag: 'lying', weight: 4),
              WeightedTag(tag: 'kneeling', weight: 3),
              WeightedTag(tag: 'walking', weight: 3),
              WeightedTag(tag: 'running', weight: 2),
              WeightedTag(tag: 'from above', weight: 3),
              WeightedTag(tag: 'from below', weight: 2),
              WeightedTag(tag: 'from side', weight: 3),
              WeightedTag(tag: 'from behind', weight: 2),
            ],
          ),
        ],
      ),
      // 服装
      RandomCategory.create(
        name: '服装',
        key: 'clothing',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'school uniform', weight: 8),
              WeightedTag(tag: 'dress', weight: 7),
              WeightedTag(tag: 'casual clothes', weight: 6),
              WeightedTag(tag: 'maid', weight: 4),
              WeightedTag(tag: 'kimono', weight: 3),
              WeightedTag(tag: 'swimsuit', weight: 3),
              WeightedTag(tag: 'uniform', weight: 4),
              WeightedTag(tag: 'armor', weight: 2),
            ],
          ),
        ],
      ),
      // 配饰
      RandomCategory.create(
        name: '配饰',
        key: 'accessory',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'ribbon', weight: 6),
              WeightedTag(tag: 'bow', weight: 5),
              WeightedTag(tag: 'hair ornament', weight: 6),
              WeightedTag(tag: 'hairband', weight: 4),
              WeightedTag(tag: 'glasses', weight: 3),
              WeightedTag(tag: 'hat', weight: 3),
              WeightedTag(tag: 'earrings', weight: 2),
              WeightedTag(tag: 'necklace', weight: 2),
            ],
          ),
        ],
      ),
      // 身体特征
      RandomCategory.create(
        name: '身体特征',
        key: 'bodyFeature',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'large breasts', weight: 5),
              WeightedTag(tag: 'medium breasts', weight: 6),
              WeightedTag(tag: 'small breasts', weight: 4),
              WeightedTag(tag: 'flat chest', weight: 3),
              WeightedTag(tag: 'thighs', weight: 4),
              WeightedTag(tag: 'midriff', weight: 3),
            ],
          ),
        ],
      ),
      // 背景
      RandomCategory.create(
        name: '背景',
        key: 'background',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'simple background', weight: 10),
              WeightedTag(tag: 'white background', weight: 8),
              WeightedTag(tag: 'grey background', weight: 5),
              WeightedTag(tag: 'black background', weight: 4),
              WeightedTag(tag: 'gradient background', weight: 3),
              WeightedTag(tag: 'blurred background', weight: 3),
              WeightedTag(tag: 'abstract background', weight: 2),
              WeightedTag(tag: 'detailed background', weight: 5),
            ],
          ),
        ],
      ),
      // 场景
      RandomCategory.create(
        name: '场景',
        key: 'scene',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'outdoors', weight: 8),
              WeightedTag(tag: 'indoors', weight: 8),
              WeightedTag(tag: 'scenery', weight: 6),
              WeightedTag(tag: 'nature', weight: 5),
              WeightedTag(tag: 'city', weight: 4),
              WeightedTag(tag: 'sky', weight: 5),
              WeightedTag(tag: 'clouds', weight: 4),
              WeightedTag(tag: 'sunset', weight: 3),
              WeightedTag(tag: 'night', weight: 3),
              WeightedTag(tag: 'rain', weight: 2),
              WeightedTag(tag: 'snow', weight: 2),
            ],
          ),
        ],
      ),
      // 风格
      RandomCategory.create(
        name: '风格',
        key: 'style',
        groups: [
          RandomTagGroup.custom(
            name: 'NAI内置',
            probability: 0.5,
            selectionMode: SelectionMode.single,
            tags: const [
              WeightedTag(tag: 'masterpiece', weight: 10),
              WeightedTag(tag: 'best quality', weight: 10),
              WeightedTag(tag: 'high quality', weight: 8),
              WeightedTag(tag: 'detailed', weight: 6),
              WeightedTag(tag: 'photorealistic', weight: 2),
              WeightedTag(tag: 'anime', weight: 5),
            ],
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
}
