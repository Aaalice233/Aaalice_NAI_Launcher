import '../../models/prompt/random_category.dart';
import '../../models/prompt/random_tag_group.dart';
import '../../models/prompt/weighted_tag.dart';

/// 标签源委托接口
///
/// 定义从不同来源获取标签的策略模式
/// - Custom: 用户自定义标签列表
/// - TagGroup: Danbooru Tag Group 同步
/// - Pool: Danbooru Pool 同步
/// - Builtin: 内置词库
abstract class TagSourceDelegate {
  /// 获取标签列表
  ///
  /// [group] 标签分组配置
  /// [category] 所属类别（用于继承设置）
  /// 返回可选中的标签列表
  Future<List<WeightedTag>> getTagsForGroup(
    RandomTagGroup group,
    RandomCategory category,
  );

  /// 检查是否支持此来源类型
  bool supports(RandomTagGroup group);

  /// 获取来源类型名称
  String get sourceTypeName;
}

/// 标签源类型枚举
enum TagSourceType {
  custom('自定义'),
  tagGroup('Danbooru Tag Group'),
  pool('Danbooru Pool'),
  builtin('内置词库');

  final String displayName;
  const TagSourceType(this.displayName);
}
