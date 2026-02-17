import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'backup_metadata.freezed.dart';
part 'backup_metadata.g.dart';

/// 备份状态
enum BackupStatus {
  /// 备份中
  inProgress,

  /// 已完成
  completed,

  /// 失败
  failed,
}

/// 备份元数据模型
///
/// 用于跟踪备份操作的状态和元数据
@freezed
class BackupMetadata with _$BackupMetadata {
  const BackupMetadata._();

  const factory BackupMetadata({
    /// 唯一标识符 (UUID)
    required String id,

    /// 备份名称
    required String name,

    /// 备份状态
    @Default(BackupStatus.inProgress) BackupStatus status,

    /// 备份文件路径
    required String filePath,

    /// 备份文件大小（字节）
    required int fileSize,

    /// 创建时间
    required DateTime createdAt,

    /// 完成时间
    DateTime? completedAt,

    /// 错误信息（当状态为 failed 时）
    String? errorMessage,
  }) = _BackupMetadata;

  /// 创建新的备份元数据
  factory BackupMetadata.create({
    required String name,
    required String filePath,
    required int fileSize,
  }) {
    return BackupMetadata(
      id: const Uuid().v4(),
      name: name,
      filePath: filePath,
      fileSize: fileSize,
      createdAt: DateTime.now(),
    );
  }

  factory BackupMetadata.fromJson(Map<String, dynamic> json) =>
      _$BackupMetadataFromJson(json);

  /// 是否已完成
  bool get isCompleted => status == BackupStatus.completed;

  /// 是否失败
  bool get isFailed => status == BackupStatus.failed;

  /// 是否进行中
  bool get isInProgress => status == BackupStatus.inProgress;
}

/// 备份元数据列表 wrapper（用于 Hive JSON 存储）
@freezed
class BackupMetadataList with _$BackupMetadataList {
  const factory BackupMetadataList({
    @Default([]) List<BackupMetadata> backups,
  }) = _BackupMetadataList;

  factory BackupMetadataList.fromJson(Map<String, dynamic> json) =>
      _$BackupMetadataListFromJson(json);
}
