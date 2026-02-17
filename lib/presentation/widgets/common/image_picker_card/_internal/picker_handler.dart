import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../image_picker_result.dart';

/// FilePicker 调用封装
///
/// 统一处理文件选择逻辑，支持图像、文件、目录三种模式
class PickerHandler {
  /// 选择图像
  ///
  /// [allowMultiple] 是否允许多选
  /// [onError] 错误回调
  static Future<ImagePickerResult?> pickImage({
    bool allowMultiple = false,
    void Function(String)? onError,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: allowMultiple,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final bytes = await _getFileBytes(file);

      if (bytes == null) {
        onError?.call('无法读取文件数据');
        return null;
      }

      return ImagePickerResult(
        bytes: bytes,
        fileName: file.name,
        path: file.path,
      );
    } catch (e) {
      onError?.call('选择文件失败: $e');
      return null;
    }
  }

  /// 选择多个图像
  static Future<List<ImagePickerResult>> pickMultipleImages({
    void Function(String)? onError,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return [];

      final results = <ImagePickerResult>[];
      for (final file in result.files) {
        final bytes = await _getFileBytes(file);
        if (bytes != null) {
          results.add(
            ImagePickerResult(
              bytes: bytes,
              fileName: file.name,
              path: file.path,
            ),
          );
        }
      }

      return results;
    } catch (e) {
      onError?.call('选择文件失败: $e');
      return [];
    }
  }

  /// 选择文件
  ///
  /// [extensions] 允许的文件扩展名
  /// [allowMultiple] 是否允许多选
  /// [onError] 错误回调
  static Future<ImagePickerResult?> pickFile({
    required List<String> extensions,
    bool allowMultiple = false,
    void Function(String)? onError,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: allowMultiple,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final bytes = await _getFileBytes(file);

      if (bytes == null) {
        onError?.call('无法读取文件数据');
        return null;
      }

      return ImagePickerResult(
        bytes: bytes,
        fileName: file.name,
        path: file.path,
      );
    } catch (e) {
      onError?.call('选择文件失败: $e');
      return null;
    }
  }

  /// 选择目录
  static Future<String?> pickDirectory({
    String? dialogTitle,
    void Function(String)? onError,
  }) async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
      );
      return path;
    } catch (e) {
      onError?.call('选择目录失败: $e');
      return null;
    }
  }

  /// 获取文件字节数据（兼容 Web 和桌面平台）
  static Future<Uint8List?> _getFileBytes(PlatformFile file) async {
    // Web 平台直接使用 bytes
    if (file.bytes != null) {
      return file.bytes;
    }

    // 桌面/移动平台从路径读取
    if (file.path != null) {
      try {
        return await File(file.path!).readAsBytes();
      } catch (e) {
        return null;
      }
    }

    return null;
  }
}
