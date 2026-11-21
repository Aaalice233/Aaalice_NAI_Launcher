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
