import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/services/android_media_store_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/image_save_utils.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../../data/services/image_metadata_service.dart';
import '../../../providers/generation/generation_models.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../utils/image_detail_opener.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/image_detail/file_image_detail_data.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';
import '../../../widgets/common/image_detail/image_detail_viewer.dart';

/// 图像保存服务类
///
/// 负责处理图像保存、全屏预览等功能
/// 从 desktop_layout.dart 中提取，减少文件职责
class GenerationSaveService {
  GenerationSaveService._();

  /// 显示全屏预览
  ///
  /// 简化逻辑：统一使用 FileImageDetailData 从 PNG 文件解析元数据
  /// - 如果图像已保存（有 filePath），直接使用
  /// - 如果图像未保存，先保存到磁盘再使用
  /// - 元数据异步加载，详情页先显示，解析中显示转圈
  static void showFullscreenPreview(
    BuildContext context,
    WidgetRef ref,
    List<GeneratedImage> images,
  ) {
    // 立即构建基础数据（使用 FileImageDetailData 从文件解析）
    final allImages = images.map((img) {
      // 如果图像已保存，直接使用 filePath
      // 如果未保存，使用临时字节（这种情况在 auto-save 开启时应该很少）
      if (img.filePath != null && img.filePath!.isNotEmpty) {
        // 加入预加载队列（如果尚未解析）
        ImageMetadataService().enqueuePreload(
          taskId: img.id,
          filePath: img.filePath,
        );
        return FileImageDetailData(
          filePath: img.filePath!,
          cachedBytes: img.bytes,
          id: img.id,
          initialMetadata: img.metadata,
          showCopyButton: img.canSave,
        );
      }

      // 未保存的图像：使用 GeneratedImageDetailData 作为 fallback
      // 这种情况只应在 auto-save 关闭且用户未手动保存时发生
      return GeneratedImageDetailData(
        imageBytes: img.bytes,
        metadata: img.metadata,
        id: img.id,
        showSaveButton: img.canSave,
        showCopyButton: img.canSave,
        preserveOriginalBytesOnSave: img.preserveOriginalBytesOnSave,
        fixedTagUsageSnapshot: img.fixedTagUsageSnapshot,
      );
    }).toList();

    // 使用 ImageDetailOpener 打开详情页（带防重复点击）
    // 使用 'generation_desktop' key 避免与本地图库的 'default' key 冲突
    ImageDetailOpener.showMultipleImmediate(
      context,
      images: allImages,
      initialIndex: 0,
      showMetadataPanel: true,
      showThumbnails: allImages.length > 1,
      callbacks: ImageDetailCallbacks(
        onSave: (image) async {
          if (!image.showSaveButton) return;
          await saveImageFromDetail(context, ref, image);
        },
      ),
    );
  }

  /// 从详情页保存图像
  ///
  /// 使用 [ImageSaveUtils] 确保元数据完整嵌入
  static Future<void> saveImageFromDetail(
    BuildContext context,
    WidgetRef ref,
    ImageDetailData image,
  ) async {
    try {
      final imageBytes = await image.getImageBytes();
      final saveDirPath = await GalleryFolderRepository.instance.getRootPath();
      if (saveDirPath == null) return;

      // 获取已有元数据（如果图像已包含）
      final existingMetadata = image.metadata;
      final fixedTagUsageSnapshot = image is GeneratedImageDetailData
          ? image.fixedTagUsageSnapshot
          : existingMetadata?.fixedTagUsageSnapshot;
      // 构建最终字节：明确要求保留原始字节的外部结果不做补写；
      // 其他图像优先保留已有 NAI 元数据，缺失时再用已解析数据重建。
      var finalBytes = imageBytes;
      final hasEmbeddedMetadata = ImageSaveUtils.hasEmbeddedNovelAiMetadata(
        imageBytes,
      );
      if (!image.preserveOriginalBytesOnSave &&
          hasEmbeddedMetadata &&
          fixedTagUsageSnapshot != null) {
        finalBytes = await ImageSaveUtils.mergeFixedTagUsageMetadata(
          imageBytes: imageBytes,
          snapshot: fixedTagUsageSnapshot,
        );
      } else if (!image.preserveOriginalBytesOnSave &&
          !hasEmbeddedMetadata &&
          existingMetadata != null) {
        finalBytes = await ImageSaveUtils.buildPrebuiltMetadataBytes(
          imageBytes: imageBytes,
          metadata: {
            'Description': existingMetadata.prompt,
            'Software': 'NovelAI',
            'Source': existingMetadata.source ?? 'NovelAI Diffusion',
            'Comment': jsonEncode(
              buildCommentJsonFromMetadata(
                existingMetadata,
                fixedTagUsageSnapshot: fixedTagUsageSnapshot,
              ),
            ),
          },
        );
      }

      // 原子保存：日期分类路径 + 独占防冲突 + 失败清理，全部在工具内完成
      final filePath = await ImageSaveUtils.saveBytesToDatedPath(
        rootPath: saveDirPath,
        bytes: finalBytes,
        seed: await ImageSaveUtils.resolveSeed(
          metadata: existingMetadata,
          bytes: imageBytes,
        ),
      );

      Object? systemGalleryError;
      if (PlatformCapabilities.current.supportsSystemGalleryExport) {
        try {
          await AndroidMediaStoreService.savePng(
            bytes: finalBytes,
            fileName: p.basename(filePath),
          );
        } catch (error) {
          systemGalleryError = error;
        }
      }

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      if (context.mounted) {
        if (systemGalleryError != null) {
          AppToast.warning(
            context,
            context.l10n.image_savedAppOnly(systemGalleryError.toString()),
          );
        } else {
          AppToast.success(
            context,
            PlatformCapabilities.current.supportsSystemGalleryExport
                ? context.l10n.image_savedToSystemGallery
                : context.l10n.image_imageSaved(saveDirPath),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  /// 从元数据构建 Comment JSON
  static Map<String, dynamic> buildCommentJsonFromMetadata(
    NaiImageMetadata metadata, {
    FixedTagUsageSnapshot? fixedTagUsageSnapshot,
  }) {
    final commentJson = <String, dynamic>{
      'prompt': metadata.prompt,
      'uc': metadata.negativePrompt,
      'seed': metadata.seed ?? -1,
      'steps': metadata.steps ?? 28,
      'width': metadata.width ?? 832,
      'height': metadata.height ?? 1216,
      'scale': metadata.scale ?? 5.0,
      'uncond_scale': 0.0,
      'cfg_rescale': metadata.cfgRescale ?? 0.0,
      'n_samples': 1,
      'noise_schedule': metadata.noiseSchedule ?? 'native',
      'sampler': metadata.sampler ?? 'k_euler_ancestral',
      'sm': metadata.smea ?? false,
      'sm_dyn': metadata.smeaDyn ?? false,
      if (fixedTagUsageSnapshot != null)
        'aaalice_fixed_tags': fixedTagUsageSnapshot.toJson(),
      if (fixedTagUsageSnapshot != null ||
          metadata.hasRecordedFixedTagFields) ...{
        'fixed_prefix': metadata.fixedPrefixTags,
        'fixed_suffix': metadata.fixedSuffixTags,
        'fixed_negative_prefix': metadata.fixedNegativePrefixTags,
        'fixed_negative_suffix': metadata.fixedNegativeSuffixTags,
      },
    };

    // 添加 Vibe 数据
    if (metadata.vibeReferences.isNotEmpty) {
      commentJson['reference_image_multiple'] = metadata.vibeReferences
          .where((v) => v.vibeEncoding.isNotEmpty)
          .map((v) => v.vibeEncoding)
          .toList();
      commentJson['reference_strength_multiple'] = metadata.vibeReferences
          .map((v) => v.strength)
          .toList();
      commentJson['reference_information_extracted_multiple'] = metadata
          .vibeReferences
          .map((v) => v.infoExtracted)
          .toList();
    }

    return commentJson;
  }
}
