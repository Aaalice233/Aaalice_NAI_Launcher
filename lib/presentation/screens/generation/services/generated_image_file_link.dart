import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/image_save_utils.dart';
import '../../../../data/repositories/gallery_folder_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/local_gallery_provider.dart';

/// [newlySavedRoot] 仅在本次新写入文件时给出图库根目录。
typedef LinkedGeneratedImageFile = ({String path, String? newlySavedRoot});

/// 需要一个真实文件的操作（收藏、定位文件夹）共用的保存入口。
///
/// 保存后把路径记回这条生成结果：重复操作复用同一个文件，删除历史时也能连带删除它。
class GeneratedImageFileLink {
  const GeneratedImageFileLink._();

  static Future<LinkedGeneratedImageFile> ensureSaved(
    WidgetRef ref,
    GeneratedImage image,
    AppLocalizations l10n,
  ) async {
    // 保存期间卡片可能被卸载，句柄必须在第一个 await 之前取好。
    final generation = ref.read(imageGenerationNotifierProvider.notifier);
    final gallery = ref.read(localGalleryNotifierProvider.notifier);
    // 卡片持有的是构建时的快照，自动保存可能已在之后写入路径。
    final current =
        ref.read(imageGenerationNotifierProvider).findImageById(image.id) ??
        image;
    final existingPath = current.filePath;
    if (existingPath != null &&
        existingPath.isNotEmpty &&
        await File(existingPath).exists()) {
      return (path: existingPath, newlySavedRoot: null);
    }

    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw StateError(l10n.localGallery_saveDirectoryNotSet);
    }

    final filePath = await ImageSaveUtils.saveBytesToDatedPath(
      rootPath: rootPath,
      bytes: current.bytes,
      seed: await ImageSaveUtils.resolveSeed(
        metadata: current.metadata,
        bytes: current.bytes,
      ),
    );
    generation.updateImageFilePath(current.id, filePath);
    await gallery.addNewlySavedImages([filePath]);
    return (path: filePath, newlySavedRoot: rootPath);
  }
}
