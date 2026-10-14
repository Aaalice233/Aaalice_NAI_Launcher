import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../common/app_toast.dart';
import '../core/editor_image_decoder.dart';
import '../core/editor_state.dart';
import '../tools/move_tool.dart';

typedef EditorImageFile = ({String name, Uint8List bytes});

const _supportedExtensions = ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'];

/// 从文件选择器取一张图片；取消、格式不支持或读取失败时提示原因并返回 null
Future<EditorImageFile?> pickEditorImageFile(BuildContext context) async {
  final l10n = context.l10n;
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty || !context.mounted) return null;

  final file = result.files.first;
  final path = file.path;
  if (path != null) {
    final extension = path.split('.').last.toLowerCase();
    if (!_supportedExtensions.contains(extension)) {
      AppLogger.w('Invalid file extension: $extension', 'ImageEditor');
      AppToast.error(context, l10n.editor_unsupportedImageFormat(extension));
      return null;
    }
  }

  var bytes = file.bytes;
  if (bytes == null && path != null) {
    try {
      bytes = await File(path).readAsBytes();
    } catch (e) {
      AppLogger.e('Failed to read file: $e', 'ImageEditor');
      if (context.mounted) {
        AppToast.error(context, l10n.editor_readFileFailed(e));
      }
      return null;
    }
  }
  if (!context.mounted) return null;
  if (bytes == null) {
    AppLogger.w('File bytes is null', 'ImageEditor');
    AppToast.error(context, l10n.editor_noFileData);
    return null;
  }
  if (!checkEditorImageBytes(context, bytes)) return null;
  return (name: file.name, bytes: bytes);
}

/// 空文件与超过体积上限的文件提示原因并返回 false
bool checkEditorImageBytes(BuildContext context, Uint8List bytes) {
  final l10n = context.l10n;
  if (bytes.isEmpty) {
    AppLogger.w('Image file is empty', 'ImageEditor');
    AppToast.error(context, l10n.editor_emptyImageFile);
    return false;
  }
  if (bytes.length > EditorImageDecoder.maxFileBytes) {
    final sizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
    AppLogger.w('Image file too large: ${bytes.length} bytes', 'ImageEditor');
    AppToast.error(context, l10n.editor_fileTooLarge(sizeMB));
    return false;
  }
  return true;
}

/// 外部图片作为新图层导入，保留原图并立即进入自由变换；拖入与图层面板共用
Future<bool> importImageAsLayer(
  BuildContext context,
  EditorState state, {
  required Uint8List bytes,
  required String layerName,
}) async {
  if (!checkEditorImageBytes(context, bytes)) return false;
  final l10n = context.l10n;
  final ui.Image image;
  try {
    image = await EditorImageDecoder.decode(bytes);
  } catch (e) {
    AppLogger.w('Failed to decode imported image: $e', 'ImageEditor');
    if (context.mounted) AppToast.error(context, l10n.editor_parseImageFailed);
    return false;
  }
  if (!context.mounted) {
    image.dispose();
    return false;
  }
  state.setToolById(MoveTool.toolId);
  final placed = state.layerTransformer.placeImage(image, name: layerName);
  if (!placed) AppToast.error(context, l10n.editor_parseImageFailed);
  return placed;
}
