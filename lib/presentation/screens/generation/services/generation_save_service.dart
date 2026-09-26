import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/system_gallery_publisher.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/image_save_settings_provider.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/gallery_save_feedback.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';
import 'generation_result_saver.dart';

/// 生成页各保存入口的界面流程：卡片、批量与详情页共用同一套落盘与提示。
class GenerationSaveService {
  GenerationSaveService._();

  /// 保存期间宿主组件可能被卸载，句柄必须在第一个 await 之前取好。
  static GenerationResultSaver saverFor(WidgetRef ref) {
    final generation = ref.read(imageGenerationNotifierProvider.notifier);
    final gallery = ref.read(localGalleryNotifierProvider.notifier);
    return GenerationResultSaver(
      resolveGalleryRootPath: GalleryFolderRepository.instance.getRootPath,
      systemGallery: ref.read(systemGalleryPublisherProvider),
      recordSavedPath: generation.updateImageFilePath,
      addGalleryImages: gallery.addNewlySavedImages,
      refreshGallery: gallery.refresh,
    );
  }

  /// 卡片持有的是构建时的快照，自动保存可能已在之后写入路径。
  static GenerationResultSaveRequest requestFor(
    WidgetRef ref,
    GeneratedImage image,
  ) => GenerationResultSaveRequest.fromImage(
    ref.read(imageGenerationNotifierProvider).findImageById(image.id) ?? image,
  );

  static Future<void> saveImageFromDetail(
    BuildContext context,
    WidgetRef ref,
    ImageDetailData image,
  ) async {
    final saver = saverFor(ref);
    final savedPath = ref
        .read(imageGenerationNotifierProvider)
        .findImageById(image.identifier)
        ?.filePath;
    await _saveWithFeedback(
      context,
      saver,
      () async => [
        await GenerationResultSaveRequest.fromDetail(
          image,
          savedPath: savedPath,
        ),
      ],
    );
  }

  /// 卡片与批量保存共用；全部成功才返回 true。
  static Future<bool> saveImages(
    BuildContext context,
    WidgetRef ref,
    List<GeneratedImage> images,
  ) async {
    if (images.isEmpty) return false;
    final saver = saverFor(ref);
    final requests = [for (final image in images) requestFor(ref, image)];
    return _saveWithFeedback(context, saver, () async => requests);
  }

  static Future<bool> _saveWithFeedback(
    BuildContext context,
    GenerationResultSaver saver,
    Future<List<GenerationResultSaveRequest>> Function() buildRequests,
  ) async {
    final GenerationResultSaveReport? report;
    try {
      report = await saver.saveAll(await buildRequests());
    } catch (e) {
      if (context.mounted) _showFailure(context, e);
      return false;
    }
    if (context.mounted) showSaveReport(context, report);
    return report?.isComplete ?? false;
  }

  /// 只在本次新写入文件时提示；复用已有文件时不打扰。
  static void showNewlySavedFeedback(
    BuildContext context,
    GenerationResultFile file,
  ) {
    if (file is! GenerationResultNewlySaved) return;
    showGallerySaveFeedback(
      context,
      file.systemGalleryOutcome,
      appGalleryMessage: context.l10n.image_imageSaved(file.rootPath),
    );
  }

  /// 调用方已有自己的成功提示时，只补报新文件没能进系统相册。
  static void showSystemGalleryFailure(
    BuildContext context,
    GenerationResultFile file,
  ) {
    if (file case GenerationResultNewlySaved(
      systemGalleryOutcome: SystemGalleryPublishFailed(:final error),
    )) {
      AppToast.warning(
        context,
        context.l10n.image_savedAppOnly(error.toString()),
      );
    }
  }

  /// [report] 为 null 表示图库根目录未设置，什么都没保存。
  static void showSaveReport(
    BuildContext context,
    GenerationResultSaveReport? report,
  ) {
    final l10n = context.l10n;
    if (report == null) {
      AppToast.error(context, l10n.toast_saveDirNotSet);
      return;
    }
    if (report.failures case [final failure, ...]) {
      _showFailure(context, failure.error);
      return;
    }
    final appGalleryMessage = l10n.image_imageSaved(report.rootPath);
    final outcome = report.systemGalleryOutcome;
    if (outcome == null) {
      AppToast.success(context, appGalleryMessage);
      return;
    }
    showGallerySaveFeedback(
      context,
      outcome,
      appGalleryMessage: appGalleryMessage,
    );
  }

  static void _showFailure(BuildContext context, Object error) {
    AppToast.error(context, context.l10n.image_saveFailed(error.toString()));
  }
}
