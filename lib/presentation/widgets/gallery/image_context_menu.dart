import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../../data/models/gallery/local_image_record.dart';

import '../common/app_toast.dart';
/// Image context menu for copy prompt/seed, open folder, delete
/// 图片右键菜单（复制Prompt/Seed、在文件夹中显示、删除）
class ImageContextMenu {
  /// Show the context menu
  /// 显示上下文菜单
  static Future<void> show(
    BuildContext context,
    LocalImageRecord record,
    Offset position, {
    VoidCallback? onDeleted,
    VoidCallback? onRefresh,
  }) async {
    final metadata = record.metadata;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        if (metadata?.prompt.isNotEmpty == true)
          const PopupMenuItem(
            value: 'copy_prompt',
            child: Row(
              children: [
                Icon(Icons.content_copy, size: 18),
                SizedBox(width: 8),
                Text('复制 Prompt'),
              ],
            ),
          ),
        if (metadata?.seed != null)
          const PopupMenuItem(
            value: 'copy_seed',
            child: Row(
              children: [
                Icon(Icons.tag, size: 18),
                SizedBox(width: 8),
                Text('复制 Seed'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'open_folder',
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 18),
              SizedBox(width: 8),
              Text('在文件夹中显示'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );

    if (value == null || !context.mounted) return;

    switch (value) {
      case 'copy_prompt':
        if (metadata?.fullPrompt.isNotEmpty == true) {
          await Clipboard.setData(ClipboardData(text: metadata!.fullPrompt));
          if (context.mounted) {
            AppToast.info(context, 'Prompt 已复制');
          }
        }
        break;
      case 'copy_seed':
        if (metadata?.seed != null) {
          await Clipboard.setData(
            ClipboardData(text: metadata!.seed.toString()),
          );
          if (context.mounted) {
            AppToast.info(context, 'Seed 已复制');
          }
        }
        break;
      case 'open_folder':
        await _openFileInFolder(context, record.path);
        break;
      case 'delete':
        await _confirmDeleteImage(context, record, onDeleted, onRefresh);
        break;
    }
  }

  /// Open file in folder
  /// 在文件夹中打开文件
  static Future<void> _openFileInFolder(
    BuildContext context,
    String filePath,
  ) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path.dirname(filePath)]);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.info(context, '无法打开文件夹: $e');
      }
    }
  }

  /// Confirm delete image
  /// 确认删除图片
  static Future<void> _confirmDeleteImage(
    BuildContext context,
    LocalImageRecord record,
    VoidCallback? onDeleted,
    VoidCallback? onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除图片「${path.basename(record.path)}」吗？\n\n此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final file = File(record.path);
        if (await file.exists()) {
          await file.delete();
          onDeleted?.call();
          onRefresh?.call();
          if (context.mounted) {
            AppToast.info(context, '图片已删除');
          }
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.info(context, '删除失败: $e');
        }
      }
    }
  }
}
