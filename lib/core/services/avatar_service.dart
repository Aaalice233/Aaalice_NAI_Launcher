import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../data/models/auth/saved_account.dart';
import '../utils/app_logger.dart';

/// 头像操作结果
class AvatarResult {
  final String? path;
  final String? errorMessage;
  final AvatarResultType type;

  const AvatarResult(this.path, this.errorMessage, this.type);

  /// 成功结果
  const AvatarResult.success(this.path)
      : errorMessage = null,
        type = AvatarResultType.success;

  /// 失败结果
  const AvatarResult.failure(this.errorMessage)
      : path = null,
        type = AvatarResultType.failure;

  /// 取消结果（用户未选择）
  const AvatarResult.cancel()
      : path = null,
        errorMessage = null,
        type = AvatarResultType.cancel;

  /// 是否成功
  bool get isSuccess => type == AvatarResultType.success;

  /// 是否失败
  bool get isFailure => type == AvatarResultType.failure;

  /// 是否取消
  bool get isCancel => type == AvatarResultType.cancel;
}

enum AvatarResultType {
  success,
  failure,
  cancel,
}

/// 头像服务
/// 封装头像选择、复制、删除逻辑
class AvatarService {
  /// 获取头像目录路径
  Future<Directory> _getAvatarsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory(path.join(appDir.path, 'avatars'));

    // 确保目录存在
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }

    return avatarsDir;
  }

  /// 从相册选择并保存头像
  /// 返回 AvatarResult 包含路径或错误信息
  Future<AvatarResult> pickAndSaveAvatar(SavedAccount account) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      // 用户取消选择
      if (result == null || result.files.isEmpty) {
        return const AvatarResult.cancel();
      }

      final pickedFile = result.files.first;

      // 文件路径为空
      if (pickedFile.path == null) {
        return const AvatarResult.failure('无法获取文件路径');
      }

      final sourcePath = pickedFile.path!;
      AppLogger.i('Selected avatar file: $sourcePath', 'AvatarService');

      // 检查源文件是否存在
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        AppLogger.e('Source file not exists: $sourcePath', 'AvatarService');
        return const AvatarResult.failure('源文件不存在或已被删除');
      }

      final avatarsDir = await _getAvatarsDirectory();

      // 生成唯一文件名（使用账号ID）
      final extension = path.extension(sourcePath);
      final fileName = '${account.id}$extension';
      final finalPath = path.join(avatarsDir.path, fileName);

      AppLogger.i('Target avatar path: $finalPath', 'AvatarService');

      // 使用临时文件名，避免在复制过程中被其他操作删除
      final tempFileName = '${account.id}_temp$extension';
      final tempPath = path.join(avatarsDir.path, tempFileName);

      // 先复制到临时文件
      try {
        await sourceFile.copy(tempPath);
        AppLogger.i('Copied to temp file: $tempPath', 'AvatarService');
      } catch (copyError) {
        AppLogger.e('Failed to copy to temp file: $copyError', 'AvatarService');
        return AvatarResult.failure('无法复制文件：$copyError');
      }

      // 如果旧头像存在，先保存旧路径
      final oldAvatarPath = account.avatarPath;

      // 用临时文件重命名为最终文件（原子操作）
      try {
        final finalFile = File(finalPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await File(tempPath).rename(finalPath);
        AppLogger.i('Renamed temp to final: $finalPath', 'AvatarService');
      } catch (renameError) {
        // 重命名失败，清理临时文件
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        AppLogger.e(
          'Failed to rename temp file: $renameError',
          'AvatarService',
        );
        return AvatarResult.failure('无法保存头像：$renameError');
      }

      // 只有在成功保存后才删除旧头像
      if (oldAvatarPath != null && oldAvatarPath != finalPath) {
        try {
          final oldFile = File(oldAvatarPath);
          if (await oldFile.exists()) {
            await oldFile.delete();
            AppLogger.i('Deleted old avatar: $oldAvatarPath', 'AvatarService');
          }
        } catch (deleteError) {
          AppLogger.w(
            'Failed to delete old avatar: $deleteError',
            'AvatarService',
          );
          // 旧头像删除失败不影响新头像生效
        }
      }

      AppLogger.i('Avatar saved successfully: $finalPath', 'AvatarService');
      return AvatarResult.success(finalPath);
    } catch (e) {
      AppLogger.e('Failed to pick and save avatar: $e', 'AvatarService');
      return AvatarResult.failure('操作失败：$e');
    }
  }

  /// 移除头像
  /// 返回 true 表示成功，false 表示失败
  Future<bool> removeAvatar(SavedAccount account) async {
    try {
      // 删除头像文件
      if (account.avatarPath != null) {
        final file = File(account.avatarPath!);
        if (await file.exists()) {
          await file.delete();
          AppLogger.i(
            'Deleted avatar file: ${account.avatarPath}',
            'AvatarService',
          );
        }
      }

      AppLogger.i('Avatar removed for account: ${account.id}', 'AvatarService');
      return true;
    } catch (e) {
      AppLogger.e('Failed to remove avatar: $e', 'AvatarService');
      return false;
    }
  }

  /// 检查头像文件是否存在且有效
  bool isAvatarFileValid(String avatarPath) {
    try {
      final file = File(avatarPath);
      return file.existsSync();
    } catch (e) {
      AppLogger.w('Failed to check avatar file validity: $e', 'AvatarService');
      return false;
    }
  }

  /// 清理废弃的头像文件
  /// 遍历 avatars 目录，删除不属于任何账号的头像文件
  Future<void> cleanupOrphanedAvatars(
    List<SavedAccount> accounts,
  ) async {
    try {
      final avatarsDir = await _getAvatarsDirectory();
      if (!await avatarsDir.exists()) return;

      // 获取所有账号使用的头像路径集合
      final usedAvatarPaths = <String>{};
      for (final account in accounts) {
        if (account.avatarPath != null) {
          usedAvatarPaths.add(account.avatarPath!);
        }
      }

      // 遍历头像目录，删除废弃文件
      final files = avatarsDir.listSync();
      for (final entity in files) {
        if (entity is File) {
          final filePath = entity.path;
          if (!usedAvatarPaths.contains(filePath)) {
            await entity.delete();
            AppLogger.i('Deleted orphaned avatar: $filePath', 'AvatarService');
          }
        }
      }
    } catch (e) {
      AppLogger.e('Failed to cleanup orphaned avatars: $e', 'AvatarService');
    }
  }

  /// 获取账号的头像路径，如果文件不存在返回 null
  String? getValidAvatarPath(SavedAccount account) {
    if (account.avatarPath == null) return null;
    if (isAvatarFileValid(account.avatarPath!)) {
      return account.avatarPath;
    }
    return null;
  }
}
