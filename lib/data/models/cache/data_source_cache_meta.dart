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
  all(0, '全部标签', 'All tags'),
  hot10k(10000, '热门 >10K', 'Hot >10K'),
  common1k(1000, '常用 >1K', 'Common >1K'),
  common100(100, '一般 >100', 'Normal >100'),
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
