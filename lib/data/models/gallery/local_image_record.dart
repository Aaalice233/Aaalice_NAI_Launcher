import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import '../vibe/vibe_reference.dart';
import 'nai_image_metadata.dart';

part 'local_image_record.freezed.dart';
part 'local_image_record.g.dart';

/// 元数据解析状态
enum MetadataStatus {
  success, // 解析成功
  failed, // 解析失败
  none, // 未解析
}

/// 本地图片记录模型
@HiveType(typeId: 22)
@freezed
class LocalImageRecord with _$LocalImageRecord {
  const factory LocalImageRecord({
    @HiveField(0) required String path, // 文件路径
    @HiveField(1) required int size, // 文件大小（字节）
    @HiveField(2) required DateTime modifiedAt, // 最后修改时间
    @HiveField(3) NaiImageMetadata? metadata, // NAI 隐写元数据（Prompt/Seed等）
    @HiveField(4)
    @Default(MetadataStatus.none)
    MetadataStatus metadataStatus, // 元数据状态
    @HiveField(5) @Default(false) bool isFavorite, // 是否收藏
    @HiveField(6) @Default([]) List<String> tags, // 标签列表
    @HiveField(7) VibeReference? vibeData, // Vibe 参考数据
    @HiveField(8) @Default(false) bool hasVibeMetadata, // 是否有 Vibe 元数据
  }) = _LocalImageRecord;

  const LocalImageRecord._();

  /// 是否有有效元数据
  bool get hasMetadata => metadata != null && metadata!.hasData;
}
