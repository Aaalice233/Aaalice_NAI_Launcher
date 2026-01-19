import 'package:freezed_annotation/freezed_annotation.dart';

import 'nai_image_metadata.dart';

part 'local_image_record.freezed.dart';

/// 元数据解析状态
enum MetadataStatus {
  success,  // 解析成功
  failed,   // 解析失败
  none,     // 未解析
}

/// 本地图片记录模型
@freezed
class LocalImageRecord with _$LocalImageRecord {
  const factory LocalImageRecord({
    required String path,           // 文件路径
    required int size,               // 文件大小（字节）
    required DateTime modifiedAt,    // 最后修改时间
    NaiImageMetadata? metadata,      // NAI 隐写元数据（Prompt/Seed等）
    @Default(MetadataStatus.none) MetadataStatus metadataStatus, // 元数据状态
  }) = _LocalImageRecord;

  const LocalImageRecord._();

  /// 是否有有效元数据
  bool get hasMetadata => metadata != null && metadata!.hasData;
}
