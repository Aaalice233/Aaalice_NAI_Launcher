import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/image_save_settings_provider.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/gallery_save_feedback.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';
import 'generation_detail_saver.dart';

/// 生成页详情查看器的保存入口，预览区与历史栏共用。
class GenerationSaveService {
  GenerationSaveService._();

  static Future<void> saveImageFromDetail(
    BuildContext context,
    WidgetRef ref,
    ImageDetailData image,
  ) async {
    // 保存期间宿主组件可能被卸载，句柄必须在第一个 await 之前取好。
    final generation = ref.read(imageGenerationNotifierProvider.notifier);
    final gallery = ref.read(localGalleryNotifierProvider.notifier);
    final saver = GenerationDetailSaver(
      resolveGalleryRootPath: GalleryFolderRepository.instance.getRootPath,
      systemGallery: ref.read(systemGalleryPublisherProvider),
      recordSavedPath: generation.updateImageFilePath,
      addGalleryImages: gallery.addNewlySavedImages,
      refreshGallery: gallery.refresh,
    );
    try {
      final result = await saver.save(image);
      if (result == null || !context.mounted) return;
      showGallerySaveFeedback(
        context,
        result.systemGalleryOutcome,
        appGalleryMessage: context.l10n.image_imageSaved(result.rootPath),
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }
}
