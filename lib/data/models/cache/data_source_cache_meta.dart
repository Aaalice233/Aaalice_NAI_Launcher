// 数据源缓存元数据模型

/// 自动刷新间隔
enum AutoRefreshInterval {
  days7(7, '7天', '7 days'),
  days15(15, '15天', '15 days'),
  days30(30, '30天', '30 days'),
  never(-1, '不自动刷新', 'Never');

  final int days;
  final String displayNameZh;
  final String displayNameEn;

  const AutoRefreshInterval(this.days, this.displayNameZh, this.displayNameEn);

  /// 显示名称（简化版，默认使用中文）
  String get displayName => displayNameZh;

  /// 根据天数获取枚举值
  static AutoRefreshInterval fromDays(int days) {
    return AutoRefreshInterval.values.firstWhere(
      (e) => e.days == days,
      orElse: () => AutoRefreshInterval.days30,
    );
  }

  /// 检查是否需要刷新
  bool shouldRefresh(DateTime? lastUpdate) {
    if (this == AutoRefreshInterval.never) return false;
    if (lastUpdate == null) return true;

    final daysSinceUpdate = DateTime.now().difference(lastUpdate).inDays;
    return daysSinceUpdate >= days;
  }
}

/// 热度档位预设
enum TagHotPreset {
  all(0, '全部', 'All'),
  hot10k(10000, '热门>10K', 'Hot>10K'),
  common1k(1000, '常用>1K', 'Common>1K'),
  medium500(500, '常用>500', 'Common>500'),
  low100(100, '一般>100', 'Normal>100'),
  minimal50(50, '少量>50', 'Minimal>50'),
  custom(-1, '自定义', 'Custom');

  final int threshold;
  final String displayNameZh;
  final String displayNameEn;

  const TagHotPreset(this.threshold, this.displayNameZh, this.displayNameEn);

  /// 显示名称（简化版，默认使用中文）
  String get displayName => displayNameZh;

  /// 根据阈值获取枚举值
  static TagHotPreset fromThreshold(int threshold) {
    return TagHotPreset.values.firstWhere(
      (e) => e.threshold == threshold,
      orElse: () => TagHotPreset.custom,
    );
  }

  /// 判断是否为自定义档位
  bool get isCustom => this == TagHotPreset.custom;
}

/// 标签分类阈值配置
///
/// 支持为不同分类（画师、角色、一般标签、版权、元标签）设置不同的热度阈值
class TagCategoryThresholds {
  final TagHotPreset generalPreset;
  final int generalCustomThreshold;
  final TagHotPreset artistPreset;
  final int artistCustomThreshold;
  final TagHotPreset characterPreset;
  final int characterCustomThreshold;
  final TagHotPreset copyrightPreset;
  final int copyrightCustomThreshold;
  final TagHotPreset metaPreset;
  final int metaCustomThreshold;

  const TagCategoryThresholds({
    this.generalPreset = TagHotPreset.common1k,
    this.generalCustomThreshold = 1000,
    this.artistPreset = TagHotPreset.minimal50,
    this.artistCustomThreshold = 50,
    this.characterPreset = TagHotPreset.low100,
    this.characterCustomThreshold = 100,
    this.copyrightPreset = TagHotPreset.medium500,
    this.copyrightCustomThreshold = 500,
    this.metaPreset = TagHotPreset.hot10k,
    this.metaCustomThreshold = 10000,
  });

  /// 获取一般标签的阈值
  int get generalThreshold => generalPreset.isCustom 
      ? generalCustomThreshold 
      : generalPreset.threshold;

  /// 获取画师标签的阈值
  int get artistThreshold => artistPreset.isCustom 
      ? artistCustomThreshold 
      : artistPreset.threshold;

  /// 获取角色标签的阈值
  int get characterThreshold => characterPreset.isCustom
      ? characterCustomThreshold
      : characterPreset.threshold;

  /// 获取版权标签的阈值
  int get copyrightThreshold => copyrightPreset.isCustom
      ? copyrightCustomThreshold
      : copyrightPreset.threshold;

  /// 获取元标签的阈值
  int get metaThreshold => metaPreset.isCustom
      ? metaCustomThreshold
      : metaPreset.threshold;

  /// 从JSON解析
  factory TagCategoryThresholds.fromJson(Map<String, dynamic> json) {
    return TagCategoryThresholds(
      generalPreset: TagHotPreset.fromThreshold(json['generalThreshold'] as int? ?? 1000),
      generalCustomThreshold: json['generalCustomThreshold'] as int? ?? 1000,
      artistPreset: TagHotPreset.fromThreshold(json['artistThreshold'] as int? ?? 50),
      artistCustomThreshold: json['artistCustomThreshold'] as int? ?? 50,
      characterPreset: TagHotPreset.fromThreshold(json['characterThreshold'] as int? ?? 100),
      characterCustomThreshold: json['characterCustomThreshold'] as int? ?? 100,
      copyrightPreset: TagHotPreset.fromThreshold(json['copyrightThreshold'] as int? ?? 500),
      copyrightCustomThreshold: json['copyrightCustomThreshold'] as int? ?? 500,
      metaPreset: TagHotPreset.fromThreshold(json['metaThreshold'] as int? ?? 10000),
      metaCustomThreshold: json['metaCustomThreshold'] as int? ?? 10000,
    );
  }

  /// 转为JSON
  Map<String, dynamic> toJson() => {
    'generalThreshold': generalThreshold,
    'generalCustomThreshold': generalCustomThreshold,
    'artistThreshold': artistThreshold,
    'artistCustomThreshold': artistCustomThreshold,
    'characterThreshold': characterThreshold,
    'characterCustomThreshold': characterCustomThreshold,
    'copyrightThreshold': copyrightThreshold,
    'copyrightCustomThreshold': copyrightCustomThreshold,
    'metaThreshold': metaThreshold,
    'metaCustomThreshold': metaCustomThreshold,
  };

  TagCategoryThresholds copyWith({
    TagHotPreset? generalPreset,
    int? generalCustomThreshold,
    TagHotPreset? artistPreset,
    int? artistCustomThreshold,
    TagHotPreset? characterPreset,
    int? characterCustomThreshold,
    TagHotPreset? copyrightPreset,
    int? copyrightCustomThreshold,
    TagHotPreset? metaPreset,
    int? metaCustomThreshold,
  }) {
    return TagCategoryThresholds(
      generalPreset: generalPreset ?? this.generalPreset,
      generalCustomThreshold: generalCustomThreshold ?? this.generalCustomThreshold,
      artistPreset: artistPreset ?? this.artistPreset,
      artistCustomThreshold: artistCustomThreshold ?? this.artistCustomThreshold,
      characterPreset: characterPreset ?? this.characterPreset,
      characterCustomThreshold: characterCustomThreshold ?? this.characterCustomThreshold,
      copyrightPreset: copyrightPreset ?? this.copyrightPreset,
      copyrightCustomThreshold: copyrightCustomThreshold ?? this.copyrightCustomThreshold,
      metaPreset: metaPreset ?? this.metaPreset,
      metaCustomThreshold: metaCustomThreshold ?? this.metaCustomThreshold,
    );
  }
}

/// 翻译数据缓存元数据
class TranslationCacheMeta {
  final DateTime lastUpdate;
  final int totalTags;
  final int version;

  const TranslationCacheMeta({
    required this.lastUpdate,
    required this.totalTags,
    this.version = 1,
  });

  factory TranslationCacheMeta.fromJson(Map<String, dynamic> json) {
    return TranslationCacheMeta(
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
      totalTags: json['totalTags'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'lastUpdate': lastUpdate.toIso8601String(),
        'totalTags': totalTags,
        'version': version,
      };

  TranslationCacheMeta copyWith({
    DateTime? lastUpdate,
    int? totalTags,
    int? version,
  }) {
    return TranslationCacheMeta(
      lastUpdate: lastUpdate ?? this.lastUpdate,
      totalTags: totalTags ?? this.totalTags,
      version: version ?? this.version,
    );
  }
}

/// 标签补全缓存元数据
class TagsCacheMeta {
  final DateTime lastUpdate;
  final int totalTags;
  final int hotThreshold;
  final TagHotPreset hotPreset;
  final AutoRefreshInterval refreshInterval;

  const TagsCacheMeta({
    required this.lastUpdate,
    required this.totalTags,
    required this.hotThreshold,
    required this.hotPreset,
    this.refreshInterval = AutoRefreshInterval.days30,
  });

  factory TagsCacheMeta.fromJson(Map<String, dynamic> json) {
    return TagsCacheMeta(
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
      totalTags: json['totalTags'] as int? ?? 0,
      hotThreshold: json['hotThreshold'] as int? ?? 1000,
      hotPreset: TagHotPreset.fromThreshold(json['hotThreshold'] as int? ?? 1000),
      refreshInterval: AutoRefreshInterval.fromDays(json['refreshIntervalDays'] as int? ?? 30),
    );
  }

  Map<String, dynamic> toJson() => {
        'lastUpdate': lastUpdate.toIso8601String(),
        'totalTags': totalTags,
        'hotThreshold': hotThreshold,
        'refreshIntervalDays': refreshInterval.days,
      };

  TagsCacheMeta copyWith({
    DateTime? lastUpdate,
    int? totalTags,
    int? hotThreshold,
    TagHotPreset? hotPreset,
    AutoRefreshInterval? refreshInterval,
  }) {
    return TagsCacheMeta(
      lastUpdate: lastUpdate ?? this.lastUpdate,
      totalTags: totalTags ?? this.totalTags,
      hotThreshold: hotThreshold ?? this.hotThreshold,
      hotPreset: hotPreset ?? this.hotPreset,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }
}

/// 画师标签同步状态
enum ArtistSyncStatus {
  idle,      // 空闲状态
  running,   // 进行中
  paused,    // 用户暂停
  failed,    // 失败（可恢复）
  completed, // 已完成
}

/// 画师标签同步断点
///
/// 用于记录画师标签拉取进度，支持断点续传
class ArtistsSyncCheckpoint {
  final int lastFetchedPage;      // 最后成功拉取的页码（0表示从未开始）
  final int importedCount;        // 已导入的记录数
  final DateTime? startTime;      // 本次同步开始时间
  final ArtistSyncStatus status;  // 同步状态
  final String? sessionId;        // 本次同步会话ID（防止多次启动冲突）
  final DateTime? lastUpdated;    // 最后更新时间

  const ArtistsSyncCheckpoint({
    this.lastFetchedPage = 0,
    this.importedCount = 0,
    this.startTime,
    this.status = ArtistSyncStatus.idle,
    this.sessionId,
    this.lastUpdated,
  });

  /// 初始状态
  factory ArtistsSyncCheckpoint.initial() => const ArtistsSyncCheckpoint();

  /// 从JSON解析
  factory ArtistsSyncCheckpoint.fromJson(Map<String, dynamic> json) {
    return ArtistsSyncCheckpoint(
      lastFetchedPage: json['lastFetchedPage'] as int? ?? 0,
      importedCount: json['importedCount'] as int? ?? 0,
      startTime: json['startTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int)
          : null,
      status: ArtistSyncStatus.values[json['status'] as int? ?? 0],
      sessionId: json['sessionId'] as String?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int)
          : null,
    );
  }

  /// 转为JSON
  Map<String, dynamic> toJson() => {
    'lastFetchedPage': lastFetchedPage,
    'importedCount': importedCount,
    'startTime': startTime?.millisecondsSinceEpoch,
    'status': status.index,
    'sessionId': sessionId,
    'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
  };

  /// 是否可以恢复
  bool get canResume =>
      (status == ArtistSyncStatus.paused || status == ArtistSyncStatus.failed) &&
      !isStale;

  /// 是否已过期（超过24小时）
  bool get isStale {
    if (lastUpdated == null) return false;
    return DateTime.now().difference(lastUpdated!).inHours > 24;
  }

  /// 复制并修改
  ArtistsSyncCheckpoint copyWith({
    int? lastFetchedPage,
    int? importedCount,
    DateTime? startTime,
    ArtistSyncStatus? status,
    String? sessionId,
    DateTime? lastUpdated,
  }) {
    return ArtistsSyncCheckpoint(
      lastFetchedPage: lastFetchedPage ?? this.lastFetchedPage,
      importedCount: importedCount ?? this.importedCount,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// 画师标签缓存元数据
class ArtistsCacheMeta {
  final DateTime lastUpdate;
  final int totalArtists;
  final bool syncFailed;
  final int minPostCount;

  const ArtistsCacheMeta({
    required this.lastUpdate,
    required this.totalArtists,
    this.syncFailed = false,
    this.minPostCount = 50,
  });

  factory ArtistsCacheMeta.fromJson(Map<String, dynamic> json) {
    return ArtistsCacheMeta(
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
      totalArtists: json['totalArtists'] as int? ?? 0,
      syncFailed: json['syncFailed'] as bool? ?? false,
      minPostCount: json['minPostCount'] as int? ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
        'lastUpdate': lastUpdate.toIso8601String(),
        'totalArtists': totalArtists,
        'syncFailed': syncFailed,
        'minPostCount': minPostCount,
      };

  ArtistsCacheMeta copyWith({
    DateTime? lastUpdate,
    int? totalArtists,
    bool? syncFailed,
    int? minPostCount,
  }) {
    return ArtistsCacheMeta(
      lastUpdate: lastUpdate ?? this.lastUpdate,
      totalArtists: totalArtists ?? this.totalArtists,
      syncFailed: syncFailed ?? this.syncFailed,
      minPostCount: minPostCount ?? this.minPostCount,
    );
  }
}
