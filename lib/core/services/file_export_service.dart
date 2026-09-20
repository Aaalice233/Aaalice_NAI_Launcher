import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../platform/platform_capabilities.dart';
import '../utils/file_name_sanitizer.dart';
import 'native_share_service.dart';

/// Writes generated files through the native document UI on Android.
///
/// Android document destinations are content URIs rather than writable Dart
/// file paths. Large exports are therefore streamed from an app-owned
/// temporary file by the native channel instead of copied through memory.
///
/// 【偏离上游：多出一条 iOS 分支】
/// 上游只有「Android 走 SAF / 其余走 `FilePicker.saveFile` 另存为对话框」两条路。
/// 但 file_picker 的 `file_picker_io.dart` 在 iOS/Android 下若 `bytes == null`
/// 会显式 `throw ArgumentError`，而上游的非 Android 分支恰恰不传 bytes——
/// 也就是说 `saveBytes` / `saveText` / `saveFileFromPath` 在 iOS 上 100% 抛异常，
/// 影响 20+ 个导出调用点。iOS 上没有另存为对话框，等价通道是
/// 「写应用私有临时文件 + 系统分享面板」（可存入「文件」App、AirDrop、发给其他应用）。
class FileExportService {
  FileExportService._();

  static const MethodChannel _channel = MethodChannel(
    'com.aaalice.nai_launcher/file_export',
  );

  /// 测试专用：覆盖平台判定。生产代码走
  /// [PlatformCapabilities.operatingSystem]（导出可能早于 Flutter 绑定初始化，
  /// 不能依赖 `defaultTargetPlatform`），但这样 iOS 分支在桌面 CI 上无法被覆盖，
  /// 而 iOS 分支恰恰是本文件最需要回归保护的部分。
  @visibleForTesting
  static PlatformCapabilities? debugPlatformOverride;

  static PlatformCapabilities get _platform =>
      debugPlatformOverride ?? PlatformCapabilities.operatingSystem;

  static bool get _isAndroid => _platform.isAndroid;

  static bool get _isIOS => _platform.isIOS;

  static Future<String?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String dialogTitle,
    required String mimeType,
    required List<String> allowedExtensions,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Export bytes cannot be empty');
    }

    if (_isAndroid) {
      return _withTemporaryFile(
        bytes: bytes,
        fileName: fileName,
        action: (path) => saveFileFromPath(
          sourcePath: path,
          fileName: fileName,
          dialogTitle: dialogTitle,
          mimeType: mimeType,
          allowedExtensions: allowedExtensions,
        ),
      );
    }

    if (_isIOS) {
      return _exportThroughShareSheet(
        fileName: _ensureExtension(fileName, allowedExtensions),
        mimeType: mimeType,
        writeContent: (target) => target.writeAsBytes(bytes, flush: true),
      );
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (outputPath == null) return null;
    final normalizedPath = _ensureExtension(outputPath, allowedExtensions);
    await _writeAtomically(normalizedPath, bytes);
    return normalizedPath;
  }

  static Future<String?> saveText({
    required String text,
    required String fileName,
    required String dialogTitle,
    required String mimeType,
    required List<String> allowedExtensions,
  }) {
    return saveBytes(
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileName: fileName,
      dialogTitle: dialogTitle,
      mimeType: mimeType,
      allowedExtensions: allowedExtensions,
    );
  }

  static Future<String?> saveFileFromPath({
    required String sourcePath,
    required String fileName,
    required String dialogTitle,
    required String mimeType,
    required List<String> allowedExtensions,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Export source does not exist', sourcePath);
    }

    if (_isAndroid) {
      return _channel.invokeMethod<String>('saveFileFromPath', {
        'sourcePath': sourcePath,
        'fileName': _safeFileName(fileName),
        'mimeType': mimeType,
      });
    }

    if (_isIOS) {
      // 按路径转存，避免把 ZIP / 模型包这类大文件整份读进内存。
      return _exportThroughShareSheet(
        fileName: _ensureExtension(fileName, allowedExtensions),
        mimeType: mimeType,
        writeContent: (target) => source.openRead().pipe(target.openWrite()),
      );
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (outputPath == null) return null;
    final normalizedPath = _ensureExtension(outputPath, allowedExtensions);
    if (p.equals(source.absolute.path, File(normalizedPath).absolute.path)) {
      return normalizedPath;
    }
    await _copyAtomically(source, normalizedPath);
    return normalizedPath;
  }

  /// 桌面「另存为」对话框，只取落地路径，内容由调用方自己写
  /// （例如 ZIP 需要边压缩边流式写盘，不适合先攒成 bytes）。
  ///
  /// 【上游没有这个方法】上游把这种场景留在 UI 层裸调
  /// `FilePicker.platform.saveFile`，iOS 上那一调用必抛 `ArgumentError`，
  /// 而且其中两处还在 try 块之外（未捕获异常 = 按钮点了没反应 + 一条 fatal 上报）。
  /// 这里统一收编：移动端返回 null，调用方应先用
  /// `PlatformCapabilities.supportsDocumentFileExport` 分流到
  /// [saveFileFromPath] / [withTemporaryOutput] 那条通道。
  static Future<String?> pickSaveFilePath({
    required String dialogTitle,
    required String fileName,
    required List<String> allowedExtensions,
  }) async {
    if (_isAndroid || _isIOS) return null;
    return FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
  }

  static Future<String?> pickExportDirectory({required String dialogTitle}) {
    if (_isAndroid) {
      return _channel.invokeMethod<String>('pickExportDirectory');
    }
    if (_isIOS) {
      // 【偏离上游】上游在这里无条件调 FilePicker.getDirectoryPath，而 iOS 返回的是
      // 一次性 security-scoped 路径：跨启动即失效，写进去的文件用户也看不到。
      // 返回 null 让调用方走「用户取消」的既有降级分支；入口本身应由
      // PlatformCapabilities.supportsDirectoryBatchExport 隐藏。
      return Future<String?>.value();
    }
    return FilePicker.platform.getDirectoryPath(dialogTitle: dialogTitle);
  }

  static Future<String> writeBytesToDirectory({
    required String directory,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Export bytes cannot be empty');
    }

    if (_isAndroid) {
      return _withTemporaryFile(
        bytes: bytes,
        fileName: fileName,
        action: (path) => writeFileToDirectory(
          directory: directory,
          sourcePath: path,
          fileName: fileName,
          mimeType: mimeType,
        ),
      ).then((value) {
        if (value == null) {
          throw const FileSystemException('Android document export failed');
        }
        return value;
      });
    }

    final outputPath = await _createUniqueFilePath(directory, fileName);
    await _writeAtomically(outputPath, bytes);
    return outputPath;
  }

  static Future<String> writeTextToDirectory({
    required String directory,
    required String text,
    required String fileName,
    required String mimeType,
  }) {
    return writeBytesToDirectory(
      directory: directory,
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  static Future<String> writeFileToDirectory({
    required String directory,
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Export source does not exist', sourcePath);
    }

    if (_isAndroid) {
      final outputUri = await _channel
          .invokeMethod<String>('writeFileToDirectory', {
            'directoryUri': directory,
            'sourcePath': sourcePath,
            'fileName': _safeFileName(fileName),
            'mimeType': mimeType,
          });
      if (outputUri == null) {
        throw const FileSystemException('Android document export failed');
      }
      return outputUri;
    }

    final outputPath = await _createUniqueFilePath(directory, fileName);
    await _copyAtomically(source, outputPath);
    return outputPath;
  }

  static Future<T> withTemporaryOutput<T>({
    required String fileName,
    required Future<T> Function(String path) action,
  }) async {
    final tempRoot = await getTemporaryDirectory();
    final exportDirectory = Directory(p.join(tempRoot.path, 'exports'));
    await exportDirectory.create(recursive: true);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final temporaryFile = File(
      p.join(exportDirectory.path, '${suffix}_${_safeFileName(fileName)}'),
    );
    try {
      return await action(temporaryFile.path);
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  static Future<String?> _withTemporaryFile({
    required Uint8List bytes,
    required String fileName,
    required Future<String?> Function(String path) action,
  }) {
    return withTemporaryOutput(
      fileName: fileName,
      action: (path) async {
        await File(path).writeAsBytes(bytes, flush: true);
        return action(path);
      },
    );
  }

  /// iOS 的「另存为」等价通道：先写到应用私有临时目录里一个**文件名干净**的暂存
  /// 文件（单独建一层目录，这样文件名不用像 [withTemporaryOutput] 那样加时间戳
  /// 前缀，用户在「文件」App 里看到的就是期望的名字），再交给系统分享面板。
  ///
  /// 返回值语义与 Android 分支一致：非 null 表示导出成功。Android 返回的是
  /// SAF 的 `content://` URI，同样不是可再次打开的本地路径；iOS 返回的是暂存
  /// 文件路径，仅作为成功标记用于日志与空值判断，函数返回时该文件已被清理。
  /// 用户划掉分享面板等同于桌面上取消另存为对话框，返回 null。
  static Future<String?> _exportThroughShareSheet({
    required String fileName,
    required String mimeType,
    required Future<void> Function(File target) writeContent,
  }) async {
    final safeName = _safeFileName(fileName);
    final tempRoot = await getTemporaryDirectory();
    final stagingDirectory = Directory(
      p.join(
        tempRoot.path,
        'exports',
        'share_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await stagingDirectory.create(recursive: true);
    final stagedFile = File(p.join(stagingDirectory.path, safeName));
    try {
      await writeContent(stagedFile);
      final result = await NativeShareService.shareFile(
        path: stagedFile.path,
        fileName: safeName,
        mimeType: mimeType,
      );
      if (result.status == ShareResultStatus.dismissed) return null;
      return stagedFile.path;
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  static String _safeFileName(String fileName) {
    final leafName = p.basename(fileName);
    final rawExtension = p.extension(leafName);
    final extension = RegExp(r'^\.[A-Za-z0-9]{1,24}$').hasMatch(rawExtension)
        ? rawExtension.toLowerCase()
        : '';
    final baseName = extension.isEmpty
        ? leafName
        : p.basenameWithoutExtension(leafName);
    final safeBaseName = FileNameSanitizer.sanitize(
      baseName,
      fallback: 'export',
      maxLength: 120,
    );
    return '$safeBaseName$extension';
  }

  static String _ensureExtension(
    String outputPath,
    List<String> allowedExtensions,
  ) {
    if (allowedExtensions.isEmpty || p.extension(outputPath).isNotEmpty) {
      return outputPath;
    }
    return '$outputPath.${allowedExtensions.first}';
  }

  static Future<void> _copyAtomically(File source, String outputPath) async {
    final target = File(outputPath);
    await target.parent.create(recursive: true);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${target.path}.$suffix.tmp');
    final backup = File('${target.path}.$suffix.bak');
    var backupCreated = false;
    try {
      await source.openRead().pipe(temporary.openWrite());
      if (await target.exists()) {
        await target.rename(backup.path);
        backupCreated = true;
      }
      await temporary.rename(target.path);
      if (backupCreated && await backup.exists()) await backup.delete();
    } on Object {
      if (backupCreated && !await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) await temporary.delete();
      if (await backup.exists() && await target.exists()) await backup.delete();
    }
  }

  static Future<void> _writeAtomically(
    String outputPath,
    Uint8List bytes,
  ) async {
    final target = File(outputPath);
    await target.parent.create(recursive: true);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('${target.path}.$suffix.tmp');
    final backup = File('${target.path}.$suffix.bak');
    var backupCreated = false;
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await target.exists()) {
        await target.rename(backup.path);
        backupCreated = true;
      }
      await temporary.rename(target.path);
      if (backupCreated && await backup.exists()) await backup.delete();
    } on Object {
      if (backupCreated && !await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) await temporary.delete();
      if (await backup.exists() && await target.exists()) await backup.delete();
    }
  }

  static Future<String> _createUniqueFilePath(
    String directory,
    String fileName,
  ) async {
    final outputDirectory = Directory(directory);
    await outputDirectory.create(recursive: true);
    final safeName = _safeFileName(fileName);
    final extension = p.extension(safeName);
    final baseName = p.basenameWithoutExtension(safeName);
    var candidate = p.join(outputDirectory.path, safeName);
    var suffix = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(outputDirectory.path, '$baseName ($suffix)$extension');
      suffix++;
    }
    return candidate;
  }
}
