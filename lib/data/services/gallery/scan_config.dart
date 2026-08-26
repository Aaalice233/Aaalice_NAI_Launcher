import 'dart:io';

/// 扫描优先级
enum ScanPriority {
  /// 高优先级 - 最小延迟，适合启动扫描
  high,
  /// 低优先级 - 较大延迟，适合后台扫描
  low,
}

/// 扫描配置类
///
/// 封装扫描过程的所有配置参数，便于管理和传递
class ScanConfig {
  /// 批次大小 - 每批处理的文件数
  final int batchSize;

  /// 文件扩展名白名单
  final List<String> supportedExtensions;

  /// 高优先级扫描的延迟（毫秒）
  final int highPriorityDelayMs;

  /// 低优先级扫描的延迟（毫秒）
  final int lowPriorityDelayMs;

  /// 哈希缓存有效期
  final Duration hashCacheValidityDuration;

  /// 小文件阈值（小于此值直接计算完整哈希）
  final int smallFileThreshold;

  /// 大文件哈希计算时的头部字节数
  final int hashHeadBytes;

  /// 大文件哈希计算时的尾部字节数
  final int hashTailBytes;

  /// 渐进式读取阈值列表（字节）
  final List<int> progressiveReadThresholds;

  /// 最大并发 isolate 数量
  final int maxConcurrentIsolates;

  /// 是否启用哈希缓存
  final bool enableHashCache;

  /// 是否启用进度回调节流
  final bool enableProgressThrottling;

  /// 进度回调节流间隔
  final Duration progressThrottleInterval;

  /// 是否跳过隐藏文件和目录
  final bool skipHiddenFiles;

  /// 缩略图目录名称列表
  final List<String> thumbnailDirNames;

  const ScanConfig({
    this.batchSize = 20,
    this.supportedExtensions = const ['.png', '.jpg', '.jpeg', '.webp'],
    this.highPriorityDelayMs = 10,
    this.lowPriorityDelayMs = 100,
    this.hashCacheValidityDuration = const Duration(minutes: 5),
    this.smallFileThreshold = 16 * 1024, // 16KB
    this.hashHeadBytes = 8192, // 8KB
    this.hashTailBytes = 8192, // 8KB
    this.progressiveReadThresholds = const [
      100 * 1024, // 100KB
      500 * 1024, // 500KB
      2 * 1024 * 1024, // 2MB
    ],
    this.maxConcurrentIsolates = 2,
    this.enableHashCache = true,
    this.enableProgressThrottling = true,
    this.progressThrottleInterval = const Duration(milliseconds: 100),
    this.skipHiddenFiles = true,
    this.thumbnailDirNames = const ['.thumbs', 'thumbs', '.thumb', 'thumb', 'thumbnails', '.thumbnails', 'cache', '.cache', 'temp', '.temp'],
  });

  /// 快速扫描配置（用于启动时）
  const ScanConfig.quick({
    this.batchSize = 20,
    this.supportedExtensions = const ['.png', '.jpg', '.jpeg', '.webp'],
    this.highPriorityDelayMs = 5,
    this.lowPriorityDelayMs = 50,
    this.hashCacheValidityDuration = const Duration(minutes: 5),
    this.smallFileThreshold = 16 * 1024,
    this.hashHeadBytes = 8192,
    this.hashTailBytes = 8192,
    this.progressiveReadThresholds = const [
      100 * 1024,
      500 * 1024,
    ],
    this.maxConcurrentIsolates = 1,
    this.enableHashCache = true,
    this.enableProgressThrottling = true,
    this.progressThrottleInterval = const Duration(milliseconds: 50),
    this.skipHiddenFiles = true,
    this.thumbnailDirNames = const ['.thumbs', 'thumbs', '.thumb'],
  });

  /// 后台扫描配置（用于增量扫描）
  const ScanConfig.background({
    this.batchSize = 20,
    this.supportedExtensions = const ['.png', '.jpg', '.jpeg', '.webp'],
    this.highPriorityDelayMs = 50,
    this.lowPriorityDelayMs = 200,
    this.hashCacheValidityDuration = const Duration(minutes: 10),
    this.smallFileThreshold = 16 * 1024,
    this.hashHeadBytes = 8192,
    this.hashTailBytes = 8192,
    this.progressiveReadThresholds = const [
      100 * 1024,
      500 * 1024,
      2 * 1024 * 1024,
    ],
    this.maxConcurrentIsolates = 2,
    this.enableHashCache = true,
    this.enableProgressThrottling = true,
    this.progressThrottleInterval = const Duration(milliseconds: 500),
    this.skipHiddenFiles = true,
    this.thumbnailDirNames = const ['.thumbs', 'thumbs', '.thumb'],
  });

  /// 全量扫描配置
  const ScanConfig.full({
    this.batchSize = 20,
    this.supportedExtensions = const ['.png', '.jpg', '.jpeg', '.webp'],
    this.highPriorityDelayMs = 10,
    this.lowPriorityDelayMs = 100,
    this.hashCacheValidityDuration = const Duration(minutes: 5),
    this.smallFileThreshold = 16 * 1024,
    this.hashHeadBytes = 8192,
    this.hashTailBytes = 8192,
    this.progressiveReadThresholds = const [
      100 * 1024,
      500 * 1024,
      2 * 1024 * 1024,
    ],
    this.maxConcurrentIsolates = 2,
    this.enableHashCache = true,
    this.enableProgressThrottling = false,
    this.progressThrottleInterval = Duration.zero,
    this.skipHiddenFiles = true,
    this.thumbnailDirNames = const ['.thumbs', 'thumbs', '.thumb'],
  });

  /// 复制并修改配置
  ScanConfig copyWith({
    int? batchSize,
    List<String>? supportedExtensions,
    int? highPriorityDelayMs,
    int? lowPriorityDelayMs,
    Duration? hashCacheValidityDuration,
    int? smallFileThreshold,
    int? hashHeadBytes,
    int? hashTailBytes,
    List<int>? progressiveReadThresholds,
    int? maxConcurrentIsolates,
    bool? enableHashCache,
    bool? enableProgressThrottling,
    Duration? progressThrottleInterval,
    bool? skipHiddenFiles,
    List<String>? thumbnailDirNames,
  }) {
    return ScanConfig(
      batchSize: batchSize ?? this.batchSize,
      supportedExtensions: supportedExtensions ?? this.supportedExtensions,
      highPriorityDelayMs: highPriorityDelayMs ?? this.highPriorityDelayMs,
      lowPriorityDelayMs: lowPriorityDelayMs ?? this.lowPriorityDelayMs,
      hashCacheValidityDuration:
          hashCacheValidityDuration ?? this.hashCacheValidityDuration,
      smallFileThreshold: smallFileThreshold ?? this.smallFileThreshold,
      hashHeadBytes: hashHeadBytes ?? this.hashHeadBytes,
      hashTailBytes: hashTailBytes ?? this.hashTailBytes,
      progressiveReadThresholds:
          progressiveReadThresholds ?? this.progressiveReadThresholds,
      maxConcurrentIsolates:
          maxConcurrentIsolates ?? this.maxConcurrentIsolates,
      enableHashCache: enableHashCache ?? this.enableHashCache,
      enableProgressThrottling:
          enableProgressThrottling ?? this.enableProgressThrottling,
      progressThrottleInterval:
          progressThrottleInterval ?? this.progressThrottleInterval,
      skipHiddenFiles: skipHiddenFiles ?? this.skipHiddenFiles,
      thumbnailDirNames: thumbnailDirNames ?? this.thumbnailDirNames,
    );
  }

  /// 获取指定优先级的延迟
  Duration getDelay(ScanPriority priority) {
    return Duration(
      milliseconds: priority == ScanPriority.high
          ? highPriorityDelayMs
          : lowPriorityDelayMs,
    );
  }

  /// 检查文件扩展名是否支持
  bool isSupportedExtension(String path) {
    final ext = path.toLowerCase();
    return supportedExtensions.any((e) => ext.endsWith(e));
  }

  /// Scanner enumeration, pre-counting, and caller-side discovery must all
  /// use this predicate so progress totals describe the same file set.
  bool acceptsGalleryImagePath(String path) {
    return isSupportedExtension(path) && !isThumbnailPath(path);
  }

  /// 检查路径是否为缩略图路径
  bool isThumbnailPath(String path) {
    final separator = Platform.pathSeparator;
    for (final dirName in thumbnailDirNames) {
      if (path.contains('$separator$dirName$separator') ||
          path.contains('.$dirName.')) {
        return true;
      }
    }
    return false;
  }

  /// 检查是否为隐藏文件
  bool isHiddenFile(String path) {
    if (!skipHiddenFiles) return false;
    final fileName = path.split(Platform.pathSeparator).last;
    return fileName.startsWith('.');
  }
}

/// 扫描类型
enum ScanType {
  /// 快速扫描 - 只扫描最近的文件
  quick,
  /// 增量扫描 - 检测变更
  incremental,
  /// 全量扫描 - 扫描所有文件
  full,
  /// 元数据补全 - 为缺少元数据的文件解析
  fillMetadata,
  /// 数据一致性修复 - 标记文件系统中不存在的记录
  consistencyFix,
}

/// 扫描阶段
enum ScanPhase {
  /// 空闲
  idle,
  /// 检测中
  checking,
  /// 扫描目录
  scanning,
  /// 计算哈希
  hashing,
  /// 解析元数据
  parsing,
  /// 写入数据库
  indexing,
  /// 补全元数据
  fillingMetadata,
  /// 清理已删除文件
  cleaning,
  /// 完成
  completed,
  /// 错误
  error,
  /// 暂停
  paused,
}

/// 扫描阶段扩展
extension ScanPhaseExtension on ScanPhase {
  /// 获取本地化显示名称
  String get displayName {
    switch (this) {
      case ScanPhase.idle:
        return '空闲';
      case ScanPhase.checking:
        return '检测中';
      case ScanPhase.scanning:
        return '扫描目录';
      case ScanPhase.hashing:
        return '计算哈希';
      case ScanPhase.parsing:
        return '解析元数据';
      case ScanPhase.indexing:
        return '写入数据库';
      case ScanPhase.fillingMetadata:
        return '补全元数据';
      case ScanPhase.cleaning:
        return '清理已删除';
      case ScanPhase.completed:
        return '完成';
      case ScanPhase.error:
        return '错误';
      case ScanPhase.paused:
        return '已暂停';
    }
  }

  /// 是否处于活动状态
  bool get isActive =>
      this != ScanPhase.idle &&
      this != ScanPhase.completed &&
      this != ScanPhase.error &&
      this != ScanPhase.paused;

  /// 是否可以暂停
  bool get canPause =>
      this == ScanPhase.scanning ||
      this == ScanPhase.hashing ||
      this == ScanPhase.parsing ||
      this == ScanPhase.indexing ||
      this == ScanPhase.fillingMetadata;
}
