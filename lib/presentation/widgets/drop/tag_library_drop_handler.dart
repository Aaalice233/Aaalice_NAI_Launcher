import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_metadata_parser.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../screens/tag_library_page/widgets/entry_add_dialog.dart';
import '../../screens/tag_library_page/widgets/entry_selector_dialog.dart';
import '../../screens/tag_library_page/widgets/tag_library_drop_menu.dart';
import '../common/app_toast.dart';

/// 词库拖拽处理器
///
/// 处理拖入词库页面的图片文件，支持创建新条目或更新现有条目预览图
class TagLibraryDropHandler {
  /// 处理拖入词库的图片
  ///
  /// [context] BuildContext 用于显示对话框
  /// [ref] WidgetRef 用于访问 Provider
  /// [fileName] 拖入的文件名
  /// [bytes] 图片字节数据
  static Future<void> handle({
    required BuildContext context,
    required WidgetRef ref,
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      // 解析图片元数据（此步骤不涉及 context）
      final metadata = await NaiMetadataParser.extractFromBytes(bytes);
      final prompt = metadata?.prompt ?? '';

      // 显示操作选择菜单
      final action = await _showMenu(
        // ignore: use_build_context_synchronously
        context: context,
        fileName: fileName,
        prompt: prompt,
      );

      if (action == null) return;

      switch (action) {
        case TagLibraryDropAction.create:
          await _handleCreateEntry(
            // ignore: use_build_context_synchronously
            context: context,
            ref: ref,
            fileName: fileName,
            bytes: bytes,
            metadata: metadata,
          );
          break;
        case TagLibraryDropAction.updateThumbnail:
          await _handleUpdateThumbnail(
            // ignore: use_build_context_synchronously
            context: context,
            ref: ref,
            bytes: bytes,
          );
          break;
        case TagLibraryDropAction.cancel:
          // 用户取消，不做任何操作
          break;
      }
    } catch (e, stack) {
      AppLogger.e('处理词库拖拽失败', e, stack, 'TagLibraryDropHandler');
      // ignore: use_build_context_synchronously
      await _showError(context, '处理图片失败: $e');
    }
  }

  /// 显示菜单对话框（抽取为单独方法以正确处理 context）
  static Future<TagLibraryDropAction?> _showMenu({
    required BuildContext context,
    required String fileName,
    required String prompt,
  }) async {
    return TagLibraryDropMenu.show(
      context,
      fileName: fileName,
      prompt: prompt,
    );
  }

  /// 显示错误提示
  static Future<void> _showError(BuildContext context, String message) async {
    if (!context.mounted) return;
    AppToast.error(context, message);
  }

  /// 处理创建新条目
  static Future<void> _handleCreateEntry({
    required BuildContext context,
    required WidgetRef ref,
    required String fileName,
    required Uint8List bytes,
    required NaiImageMetadata? metadata,
  }) async {
    final state = ref.read(tagLibraryPageNotifierProvider);

    // 提取文件名作为默认条目名称（去掉扩展名）
    final defaultName = path.basenameWithoutExtension(fileName);

    // 准备预填数据
    final initialContent = metadata?.prompt ?? '';

    if (!context.mounted) return;

    // 显示 EntryAddDialog，预填数据
    await showDialog(
      context: context,
      builder: (dialogContext) => EntryAddDialog(
        categories: state.categories,
        initialCategoryId: state.selectedCategoryId,
        initialContent: initialContent.isNotEmpty ? initialContent : null,
        initialImageBytes: bytes,
        initialName: defaultName,
      ),
    );
  }

  /// 处理更新现有条目预览图
  static Future<void> _handleUpdateThumbnail({
    required BuildContext context,
    required WidgetRef ref,
    required Uint8List bytes,
  }) async {
    final state = ref.read(tagLibraryPageNotifierProvider);

    // 显示条目选择对话框
    final selectedEntry = await EntrySelectorDialog.show(
      context,
      entries: state.entries,
      categories: state.categories,
    );

    if (selectedEntry == null || !context.mounted) return;

    // 保存图片到应用目录
    final thumbnailPath = await _saveThumbnailToAppDir(bytes);
    if (thumbnailPath == null) {
      // ignore: use_build_context_synchronously
      await _showError(context, '保存预览图失败');
      return;
    }

    // 删除旧预览图（如果存在且在应用目录内）
    await _deleteOldThumbnail(selectedEntry.thumbnail);

    // 更新条目
    final updatedEntry = selectedEntry.copyWith(
      thumbnail: thumbnailPath,
      updatedAt: DateTime.now(),
    );

    await ref.read(tagLibraryPageNotifierProvider.notifier).updateEntry(updatedEntry);

    if (context.mounted) {
      AppToast.success(context, '预览图已更新');
    }
  }

  /// 将缩略图保存到应用目录
  static Future<String?> _saveThumbnailToAppDir(Uint8List bytes) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory(
        path.join(appDir.path, 'tag_library_thumbnails'),
      );

      // 确保目录存在
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }

      // 生成唯一文件名
      final fileName = '${const Uuid().v4()}.png';
      final filePath = path.join(thumbnailsDir.path, fileName);

      // 写入文件
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e, stack) {
      AppLogger.e('保存缩略图失败', e, stack, 'TagLibraryDropHandler');
      return null;
    }
  }

  /// 删除旧的缩略图文件
  static Future<void> _deleteOldThumbnail(String? oldThumbnailPath) async {
    if (oldThumbnailPath == null || oldThumbnailPath.isEmpty) {
      return;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = path.join(appDir.path, 'tag_library_thumbnails');

      // 只删除应用目录内的文件，避免误删外部文件
      if (oldThumbnailPath.startsWith(thumbnailsDir)) {
        final file = File(oldThumbnailPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      // 忽略删除失败，不影响保存流程
      AppLogger.w('删除旧缩略图失败: $e', 'TagLibraryDropHandler');
    }
  }
}
