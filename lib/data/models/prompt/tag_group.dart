import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag_group.freezed.dart';
part 'tag_group.g.dart';

/// Tag Group 模型
///
/// 对应 Danbooru wiki_pages 的 tag_group 页面
/// 用于从 Danbooru 获取按语义分类的标签集合
@freezed
class TagGroup with _$TagGroup {
  const TagGroup._();

  const factory TagGroup({
    /// wiki_page ID
    required int id,

    /// tag_group 标题 (如 "tag_group:hair_color")
    required String title,

    /// 显示名称 (如 "Hair Color")
    required String displayName,

    /// 父级 tag_group 标题 (用于层级结构)
    String? parentTitle,

    /// 子 tag_group 标题列表
    @Default([]) List<String> childGroupTitles,

    /// 此分组包含的标签列表（带热度）
    @Default([]) List<TagGroupEntry> tags,

    /// 原始标签总数（筛选前）
    @Default(0) int originalTagCount,

    /// 最后更新时间
    DateTime? lastUpdated,

    /// 层级深度 (0=顶级, 1=二级, ...)
    @Default(0) int depth,
  }) = _TagGroup;

  factory TagGroup.fromJson(Map<String, dynamic> json) =>
      _$TagGroupFromJson(json);

  /// 是否有子分组
  bool get hasChildren => childGroupTitles.isNotEmpty;

  /// 是否有标签
  bool get hasTags => tags.isNotEmpty;

  /// 标签总数
  int get tagCount => tags.length;

  /// 获取高于热度阈值的标签
  List<TagGroupEntry> getTagsAboveThreshold(int minPostCount) =>
      tags.where((t) => t.postCount >= minPostCount).toList();

  /// 获取高于热度阈值的标签数量
  int getTagCountAboveThreshold(int minPostCount) =>
      tags.where((t) => t.postCount >= minPostCount).length;

  /// 从 wiki_page 标题提取显示名称
  /// 例如: "tag_group:hair_color" -> "Hair Color"
  static String titleToDisplayName(String title) {
    // 移除 "tag_group:" 前缀
    var name = title;
    if (name.startsWith('tag_group:')) {
      name = name.substring('tag_group:'.length);
    }

    // 检查是否有中文翻译
    final chineseName = _tagGroupChineseNames[name];
    if (chineseName != null) {
      return chineseName;
    }

    // 将下划线替换为空格，并将首字母大写
    return name
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  /// Tag Group 中文翻译映射表
  /// 这些翻译用于将 Danbooru 的 tag_group 标题显示为中文
  static const Map<String, String> _tagGroupChineseNames = {
    // 外貌特征
    'hair_color': '发色',
    'hair_styles': '发型',
    'hair_length': '发长',
    'eye_color': '瞳色',
    'eyes': '眼睛',
    'skin_color': '肤色',
    'ears_tags': '耳朵',
    'breasts_tags': '胸部',
    // 姿势与动作
    'posture': '姿势',
    'poses': '姿势',
    'gestures': '手势',
    // 服装与配饰
    'attire': '服装',
    'clothing': '服装',
    'dress': '连衣裙',
    'tops': '上装',
    'bottoms': '下装',
    'swimwear': '泳装',
    'underwear': '内衣',
    'panties': '内裤',
    'bra': '胸罩',
    'sleeves': '袖子',
    'nudity': '裸体',
    // 配饰
    'headwear': '头饰',
    'eyewear': '眼镜',
    'footwear': '鞋履',
    'legwear': '腿饰',
    'handwear': '手套',
    'accessories': '配饰',
    'jewelry': '首饰',
    'piercings': '穿孔饰品',
    // 背景与场景
    'backgrounds': '背景',
    'scenery': '风景',
    'locations': '场所',
    'weather': '天气',
    'doors_and_gates': '门户',
    // 画风与构图
    'image_composition': '构图',
    'art_styles': '画风',
    'lighting': '光效',
    // 其他分类
    'people': '人物',
    'cats': '猫',
    'dogs': '狗',
    'cards': '卡片',
    'objects': '物品',
    'food': '食物',
    'animals': '动物',
    'plants': '植物',
    'vehicles': '载具',
    'weapons': '武器',
  };
}

/// Tag Group 中的标签条目
@freezed
class TagGroupEntry with _$TagGroupEntry {
  const TagGroupEntry._();

  const factory TagGroupEntry({
    /// 标签名 (如 "blonde_hair")
    required String name,

    /// 帖子数量（热度）
    @Default(0) int postCount,

    /// 是否已获取热度信息
    @Default(false) bool hasPostCount,
  }) = _TagGroupEntry;

  factory TagGroupEntry.fromJson(Map<String, dynamic> json) =>
      _$TagGroupEntryFromJson(json);

  /// 显示名称 (空格格式)
  String get displayName => name.replaceAll('_', ' ');

  /// 格式化的热度显示
  /// 例如: 1234567 -> "1.2M", 12345 -> "12.3K"
  String get formattedPostCount {
    if (postCount >= 1000000) {
      return '${(postCount / 1000000).toStringAsFixed(1)}M';
    } else if (postCount >= 1000) {
      return '${(postCount / 1000).toStringAsFixed(1)}K';
    }
    return postCount.toString();
  }
}

/// Tag Group 同步进度
class TagGroupSyncProgress {
  final double progress; // 0.0 - 1.0
  final String message;
  final String? currentGroup;
  final int completedGroups;
  final int totalGroups;
  final int fetchedTags;
  final int filteredTags;

  const TagGroupSyncProgress({
    required this.progress,
    required this.message,
    this.currentGroup,
    this.completedGroups = 0,
    this.totalGroups = 0,
    this.fetchedTags = 0,
    this.filteredTags = 0,
  });

  factory TagGroupSyncProgress.initial() {
    return const TagGroupSyncProgress(
      progress: 0,
      message: '准备同步...',
    );
  }

  factory TagGroupSyncProgress.fetchingGroup(
    String groupName,
    int completed,
    int total,
  ) {
    return TagGroupSyncProgress(
      progress: total > 0 ? completed / total * 0.5 : 0,
      message: '正在获取 $groupName...',
      currentGroup: groupName,
      completedGroups: completed,
      totalGroups: total,
    );
  }

  factory TagGroupSyncProgress.fetchingTags(
    String groupName,
    int fetchedTags,
  ) {
    return TagGroupSyncProgress(
      progress: 0.5,
      message: '正在获取 $groupName 标签热度...',
      currentGroup: groupName,
      fetchedTags: fetchedTags,
    );
  }

  factory TagGroupSyncProgress.filtering(int fetchedTags, int filteredTags) {
    return TagGroupSyncProgress(
      progress: 0.8,
      message: '正在筛选标签...',
      fetchedTags: fetchedTags,
      filteredTags: filteredTags,
    );
  }

  factory TagGroupSyncProgress.merging() {
    return const TagGroupSyncProgress(
      progress: 0.9,
      message: '正在合并标签...',
    );
  }

  factory TagGroupSyncProgress.saving() {
    return const TagGroupSyncProgress(
      progress: 0.95,
      message: '正在保存...',
    );
  }

  factory TagGroupSyncProgress.completed(int totalTags, int filteredTags) {
    return TagGroupSyncProgress(
      progress: 1.0,
      message: '同步完成',
      fetchedTags: totalTags,
      filteredTags: filteredTags,
    );
  }

  factory TagGroupSyncProgress.failed(String error) {
    return TagGroupSyncProgress(
      progress: 0,
      message: '同步失败: $error',
    );
  }
}

/// Tag Group 同步结果
class TagGroupSyncResult {
  /// 按目标分类合并的标签
  final Map<String, List<TagGroupEntry>> tagsByCategory;

  /// 每个分组获取的标签数量（筛选后）
  final Map<String, int> tagCountByGroup;

  /// 每个分组的原始标签数量（筛选前）
  final Map<String, int> originalTagCountByGroup;

  /// 总获取标签数
  final int totalFetchedTags;

  /// 筛选后标签数
  final int totalFilteredTags;

  /// 是否成功
  final bool success;

  /// 错误信息
  final String? error;

  const TagGroupSyncResult({
    this.tagsByCategory = const {},
    this.tagCountByGroup = const {},
    this.originalTagCountByGroup = const {},
    this.totalFetchedTags = 0,
    this.totalFilteredTags = 0,
    this.success = true,
    this.error,
  });

  factory TagGroupSyncResult.failed(String error) {
    return TagGroupSyncResult(
      success: false,
      error: error,
    );
  }
}
