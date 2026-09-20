import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../../core/platform/platform_capabilities.dart';
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
    required AppLocalizations l10n,
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
        onError?.call(l10n.imagePicker_fileDataUnavailable);
        return null;
      }

      return ImagePickerResult(
        bytes: bytes,
        fileName: file.name,
        path: file.path,
      );
    } catch (e) {
      onError?.call(l10n.imagePicker_fileSelectionFailed(e.toString()));
      return null;
    }
  }

  /// 选择多个图像
  static Future<List<ImagePickerResult>> pickMultipleImages({
    required AppLocalizations l10n,
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
      onError?.call(l10n.imagePicker_fileSelectionFailed(e.toString()));
      return [];
    }
  }

  /// 选择文件
  ///
  /// [extensions] 允许的文件扩展名
  /// [allowMultiple] 是否允许多选
  /// [onError] 错误回调
  static Future<ImagePickerResult?> pickFile({
    required AppLocalizations l10n,
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
        onError?.call(l10n.imagePicker_fileDataUnavailable);
        return null;
      }

      return ImagePickerResult(
        bytes: bytes,
        fileName: file.name,
        path: file.path,
      );
    } catch (e) {
      onError?.call(l10n.imagePicker_fileSelectionFailed(e.toString()));
      return null;
    }
  }

  /// 选择目录
  ///
  /// 【偏离上游】上游在这里无条件调 `FilePicker.platform.getDirectoryPath`。
  /// iOS 上该调用返回的是一次性的 security-scoped 路径：本次运行内还能读，
  /// 进程重启后就失去授权，而调用方（`ImagePickerCard.onDirectorySelected`）
  /// 拿到的是要长期保存的目录字符串——界面会显示「已配置」，实际扫不到任何文件。
  ///
  /// 门控选的是 [PlatformCapabilities.supportsDirectoryBatchExport]（`!isIOS`）
  /// 而不是 [PlatformCapabilities.supportsCustomStorageDirectories]（`isDesktop`）：
  /// 上面这条失效原因是 iOS 独有的，Android 的 `getDirectoryPath` 走 SAF
  /// 仍然可用；用 `isDesktop` 会顺手把 Android 也关掉，那是本次任务之外的行为变更。
  /// 返回 null 等价于「用户取消」，调用方既有的 `if (path != null)` 分支直接兜住；
  /// 但入口按钮本身应由上层用同一能力位隐藏，不要留一个点了没反应的按钮。
  static Future<String?> pickDirectory({
    required AppLocalizations l10n,
    String? dialogTitle,
    void Function(String)? onError,
  }) async {
    if (!PlatformCapabilities.current.supportsDirectoryBatchExport) {
      return null;
    }
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
      );
      return path;
    } catch (e) {
      onError?.call(l10n.imagePicker_directorySelectionFailed(e.toString()));
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
