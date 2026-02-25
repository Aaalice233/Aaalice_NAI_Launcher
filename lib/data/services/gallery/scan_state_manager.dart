import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';

import '../../../core/utils/app_logger.dart';
import 'scan_config.dart';

/// 扫描状态枚举
enum ScanStatus {
  /// 空闲 - 初始状态
  idle,
  /// 扫描中
  scanning,
  /// 已暂停
  paused,
  /// 已完成
  completed,
  /// 出错
  error,
  /// 已取消
  cancelled,
}

/// 扫描状态扩展
extension ScanStatusExtension on ScanStatus {
  /// 获取本地化显示名称
  String get displayName {
    switch (this) {
      case ScanStatus.idle:
        return '空闲';
      case ScanStatus.scanning:
        return '扫描中';
      case ScanStatus.paused:
        return '已暂停';
      case ScanStatus.completed:
        return '已完成';
      case ScanStatus.error:
        return '出错';
      case ScanStatus.cancelled:
        return '已取消';
    }
  }

  /// 是否处于活动状态
  bool get isActive => this == ScanStatus.scanning;

  /// 是否可以暂停
  bool get canPause => this == ScanStatus.scanning;

  /// 是否可以恢复
  bool get canResume => this == ScanStatus.paused;

  /// 是否可以开始新扫描
  bool get canStart => this == ScanStatus.idle || this == ScanStatus.completed || this == ScanStatus.error || this == ScanStatus.cancelled;
}

/// 进度信息
class ScanProgressInfo {
  /// 已处理文件数
  final int processed;

  /// 总文件数（估计）
  final int total;

  /// 当前处理的文件路径
  final String? currentFile;

  /// 当前阶段
  final ScanPhase phase;

  /// 扫描速度（文件/秒）
  final double? speed;

  /// 预计剩余时间
  final Duration? estimatedRemaining;

  /// 进度百分比 (0-100)
  double get percentage => total > 0 ? (processed / total * 100).clamp(0, 100) : 0;

  const ScanProgressInfo({
    this.processed = 0,
    this.total = 0,
    this.currentFile,
    this.phase = ScanPhase.idle,
    this.speed,
    this.estimatedRemaining,
  });

  const ScanProgressInfo.initial()
      : processed = 0,
        total = 0,
        currentFile = null,
        phase = ScanPhase.idle,
        speed = null,
        estimatedRemaining = null;

  /// 复制并修改
  ScanProgressInfo copyWith({
    int? processed,
    int? total,
    String? currentFile,
    ScanPhase? phase,
    double? speed,
    Duration? estimatedRemaining,
  }) {
    return ScanProgressInfo(
      processed: processed ?? this.processed,
      total: total ?? this.total,
      currentFile: currentFile ?? this.currentFile,
      phase: phase ?? this.phase,
      speed: speed ?? this.speed,
      estimatedRemaining: estimatedRemaining ?? this.estimatedRemaining,
    );
  }

  Map<String, dynamic> toJson() => {
        'processed': processed,
        'total': total,
        'currentFile': currentFile,
        'phase': phase.name,
        'speed': speed,
        'estimatedRemaining': estimatedRemaining?.inMilliseconds,
      };

  factory ScanProgressInfo.fromJson(Map<String, dynamic> json) {
    return ScanProgressInfo(
      processed: json['processed'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      currentFile: json['currentFile'] as String?,
      phase: ScanPhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => ScanPhase.idle,
      ),
      speed: json['speed'] as double?,
      estimatedRemaining: json['estimatedRemaining'] != null
          ? Duration(milliseconds: json['estimatedRemaining'] as int)
          : null,
    );
  }
}

/// 扫描日志条目
class ScanLogEntry {
  /// 时间戳
  final DateTime timestamp;

  /// 日志级别
  final ScanLogLevel level;

  /// 消息
  final String message;

  /// 详细信息（可选）
  final String? details;

  const ScanLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'message': message,
        'details': details,
      };

  factory ScanLogEntry.fromJson(Map<String, dynamic> json) {
    return ScanLogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: ScanLogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => ScanLogLevel.info,
      ),
      message: json['message'] as String,
      details: json['details'] as String?,
    );
  }
}

/// 扫描日志级别
enum ScanLogLevel {
  debug,
  info,
  warning,
  error,
}

/// 扫描统计信息
class ScanStatistics {
  /// 扫描的文件总数
  final int filesScanned;

  /// 新增的文件数
  final int filesAdded;

  /// 更新的文件数
  final int filesUpdated;

  /// 删除的文件数
  final int filesDeleted;

  /// 跳过的文件数
  final int filesSkipped;

  /// 失败的文件数
  final int filesFailed;

  /// 扫描开始时间
  final DateTime? startTime;

  /// 扫描结束时间
  final DateTime? endTime;

  /// 扫描耗时
  Duration get duration {
    if (startTime == null) return Duration.zero;
    return (endTime ?? DateTime.now()).difference(startTime!);
  }

  const ScanStatistics({
    this.filesScanned = 0,
    this.filesAdded = 0,
    this.filesUpdated = 0,
    this.filesDeleted = 0,
    this.filesSkipped = 0,
    this.filesFailed = 0,
    this.startTime,
    this.endTime,
  });

  const ScanStatistics.initial()
      : filesScanned = 0,
        filesAdded = 0,
        filesUpdated = 0,
        filesDeleted = 0,
        filesSkipped = 0,
        filesFailed = 0,
        startTime = null,
        endTime = null;

  /// 复制并修改
  ScanStatistics copyWith({
    int? filesScanned,
    int? filesAdded,
    int? filesUpdated,
    int? filesDeleted,
    int? filesSkipped,
    int? filesFailed,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return ScanStatistics(
      filesScanned: filesScanned ?? this.filesScanned,
      filesAdded: filesAdded ?? this.filesAdded,
      filesUpdated: filesUpdated ?? this.filesUpdated,
      filesDeleted: filesDeleted ?? this.filesDeleted,
      filesSkipped: filesSkipped ?? this.filesSkipped,
      filesFailed: filesFailed ?? this.filesFailed,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'filesScanned': filesScanned,
        'filesAdded': filesAdded,
        'filesUpdated': filesUpdated,
        'filesDeleted': filesDeleted,
        'filesSkipped': filesSkipped,
        'filesFailed': filesFailed,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
      };

  factory ScanStatistics.fromJson(Map<String, dynamic> json) {
    return ScanStatistics(
      filesScanned: json['filesScanned'] as int? ?? 0,
      filesAdded: json['filesAdded'] as int? ?? 0,
      filesUpdated: json['filesUpdated'] as int? ?? 0,
      filesDeleted: json['filesDeleted'] as int? ?? 0,
      filesSkipped: json['filesSkipped'] as int? ?? 0,
      filesFailed: json['filesFailed'] as int? ?? 0,
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
    );
  }
}

/// 扫描检查点（用于断点续扫）
class ScanCheckpoint {
  /// 扫描根目录
  final String rootPath;

  /// 扫描类型
  final ScanType scanType;

  /// 已处理的文件路径列表
  final Set<String> processedPaths;

  /// 最后处理的文件路径
  final String? lastProcessedPath;

  /// 扫描统计
  final ScanStatistics statistics;

  /// 创建时间
  final DateTime createdAt;

  const ScanCheckpoint({
    required this.rootPath,
    required this.scanType,
    this.processedPaths = const {},
    this.lastProcessedPath,
    this.statistics = const ScanStatistics.initial(),
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'rootPath': rootPath,
        'scanType': scanType.name,
        'processedPaths': processedPaths.toList(),
        'lastProcessedPath': lastProcessedPath,
        'statistics': statistics.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScanCheckpoint.fromJson(Map<String, dynamic> json) {
    return ScanCheckpoint(
      rootPath: json['rootPath'] as String,
      scanType: ScanType.values.firstWhere(
        (e) => e.name == json['scanType'],
        orElse: () => ScanType.incremental,
      ),
      processedPaths: (json['processedPaths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
      lastProcessedPath: json['lastProcessedPath'] as String?,
      statistics: json['statistics'] != null
          ? ScanStatistics.fromJson(json['statistics'] as Map<String, dynamic>)
          : const ScanStatistics.initial(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 扫描状态管理器
///
/// 管理扫描状态、进度、日志和检查点
class ScanStateManager {
  static const String _hiveBoxName = 'scan_state';
  static const String _checkpointKey = 'scan_checkpoint';
  static const String _logsKey = 'scan_logs';
  static const int _maxLogEntries = 1000;

  static ScanStateManager? _instance;
  static ScanStateManager get instance => _instance ??= ScanStateManager._();

  Box<String>? _box;

  // 状态流
  final _statusController = StreamController<ScanStatus>.broadcast();
  final _progressController = StreamController<ScanProgressInfo>.broadcast();
  final _statisticsController = StreamController<ScanStatistics>.broadcast();
  final _logController = StreamController<ScanLogEntry>.broadcast();

  // 当前状态
  ScanStatus _status = ScanStatus.idle;
  ScanProgressInfo _progress = const ScanProgressInfo.initial();
  ScanStatistics _statistics = const ScanStatistics.initial();
  final List<ScanLogEntry> _logs = [];

  // 扫描控制
  bool _shouldPause = false;
  bool _shouldCancel = false;
  bool _isScanning = false;
  ScanType? _currentScanType;
  
  // 数据库统计（用于显示已有数据）
  int _existingInDatabase = 0;
  int _metadataCacheCount = 0;

  // 流订阅
  Stream<ScanStatus> get statusStream => _statusController.stream;
  Stream<ScanProgressInfo> get progressStream => _progressController.stream;
  Stream<ScanStatistics> get statisticsStream => _statisticsController.stream;
  Stream<ScanLogEntry> get logStream => _logController.stream;

  // 当前状态 getter
  ScanStatus get status => _status;
  ScanProgressInfo get progress => _progress;
  ScanStatistics get statistics => _statistics;
  List<ScanLogEntry> get logs => List.unmodifiable(_logs);
  bool get shouldPause => _shouldPause;
  bool get shouldCancel => _shouldCancel;
  bool get isScanning => _isScanning;
  int get existingInDatabase => _existingInDatabase;
  int get metadataCacheCount => _metadataCacheCount;
  
  /// 增加元数据缓存计数
  void incrementMetadataCacheCount() {
    _metadataCacheCount++;
  }
  
  /// 设置元数据缓存计数
  void setMetadataCacheCount(int count) {
    _metadataCacheCount = count;
    // 触发进度流更新，让UI刷新元数据计数
    _progressController.add(_progress);
  }

  ScanStateManager._();

  /// 初始化
  Future<void> initialize() async {
    if (_box != null) return;
    _box = await Hive.openBox<String>(_hiveBoxName);
    _loadLogs();
    AppLogger.i('ScanStateManager initialized', 'ScanStateManager');
  }

  /// 关闭
  Future<void> dispose() async {
    await _statusController.close();
    await _progressController.close();
    await _statisticsController.close();
    await _logController.close();
    await _box?.close();
    _box = null;
  }

  /// 开始扫描
  /// 
  /// [total] 预估的总文件数，用于进度显示
  /// [existingInDatabase] 数据库中已有的图片数量
  /// [metadataCacheCount] 元数据缓存数量
  bool startScan({
    ScanType? type,
    String? rootPath,
    int total = 0,
    int existingInDatabase = 0,
    int metadataCacheCount = 0,
  }) {
    // 防止并发扫描
    if (_isScanning) {
      logWarning('扫描已在进行中，忽略新的扫描请求');
      return false;
    }

    _isScanning = true;
    _currentScanType = type;
    _existingInDatabase = existingInDatabase;
    _metadataCacheCount = metadataCacheCount;
    _status = ScanStatus.scanning;
    _progress = ScanProgressInfo(total: total);
    _statistics = ScanStatistics(startTime: DateTime.now());
    _shouldPause = false;
    _shouldCancel = false;

    _statusController.add(_status);
    _progressController.add(_progress);
    _statisticsController.add(_statistics);

    logInfo('扫描开始', details: '类型: ${type?.name ?? "unknown"}, 路径: $rootPath, 总数: $total, 已有: $existingInDatabase, 有元数据: $_metadataCacheCount');
    return true;
  }

  /// 暂停扫描
  Future<void> pauseScan() async {
    if (!_status.canPause) return;
    _shouldPause = true;
    _status = ScanStatus.paused;
    _statusController.add(_status);
    logInfo('扫描已暂停');
  }

  /// 恢复扫描
  Future<void> resumeScan() async {
    if (!_status.canResume) return;
    _shouldPause = false;
    _status = ScanStatus.scanning;
    _statusController.add(_status);
    logInfo('扫描已恢复');
  }

  /// 取消扫描
  void cancelScan() {
    _shouldCancel = true;
    _isScanning = false;
    _status = ScanStatus.cancelled;
    _statusController.add(_status);
    logInfo('扫描已取消');
  }

  /// 完成扫描
  /// 
  /// 只清除与当前扫描类型匹配的检查点，避免不同类型扫描互相干扰
  void completeScan() {
    _isScanning = false;
    _status = ScanStatus.completed;
    _statistics = _statistics.copyWith(endTime: DateTime.now());
    _statusController.add(_status);
    _statisticsController.add(_statistics);
    logInfo(
        '扫描完成',
        details: '耗时: ${_statistics.duration.inSeconds}s, '
            '扫描: ${_statistics.filesScanned}, '
            '新增: ${_statistics.filesAdded}, '
            '更新: ${_statistics.filesUpdated}',);
    // 只清除与当前扫描类型匹配的检查点
    _clearCheckpointIfTypeMatches(_currentScanType);
    _currentScanType = null;
  }

  /// 扫描出错
  void errorScan(String error, {String? details}) {
    _isScanning = false;
    _status = ScanStatus.error;
    _statistics = _statistics.copyWith(endTime: DateTime.now());
    _statusController.add(_status);
    _statisticsController.add(_statistics);
    logError(error, details: details);
  }

  /// 更新进度
  void updateProgress({
    int? processed,
    int? total,
    String? currentFile,
    ScanPhase? phase,
    double? speed,
    Duration? estimatedRemaining,
  }) {
    _progress = _progress.copyWith(
      processed: processed,
      total: total,
      currentFile: currentFile,
      phase: phase,
      speed: speed,
      estimatedRemaining: estimatedRemaining,
    );
    _progressController.add(_progress);
  }

  /// 更新统计
  void updateStatistics({
    int? filesScanned,
    int? filesAdded,
    int? filesUpdated,
    int? filesDeleted,
    int? filesSkipped,
    int? filesFailed,
  }) {
    _statistics = _statistics.copyWith(
      filesScanned: filesScanned ?? _statistics.filesScanned,
      filesAdded: filesAdded ?? _statistics.filesAdded,
      filesUpdated: filesUpdated ?? _statistics.filesUpdated,
      filesDeleted: filesDeleted ?? _statistics.filesDeleted,
      filesSkipped: filesSkipped ?? _statistics.filesSkipped,
      filesFailed: filesFailed ?? _statistics.filesFailed,
    );
    _statisticsController.add(_statistics);
  }

  /// 增加统计值
  void incrementStatistics({
    int filesScanned = 0,
    int filesAdded = 0,
    int filesUpdated = 0,
    int filesDeleted = 0,
    int filesSkipped = 0,
    int filesFailed = 0,
  }) {
    updateStatistics(
      filesScanned: _statistics.filesScanned + filesScanned,
      filesAdded: _statistics.filesAdded + filesAdded,
      filesUpdated: _statistics.filesUpdated + filesUpdated,
      filesDeleted: _statistics.filesDeleted + filesDeleted,
      filesSkipped: _statistics.filesSkipped + filesSkipped,
      filesFailed: _statistics.filesFailed + filesFailed,
    );
  }

  /// 记录调试日志
  void logDebug(String message, {String? details}) {
    _addLog(ScanLogLevel.debug, message, details: details);
  }

  /// 记录信息日志
  void logInfo(String message, {String? details}) {
    _addLog(ScanLogLevel.info, message, details: details);
  }

  /// 记录警告日志
  void logWarning(String message, {String? details}) {
    _addLog(ScanLogLevel.warning, message, details: details);
  }

  /// 记录错误日志
  void logError(String message, {String? details}) {
    _addLog(ScanLogLevel.error, message, details: details);
  }

  void _addLog(ScanLogLevel level, String message, {String? details}) {
    final entry = ScanLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      details: details,
    );
    _logs.add(entry);
    _logController.add(entry);

    // 限制日志数量
    if (_logs.length > _maxLogEntries) {
      _logs.removeAt(0);
    }

    // 持久化日志
    _saveLogs();

    // 同时输出到应用日志
    switch (level) {
      case ScanLogLevel.debug:
        AppLogger.d('[Scan] $message', 'ScanStateManager');
        break;
      case ScanLogLevel.info:
        AppLogger.i('[Scan] $message', 'ScanStateManager');
        break;
      case ScanLogLevel.warning:
        AppLogger.w('[Scan] $message', 'ScanStateManager');
        break;
      case ScanLogLevel.error:
        AppLogger.e('[Scan] $message', details, null, 'ScanStateManager');
        break;
    }
  }

  /// 保存检查点（断点续扫）
  Future<void> saveCheckpoint(ScanCheckpoint checkpoint) async {
    try {
      await initialize(); // 确保已初始化
      await _box?.put(_checkpointKey, jsonEncode(checkpoint.toJson()));
      AppLogger.i('Checkpoint saved: ${checkpoint.processedPaths.length} files, type: ${checkpoint.scanType.name}', 'ScanStateManager');
    } catch (e) {
      AppLogger.w('Failed to save checkpoint: $e', 'ScanStateManager');
    }
  }

  /// 加载检查点
  Future<ScanCheckpoint?> loadCheckpoint() async {
    try {
      await initialize(); // 确保已初始化
      final json = _box?.get(_checkpointKey);
      if (json == null) return null;
      return ScanCheckpoint.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.w('Failed to load checkpoint: $e', 'ScanStateManager');
      return null;
    }
  }

  /// 清除检查点（私有）
  Future<void> _clearCheckpoint() async {
    try {
      await _box?.delete(_checkpointKey);
    } catch (e) {
      AppLogger.w('Failed to clear checkpoint: $e', 'ScanStateManager');
    }
  }

  /// 清除检查点（公共接口）
  Future<void> clearCheckpoint() async {
    await _clearCheckpoint();
  }

  /// 如果检查点类型匹配，则清除检查点
  /// 
  /// 用于避免不同类型扫描互相清除检查点
  Future<void> _clearCheckpointIfTypeMatches(ScanType? type) async {
    if (type == null) {
      await _clearCheckpoint();
      return;
    }
    try {
      final checkpoint = await loadCheckpoint();
      if (checkpoint != null && checkpoint.scanType == type) {
        await _box?.delete(_checkpointKey);
        AppLogger.d('Cleared checkpoint for scan type: ${type.name}', 'ScanStateManager');
      }
    } catch (e) {
      AppLogger.w('Failed to clear checkpoint by type: $e', 'ScanStateManager');
    }
  }

  /// 保存日志到 Hive
  Future<void> _saveLogs() async {
    try {
      final logsJson = jsonEncode(_logs.map((e) => e.toJson()).toList());
      await _box?.put(_logsKey, logsJson);
    } catch (e) {
      AppLogger.w('Failed to save logs: $e', 'ScanStateManager');
    }
  }

  /// 从 Hive 加载日志
  void _loadLogs() {
    try {
      final json = _box?.get(_logsKey);
      if (json == null) return;

      final list = jsonDecode(json) as List<dynamic>;
      _logs.clear();
      _logs.addAll(
        list.map((e) => ScanLogEntry.fromJson(e as Map<String, dynamic>)),
      );

      // 只保留最近的日志
      if (_logs.length > _maxLogEntries) {
        _logs.removeRange(0, _logs.length - _maxLogEntries);
      }
    } catch (e) {
      AppLogger.w('Failed to load logs: $e', 'ScanStateManager');
    }
  }

  /// 清除所有日志
  Future<void> clearLogs() async {
    _logs.clear();
    await _box?.delete(_logsKey);
    logInfo('日志已清除');
  }

  /// 获取最近扫描的检查点目录
  Future<String?> getResumableDirectory() async {
    final checkpoint = await loadCheckpoint();
    if (checkpoint == null) return null;

    // 检查目录是否仍然存在
    final dir = Directory(checkpoint.rootPath);
    if (!dir.existsSync()) return null;

    // 检查检查点是否过期（超过24小时）
    final age = DateTime.now().difference(checkpoint.createdAt);
    if (age > const Duration(hours: 24)) return null;

    return checkpoint.rootPath;
  }

  /// 等待恢复信号
  Future<void> waitForResume() async {
    while (_shouldPause && !_shouldCancel) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// 检查是否应该暂停
  Future<void> checkPause() async {
    if (_shouldPause) {
      await waitForResume();
    }
  }
}

/// 统一的进度回调类型定义
typedef UnifiedScanProgressCallback = void Function(ScanProgressInfo progress);

/// 进度回调转换器
///
/// 将旧的回调格式转换为新的统一格式
ScanProgressCallback adaptProgressCallback(UnifiedScanProgressCallback? callback) {
  return ({
    required int processed,
    required int total,
    String? currentFile,
    required String phase,
    int? filesSkipped,  // 新增：传递跳过的文件数
  }) {
    callback?.call(ScanProgressInfo(
      processed: processed,
      total: total,
      currentFile: currentFile,
      phase: _adaptPhase(phase),
    ),);
  };
}

/// 阶段字符串转枚举
ScanPhase _adaptPhase(String phase) {
  return ScanPhase.values.firstWhere(
    (e) => e.name == phase,
    orElse: () => ScanPhase.scanning,
  );
}

/// 旧的进度回调类型（保持兼容）
/// 
/// 改进：添加 filesSkipped 参数，让UI可以显示包含跳过文件的总进度
typedef ScanProgressCallback = void Function({
  required int processed,
  required int total,
  String? currentFile,
  required String phase,
  int? filesSkipped,  // 新增：跳过的文件数
});
