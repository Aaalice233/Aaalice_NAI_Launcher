/// 预缓存的 Tag Group 完整标签数据
///
/// 数据来源：Danbooru API（热度阈值 1000）
/// 更新方式：开发者同步后更新此文件并提交到 git
///
/// 用途：
/// - 新用户首次选择类别时，立即显示预估标签数
/// - 无需等待网络同步即可获得 UI 反馈
class TagGroupPresetCache {
  TagGroupPresetCache._();

  /// 获取 tag_group 的预缓存数据
  /// 返回: {'tags': List<Map>, 'count': int, 'originalCount': int}
  static Map<String, dynamic>? getData(String groupTitle) => _cache[groupTitle];

  /// 获取预缓存的标签数量（筛选后）
  static int? getCount(String groupTitle) =>
      _cache[groupTitle]?['count'] as int?;

  /// 获取预缓存的原始标签数量（筛选前）
  static int? getOriginalCount(String groupTitle) =>
      _cache[groupTitle]?['originalCount'] as int?;

  /// 是否有缓存
  static bool hasCache(String groupTitle) => _cache.containsKey(groupTitle);

  /// 预缓存数据
  ///
  /// 格式:
  /// ```
  /// {
  ///   'tag_group:xxx': {
  ///     'count': 筛选后数量,
  ///     'originalCount': 原始数量,
  ///     'tags': [{'name': 'tag_name', 'postCount': 12345}, ...]
  ///   }
  /// }
  /// ```
  ///
  /// 开发者操作流程：
  /// 1. 运行应用，选择所有 tag group
  /// 2. 点击"立即同步"
  /// 3. 从同步结果提取数据填充到此处
  /// 4. 提交到 git 作为软件内置初始数据
  static const Map<String, Map<String, dynamic>> _cache = {
    // TODO: 开发者同步后填充数据
    // 示例:
    // 'tag_group:hair_color': {
    //   'count': 52,
    //   'originalCount': 128,
    //   'tags': [
    //     {'name': 'blonde_hair', 'postCount': 1234567},
    //     {'name': 'black_hair', 'postCount': 987654},
    //   ],
    // },
  };
}
