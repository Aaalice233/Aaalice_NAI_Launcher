import 'package:path/path.dart' as p;

import '../../../../core/services/system_gallery_publisher.dart';
import '../../../../core/utils/image_save_utils.dart';
import '../../../../data/models/gallery/gallery_index_admission.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';

typedef GenerationDetailSaveResult = ({
  String rootPath,
  SavedResultImage saved,
  SystemGalleryPublishOutcome systemGalleryOutcome,
});

/// 生成页详情查看器的落盘流程：只认图像自身元数据，保存后把路径记回生成结果。
class GenerationDetailSaver {
  const GenerationDetailSaver({
    required this.resolveGalleryRootPath,
    required this.systemGallery,
    required this.recordSavedPath,
    required this.addGalleryImages,
    required this.refreshGallery,
  });

  final Future<String?> Function() resolveGalleryRootPath;
  final SystemGalleryPublisher systemGallery;
  final void Function(String imageId, String path) recordSavedPath;
  final Future<GalleryIndexAdmission> Function(List<String> paths)
  addGalleryImages;
  final Future<void> Function() refreshGallery;

  /// 图库根目录未设置时返回 null，不落盘。
  Future<GenerationDetailSaveResult?> save(ImageDetailData image) async {
    final imageBytes = await image.getImageBytes();
    final rootPath = await resolveGalleryRootPath();
    if (rootPath == null) return null;

    final saved = await ImageSaveUtils.saveResultImage(
      rootPath: rootPath,
      imageBytes: imageBytes,
      preserveOriginalBytes: image.preserveOriginalBytesOnSave,
      metadata: image.metadata,
      fixedTagUsageSnapshot: image is GeneratedImageDetailData
          ? image.fixedTagUsageSnapshot
          : null,
    );
    recordSavedPath(image.identifier, saved.path);

    final systemGalleryOutcome = await systemGallery.publishPng(
      bytes: saved.bytes,
      fileName: p.basename(saved.path),
    );
    final admission = await addGalleryImages([saved.path]);
    if (admission.requiresFullRescan) await refreshGallery();
    return (
      rootPath: rootPath,
      saved: saved,
      systemGalleryOutcome: systemGalleryOutcome,
    );
  }
}
