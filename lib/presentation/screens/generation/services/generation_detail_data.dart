import '../../../../data/services/image_metadata_service.dart';
import '../../../providers/generation/generation_models.dart';
import '../../../widgets/common/image_detail/file_image_detail_data.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';

/// 生成页各入口（预览、历史）打开详情页共用的数据适配。
class GenerationDetailData {
  GenerationDetailData._();

  /// 已保存的图从文件解析元数据；未保存的图（关闭自动保存时）用内存字节兜底。
  static ImageDetailData forImage(GeneratedImage image) {
    final filePath = image.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      ImageMetadataService().enqueuePreload(
        taskId: image.id,
        filePath: filePath,
      );
      return FileImageDetailData(
        filePath: filePath,
        cachedBytes: image.bytes,
        id: image.id,
        initialMetadata: image.metadata,
        showCopyButton: image.canSave,
        showSaveAsButton: image.canSave,
      );
    }
    return GeneratedImageDetailData(
      imageBytes: image.bytes,
      metadata: image.metadata,
      id: image.id,
      showSaveButton: image.canSave,
      showCopyButton: image.canSave,
      showSaveAsButton: image.canSave,
      preserveOriginalBytesOnSave: image.preserveOriginalBytesOnSave,
      fixedTagUsageSnapshot: image.fixedTagUsageSnapshot,
    );
  }
}
