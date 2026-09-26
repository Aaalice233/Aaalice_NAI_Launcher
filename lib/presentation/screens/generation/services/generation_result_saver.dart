import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../../core/services/system_gallery_publisher.dart';
import '../../../../core/utils/image_save_utils.dart';
import '../../../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../../../../data/models/gallery/gallery_index_admission.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../providers/generation/generation_models.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';

/// 一条生成结果落盘所需的数据，全部取自图像自身。
class GenerationResultSaveRequest {
  const GenerationResultSaveRequest({
    required this.imageId,
    required this.bytes,
    required this.preserveOriginalBytes,
    this.metadata,
    this.fixedTagUsageSnapshot,
    this.savedPath,
  });

  factory GenerationResultSaveRequest.fromImage(GeneratedImage image) =>
      GenerationResultSaveRequest(
        imageId: image.id,
        bytes: image.bytes,
        preserveOriginalBytes: image.preserveOriginalBytesOnSave,
        metadata: image.metadata,
        fixedTagUsageSnapshot: image.fixedTagUsageSnapshot,
        savedPath: image.filePath,
      );

  static Future<GenerationResultSaveRequest> fromDetail(
    ImageDetailData detail, {
    String? savedPath,
  }) async => GenerationResultSaveRequest(
    imageId: detail.identifier,
    bytes: await detail.getImageBytes(),
    preserveOriginalBytes: detail.preserveOriginalBytesOnSave,
    metadata: detail.metadata,
    fixedTagUsageSnapshot: detail is GeneratedImageDetailData
        ? detail.fixedTagUsageSnapshot
        : null,
    savedPath: savedPath,
  );

  final String imageId;
  final Uint8List bytes;
  final bool preserveOriginalBytes;
  final NaiImageMetadata? metadata;
  final FixedTagUsageSnapshot? fixedTagUsageSnapshot;

  /// 这条结果此前记录的文件路径。
  final String? savedPath;
}

/// 一条生成结果在图库里对应的文件。
sealed class GenerationResultFile {
  const GenerationResultFile({required this.rootPath});

  final String rootPath;

  String get path;
}

/// 本次新写入图库。
final class GenerationResultNewlySaved extends GenerationResultFile {
  const GenerationResultNewlySaved({
    required super.rootPath,
    required this.saved,
    required this.systemGalleryOutcome,
  });

  final SavedResultImage saved;
  final SystemGalleryPublishOutcome systemGalleryOutcome;

  @override
  String get path => saved.path;
}

/// 已在当前图库里，没有重复落盘。
final class GenerationResultAlreadySaved extends GenerationResultFile {
  const GenerationResultAlreadySaved({
    required super.rootPath,
    required this.path,
  });

  @override
  final String path;
}

typedef GenerationResultSaveFailure = ({
  String imageId,
  Object error,
  StackTrace stackTrace,
});

/// 一次保存操作的汇总；成功项按请求顺序排列。
class GenerationResultSaveReport {
  const GenerationResultSaveReport({
    required this.rootPath,
    required this.files,
    required this.failures,
  });

  final String rootPath;
  final List<GenerationResultFile> files;
  final List<GenerationResultSaveFailure> failures;

  bool get isComplete => failures.isEmpty;

  /// 只汇总本次新写入的文件：任一失败即失败，否则取最后一次结果。
  SystemGalleryPublishOutcome? get systemGalleryOutcome {
    SystemGalleryPublishOutcome? outcome;
    for (final file in files) {
      if (file is! GenerationResultNewlySaved) continue;
      if (outcome is SystemGalleryPublishFailed) break;
      outcome = file.systemGalleryOutcome;
    }
    return outcome;
  }
}

/// 生成结果的手动落盘：卡片、批量、详情页，以及收藏/定位前的补存共用。
///
/// 只认图像自身元数据；已在当前图库里的结果复用原文件，新文件把路径记回生成结果。
class GenerationResultSaver {
  const GenerationResultSaver({
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

  /// 单张保存，失败直接抛出；图库根目录未设置时返回 null，不落盘。
  Future<GenerationResultFile?> save(
    GenerationResultSaveRequest request,
  ) async {
    final report = await saveAll([request]);
    if (report == null) return null;
    if (report.failures case [final failure, ...]) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return report.files.single;
  }

  /// 单张失败不阻断其余；新文件合并成一次图库索引收录。
  ///
  /// 图库根目录未设置时返回 null，不落盘。
  Future<GenerationResultSaveReport?> saveAll(
    List<GenerationResultSaveRequest> requests,
  ) async {
    final rootPath = await resolveGalleryRootPath();
    if (rootPath == null || rootPath.isEmpty) return null;

    final files = <GenerationResultFile>[];
    final failures = <GenerationResultSaveFailure>[];
    for (final request in requests) {
      try {
        files.add(await _saveOne(rootPath, request));
      } catch (error, stackTrace) {
        failures.add((
          imageId: request.imageId,
          error: error,
          stackTrace: stackTrace,
        ));
      }
    }

    final newPaths = [
      for (final file in files)
        if (file is GenerationResultNewlySaved) file.path,
    ];
    if (newPaths.isNotEmpty) {
      final admission = await addGalleryImages(newPaths);
      if (admission.requiresFullRescan) await refreshGallery();
    }
    return GenerationResultSaveReport(
      rootPath: rootPath,
      files: files,
      failures: failures,
    );
  }

  Future<GenerationResultFile> _saveOne(
    String rootPath,
    GenerationResultSaveRequest request,
  ) async {
    final existing = await _reusablePath(rootPath, request.savedPath);
    if (existing != null) {
      return GenerationResultAlreadySaved(rootPath: rootPath, path: existing);
    }

    final saved = await ImageSaveUtils.saveResultImage(
      rootPath: rootPath,
      imageBytes: request.bytes,
      preserveOriginalBytes: request.preserveOriginalBytes,
      metadata: request.metadata,
      fixedTagUsageSnapshot: request.fixedTagUsageSnapshot,
    );
    recordSavedPath(request.imageId, saved.path);
    final systemGalleryOutcome = await systemGallery.publishPng(
      bytes: saved.bytes,
      fileName: p.basename(saved.path),
    );
    return GenerationResultNewlySaved(
      rootPath: rootPath,
      saved: saved,
      systemGalleryOutcome: systemGalleryOutcome,
    );
  }

  // 换过图库根目录后，旧文件不在当前图库里，要重新落一份。
  static Future<String?> _reusablePath(String rootPath, String? path) async {
    if (path == null || path.isEmpty || !p.isWithin(rootPath, path)) {
      return null;
    }
    return await File(path).exists() ? path : null;
  }
}
