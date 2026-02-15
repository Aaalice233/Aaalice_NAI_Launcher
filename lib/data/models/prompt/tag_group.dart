import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/widgets.dart';

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
  /// 例如: "tag_group:hair_color" -> "Hair Color" (英文) 或 "发色" (中文)
  static String titleToDisplayName(String title, [BuildContext? context]) {
    // 移除 "tag_group:" 前缀
    var name = title;
    if (name.startsWith('tag_group:')) {
      name = name.substring('tag_group:'.length);
    }

    // 检查是否有中文翻译（仅在中文语言环境下使用）
    if (context != null) {
      final locale = Localizations.localeOf(context);
      if (locale.languageCode == 'zh') {
        final chineseName = _tagGroupChineseNames[name];
        if (chineseName != null) {
          return chineseName;
        }
      }
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
    'hair': '头发',
    'eye_color': '瞳色',
    'eyes': '眼睛',
    'eyes_tags': '眼睛',
    'skin_color': '肤色',
    'ears_tags': '耳朵',
    'breasts_tags': '胸部',
    // 姿势与动作
    'posture': '体态',
    'poses': '姿势',
    'gestures': '手势',
    'hands': '手部',
    'dances': '舞姿',
    'sexual_positions': '体位',
    // 服装与配饰
    'attire': '着装',
    'clothing': '服装',
    'dress': '裙装',
    'fashion_style': '穿搭风格',
    'tops': '上装',
    'bottoms': '下装',
    'swimwear': '泳装',
    'underwear': '内衣',
    'panties': '内裤',
    'bra': '文胸',
    'sleeves': '袖型',
    'legwear': '腿饰',
    'sexual_attire': '情趣服饰',
    'nudity': '裸露',
    'covering': '遮掩',
    // 配饰
    'accessories': '配饰',
    'headwear': '头饰',
    'eyewear': '眼饰',
    'glasses': '眼镜',
    'footwear': '鞋履',
    'handwear': '手饰',
    'jewelry': '珠宝',
    'piercings': '穿孔饰品',
    'neck_and_neckwear': '颈饰',
    'embellishment': '装饰',
    'makeup': '妆容',
    // 背景与场景
    'backgrounds': '背景',
    'scenery': '风景',
    'locations': '场景',
    'real_world_locations': '真实地点',
    'weather': '天气',
    'doors_and_gates': '门与闸',
    'water': '水',
    'fire': '火焰',
    'flowers': '花卉',
    'colors': '色彩',
    'patterns': '图案',
    // 画风与构图
    'image_composition': '构图',
    'visual_aesthetic': '视觉风格',
    'art_styles': '画风',
    'lighting': '光影',
    'focus_tags': '焦点',
    'artistic_license': '艺术演绎',
    'fine_art_parody': '名画戏仿',
    // 身体特征
    'body_parts': '身体部位',
    'ass': '臀部',
    'tail': '尾巴',
    'wings': '翅膀',
    'shoulders': '肩部',
    'skin_folds': '皮肤褶皱',
    // 人数
    'character_count': '人物数量',
    'groups': '群像',
    'family_relationships': '家庭关系',
    // 其他分类
    'face_tags': '面部表情',
    'people': '人物类型',
    'cats': '猫',
    'dogs': '狗',
    'birds': '鸟类',
    'legendary_creatures': '传说生物',
    'cards': '卡片',
    'objects': '物品',
    'food': '食物',
    'food_tags': '食物',
    'animals': '动物',
    'plants': '植物',
    'vehicles': '载具',
    'weapons': '武器',
    'technology': '科技',
    'symbols': '符号',
    'sports': '运动',
    'holidays_and_celebrations': '节日庆典',
    'jobs': '职业',
    'video_game': '电子游戏',
    'fighting_games': '格斗游戏',
    'shooter_games': '射击游戏',
    'visual_novel_games': '视觉小说',
    'role-playing_games': '角色扮演',
    'platform_games': '平台游戏',
    'board_games': '桌游',
    'card_games': '卡牌游戏',
    'metatags': '元标签',
    'text': '文字',
    'language': '语言',
    'scan': '扫描',
    'censorship': '审查',
    'audio_tags': '音频标签',
    'meme': '梗图',
    'history': '历史',
    'prints': '印花',
    'verbs_and_gerunds': '动作',
    'phrases': '短语',
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

/// Tag Group 同步进度类型
enum TagGroupSyncProgressType {
  initial,
  fetchingGroup,
  fetchingTags,
  filtering,
  merging,
  saving,
  completed,
  failed,
}

/// Tag Group 同步进度
class TagGroupSyncProgress {
  final double progress; // 0.0 - 1.0
  final TagGroupSyncProgressType type;
  final String? currentGroup;
  final int completedGroups;
  final int totalGroups;
  final int fetchedTags;
  final int filteredTags;
  final String? error;

  const TagGroupSyncProgress({
    required this.progress,
    required this.type,
    this.currentGroup,
    this.completedGroups = 0,
    this.totalGroups = 0,
    this.fetchedTags = 0,
    this.filteredTags = 0,
    this.error,
  });

  factory TagGroupSyncProgress.initial() {
    return const TagGroupSyncProgress(
      progress: 0,
      type: TagGroupSyncProgressType.initial,
    );
  }

  factory TagGroupSyncProgress.fetchingGroup(
    String groupName,
    int completed,
    int total,
  ) {
    // 获取 groups 是主要工作量，占 95% 进度
    return TagGroupSyncProgress(
      progress: total > 0 ? completed / total * 0.95 : 0,
      type: TagGroupSyncProgressType.fetchingGroup,
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
      progress: 0.96,
      type: TagGroupSyncProgressType.fetchingTags,
      currentGroup: groupName,
      fetchedTags: fetchedTags,
    );
  }

  factory TagGroupSyncProgress.filtering(int fetchedTags, int filteredTags) {
    return TagGroupSyncProgress(
      progress: 0.97,
      type: TagGroupSyncProgressType.filtering,
      fetchedTags: fetchedTags,
      filteredTags: filteredTags,
    );
  }

  factory TagGroupSyncProgress.merging() {
    return const TagGroupSyncProgress(
      progress: 0.98,
      type: TagGroupSyncProgressType.merging,
    );
  }

  factory TagGroupSyncProgress.saving() {
    return const TagGroupSyncProgress(
      progress: 0.99,
      type: TagGroupSyncProgressType.saving,
    );
  }

  factory TagGroupSyncProgress.completed(int totalTags, int filteredTags) {
    return TagGroupSyncProgress(
      progress: 1.0,
      type: TagGroupSyncProgressType.completed,
      fetchedTags: totalTags,
      filteredTags: filteredTags,
    );
  }

  factory TagGroupSyncProgress.failed(String error) {
    return TagGroupSyncProgress(
      progress: 0,
      type: TagGroupSyncProgressType.failed,
      error: error,
    );
  }

  /// 获取本地化消息
  String localizedMessage(BuildContext context) {
    return switch (type) {
      TagGroupSyncProgressType.initial => context.l10n.sync_preparing,
      TagGroupSyncProgressType.fetchingGroup =>
        context.l10n.sync_fetching(currentGroup ?? ''),
      TagGroupSyncProgressType.fetchingTags =>
        context.l10n.sync_fetching_tags(currentGroup ?? ''),
      TagGroupSyncProgressType.filtering => context.l10n.sync_filtering,
      TagGroupSyncProgressType.merging => context.l10n.sync_merging,
      TagGroupSyncProgressType.saving => context.l10n.sync_saving,
      TagGroupSyncProgressType.completed => context.l10n.sync_done,
      TagGroupSyncProgressType.failed => context.l10n.sync_failed(error ?? ''),
    };
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
