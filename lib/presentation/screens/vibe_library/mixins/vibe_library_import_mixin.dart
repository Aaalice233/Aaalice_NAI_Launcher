import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_import_service.dart';
import '../../../providers/vibe_library_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../models/import_progress.dart';
import '../widgets/vibe_bundle_import_dialog.dart' as bundle_import_dialog;
import '../widgets/vibe_import_naming_dialog.dart' as naming_dialog;

/// Vibe库导入功能Mixin
/// 提供导入相关的状态管理和方法
///
/// 使用方式:
/// ```dart
/// class _VibeLibraryScreenState extends ConsumerState<VibeLibraryScreen>
///     with VibeLibraryImportMixin<VibeLibraryScreen> {
///   @override
///   Widget build(BuildContext context) {
///     // 使用 isImporting, importProgress 等状态
///     // 调用 importVibes(), handleDrop() 等方法
///   }
/// }
/// ```
mixin VibeLibraryImportMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// 是否正在导入
  bool isImporting = false;

  /// 是否正在打开文件选择器
  bool isPickingFile = false;

  /// 导入进度信息
  ImportProgress importProgress = const ImportProgress();

  /// 导入 Vibe 文件
  Future<void> importVibes() async {
    final files = await pickImportFiles();
    if (files == null || files.isEmpty) {
      return;
    }

    setState(() => isImporting = true);
    final (imageFiles, regularFiles) = await categorizeFiles(files);
    final currentCategoryId =
        ref.read(vibeLibraryNotifierProvider).selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
            ? currentCategoryId
            : null;
    final result = await processImportSources(
      imageItems: imageFiles,
      vibeFiles: regularFiles,
      targetCategoryId: targetCategoryId,
      onProgress: (current, total, message) {
        AppLogger.d(message, 'VibeLibrary');
      },
    );
    setState(() => isImporting = false);

    await handleImportResult(result.success, result.fail);
  }

  /// 从图片导入 Vibe
  Future<void> importVibesFromImage() async {
    setState(() => isPickingFile = true);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
      allowMultiple: true,
      dialogTitle: '选择包含 Vibe 的 PNG 图片',
    );

    setState(() => isPickingFile = false);

    if (result == null || result.files.isEmpty) return;

    setState(() => isImporting = true);

    // 获取当前选中的分类
    final currentCategoryId =
        ref.read(vibeLibraryNotifierProvider).selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
            ? currentCategoryId
            : null;

    // 创建导入服务和仓库
    final notifier = ref.read(vibeLibraryNotifierProvider.notifier);
    final repository = _VibeLibraryNotifierImportRepository(
      onGetAllEntries: () async =>
          ref.read(vibeLibraryNotifierProvider).entries,
      onSaveEntry: notifier.saveEntry,
    );
    final importService = VibeImportService(repository: repository);

    // 收集图片文件
    final imageFiles = <VibeImageImportItem>[];
    for (final file in result.files) {
      try {
        final bytes = await readPlatformFileBytes(file);
        imageFiles.add(
          VibeImageImportItem(
            source: file.name,
            bytes: bytes,
          ),
        );
      } catch (e) {
        AppLogger.e('读取图片文件失败: ${file.name}', e, null, 'VibeLibrary');
      }
    }

    var totalSuccess = 0;
    var totalFail = 0;

    try {
      final importResult = await importService.importFromImages(
        imageItems: imageFiles,
        categoryId: targetCategoryId,
        onNaming: (suggestedName, {required bool isBatch, thumbnail}) async {
          return naming_dialog.showVibeImportNamingDialog(
            context: context,
            suggestedName: suggestedName,
            isBatch: isBatch,
            thumbnail: thumbnail,
          );
        },
        onProgress: (current, total, message) {
          AppLogger.d(message, 'VibeLibrary');
        },
      );

      totalSuccess = importResult.successCount;
      totalFail = importResult.failCount;
    } catch (e, stackTrace) {
      AppLogger.e('从图片导入失败', e, stackTrace, 'VibeLibrary');
      if (mounted) {
        AppToast.error(context, '导入失败: $e');
      }
    }

    setState(() => isImporting = false);

    // 重新加载数据
    if (totalSuccess > 0) {
      await ref.read(vibeLibraryNotifierProvider.notifier).reload();
    }

    if (mounted) {
      if (totalFail == 0) {
        AppToast.success(context, '成功导入 $totalSuccess 个 Vibe');
      } else {
        AppToast.warning(
          context,
          '导入完成: $totalSuccess 成功, $totalFail 失败',
        );
      }
    }
  }

  /// 从剪贴板导入 Vibe 编码
  Future<void> importVibesFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim();

    if (text == null || text.isEmpty) {
      if (mounted) {
        AppToast.error(context, '剪贴板为空');
      }
      return;
    }

    setState(() => isImporting = true);

    // 获取当前选中的分类
    final currentCategoryId =
        ref.read(vibeLibraryNotifierProvider).selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
            ? currentCategoryId
            : null;

    // 创建导入服务和仓库
    final notifier = ref.read(vibeLibraryNotifierProvider.notifier);
    final repository = _VibeLibraryNotifierImportRepository(
      onGetAllEntries: () async =>
          ref.read(vibeLibraryNotifierProvider).entries,
      onSaveEntry: notifier.saveEntry,
    );
    final importService = VibeImportService(repository: repository);

    var totalSuccess = 0;
    var totalFail = 0;

    try {
      final result = await importService.importFromEncodings(
        encodings: [text],
        categoryId: targetCategoryId,
        onProgress: (current, total, message) {
          AppLogger.d(message, 'VibeLibrary');
        },
      );

      totalSuccess = result.successCount;
      totalFail = result.failCount;
    } catch (e, stackTrace) {
      AppLogger.e('从剪贴板导入失败', e, stackTrace, 'VibeLibrary');
      if (mounted) {
        AppToast.error(context, '导入失败: $e');
      }
    }

    setState(() => isImporting = false);

    // 重新加载数据
    if (totalSuccess > 0) {
      await ref.read(vibeLibraryNotifierProvider.notifier).reload();
    }

    if (mounted) {
      if (totalFail == 0) {
        AppToast.success(context, '成功导入 $totalSuccess 个 Vibe');
      } else {
        AppToast.warning(
          context,
          '导入完成: $totalSuccess 成功, $totalFail 失败',
        );
      }
    }
  }

  /// 选择导入文件
  Future<List<PlatformFile>?> pickImportFiles() async {
    setState(() => isPickingFile = true);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['naiv4vibe', 'naiv4vibebundle', 'png'],
      allowMultiple: true,
      dialogTitle: '选择要导入的 Vibe 文件',
    );

    setState(() => isPickingFile = false);
    return result?.files;
  }

  /// 分类文件
  Future<(List<VibeImageImportItem>, List<PlatformFile>)> categorizeFiles(
    List<PlatformFile> files,
  ) async {
    final imageFiles = <VibeImageImportItem>[];
    final regularFiles = <PlatformFile>[];

    for (final file in files) {
      final ext = file.extension?.toLowerCase() ?? '';
      if (ext == 'png') {
        try {
          final bytes = await readPlatformFileBytes(file);
          imageFiles.add(
            VibeImageImportItem(
              source: file.name,
              bytes: bytes,
            ),
          );
        } catch (e) {
          AppLogger.e('读取图片文件失败: ${file.name}', e, null, 'VibeLibrary');
        }
      } else if (ext == 'naiv4vibe' || ext == 'naiv4vibebundle') {
        regularFiles.add(file);
      }
    }

    return (imageFiles, regularFiles);
  }

  /// 处理导入源
  Future<({int success, int fail})> processImportSources({
    required List<VibeImageImportItem> imageItems,
    required List<PlatformFile> vibeFiles,
    String? targetCategoryId,
    required ImportProgressCallback onProgress,
  }) async {
    final notifier = ref.read(vibeLibraryNotifierProvider.notifier);
    final repository = _VibeLibraryNotifierImportRepository(
      onGetAllEntries: () async =>
          ref.read(vibeLibraryNotifierProvider).entries,
      onSaveEntry: notifier.saveEntry,
    );
    final importService = VibeImportService(repository: repository);

    var totalSuccess = 0;
    var totalFail = 0;
    final totalCount = imageItems.length + vibeFiles.length;

    // 处理普通文件
    if (vibeFiles.isNotEmpty) {
      onProgress(0, totalCount, '正在导入 ${vibeFiles.length} 个文件...');
      try {
        final result = await importService.importFromFile(
          files: vibeFiles,
          categoryId: targetCategoryId,
          onProgress: (current, total, message) {
            onProgress(
              imageItems.length + current,
              totalCount,
              message,
            );
          },
          onNaming: (suggestedName, {required bool isBatch, thumbnail}) async {
            return naming_dialog.showVibeImportNamingDialog(
              context: context,
              suggestedName: suggestedName,
              isBatch: isBatch,
              thumbnail: thumbnail,
            );
          },
          onBundleOption: (bundleName, vibes) async {
            return bundle_import_dialog.showVibeBundleImportDialog(
              context: context,
              bundleName: bundleName,
              vibes: vibes,
            );
          },
        );
        totalSuccess += result.successCount;
        totalFail += result.failCount;
      } catch (e, stackTrace) {
        AppLogger.e('导入文件失败', e, stackTrace, 'VibeLibrary');
        totalFail += vibeFiles.length;
      }
    }

    // 处理图片
    if (imageItems.isNotEmpty) {
      onProgress(
        vibeFiles.length,
        totalCount,
        '正在从 ${imageItems.length} 个图片中提取 Vibe...',
      );
      try {
        final result = await importService.importFromImages(
          imageItems: imageItems,
          categoryId: targetCategoryId,
          onProgress: (current, total, message) {
            onProgress(
              vibeFiles.length + current,
              totalCount,
              message,
            );
          },
          onNaming: (suggestedName, {required bool isBatch, thumbnail}) async {
            return naming_dialog.showVibeImportNamingDialog(
              context: context,
              suggestedName: suggestedName,
              isBatch: isBatch,
              thumbnail: thumbnail,
            );
          },
        );
        totalSuccess += result.successCount;
        totalFail += result.failCount;
      } catch (e, stackTrace) {
        AppLogger.e('从图片导入失败', e, stackTrace, 'VibeLibrary');
        totalFail += imageItems.length;
      }
    }

    return (success: totalSuccess, fail: totalFail);
  }

  /// 处理导入结果
  Future<void> handleImportResult(int totalSuccess, int totalFail) async {
    if (totalSuccess > 0) {
      await ref.read(vibeLibraryNotifierProvider.notifier).reload();
    }

    if (!mounted) {
      return;
    }

    if (totalFail == 0) {
      AppToast.success(context, '成功导入 $totalSuccess 个 Vibe');
    } else {
      AppToast.warning(
        context,
        '导入完成: $totalSuccess 成功, $totalFail 失败',
      );
    }
  }

  /// 读取平台文件字节
  Future<Uint8List> readPlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw ArgumentError('File path is empty: ${file.name}');
    }

    return File(path).readAsBytes();
  }

  /// 处理拖拽文件
  /// 支持 .naiv4vibe, .naiv4vibebundle, .png 格式，以及文件夹
  Future<void> handleDrop(PerformDropEvent event) async {
    // 收集所有文件/文件夹路径
    final allPaths = <String>[];

    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null) continue;

      if (reader.canProvide(Formats.fileUri)) {
        final completer = Completer<Uri?>();
        reader.getValue<Uri>(Formats.fileUri, (uri) {
          completer.complete(uri);
        });
        final uri = await completer.future;
        if (uri != null) {
          allPaths.add(uri.toFilePath());
        }
      }
    }

    if (allPaths.isEmpty) return;

    // 递归收集所有文件
    final vibeFilePaths = <String>[];
    final imagePaths = <String>[];

    for (final path in allPaths) {
      final entity = FileSystemEntity.typeSync(path);
      if (entity == FileSystemEntityType.directory) {
        final dir = Directory(path);
        await for (final file in dir.list(recursive: true)) {
          if (file is File) {
            final ext = file.path.split('.').last.toLowerCase();
            if (ext == 'naiv4vibe' || ext == 'naiv4vibebundle') {
              vibeFilePaths.add(file.path);
            } else if (ext == 'png') {
              imagePaths.add(file.path);
            }
          }
        }
      } else if (entity == FileSystemEntityType.file) {
        final ext = path.split('.').last.toLowerCase();
        if (ext == 'naiv4vibe' || ext == 'naiv4vibebundle') {
          vibeFilePaths.add(path);
        } else if (ext == 'png') {
          imagePaths.add(path);
        }
      }
    }

    if (vibeFilePaths.isEmpty && imagePaths.isEmpty) return;

    // 创建 vibeFiles 列表
    final vibeFiles = <PlatformFile>[];
    for (final path in vibeFilePaths) {
      vibeFiles.add(PlatformFile(
        name: path.split(Platform.pathSeparator).last,
        path: path,
        size: await File(path).length(),
      ));
    }

    // 设置导入状态
    setState(() {
      isImporting = true;
      importProgress = ImportProgress(
        total: imagePaths.length + vibeFilePaths.length,
        message: '准备导入...',
      );
    });

    // 获取当前选中的分类
    final currentCategoryId =
        ref.read(vibeLibraryNotifierProvider).selectedCategoryId;
    final targetCategoryId =
        (currentCategoryId != null && currentCategoryId != 'favorites')
            ? currentCategoryId
            : null;

    final imageItems = <VibeImageImportItem>[];
    var preProcessFail = 0;
    for (final path in imagePaths) {
      try {
        final bytes = await File(path).readAsBytes();
        imageItems.add(
          VibeImageImportItem(
            source: path.split(Platform.pathSeparator).last,
            bytes: bytes,
          ),
        );
      } catch (e, stackTrace) {
        AppLogger.e('读取拖拽图片失败: $path', e, stackTrace, 'VibeLibrary');
        preProcessFail++;
      }
    }

    final result = await processImportSources(
      imageItems: imageItems,
      vibeFiles: vibeFiles,
      targetCategoryId: targetCategoryId,
      onProgress: (current, total, message) {
        if (!mounted) {
          return;
        }
        setState(() {
          importProgress = importProgress.copyWith(
            current: current,
            total: total,
            message: message,
          );
        });
      },
    );

    final totalSuccess = result.success;
    final totalFail = result.fail + preProcessFail;

    setState(() {
      isImporting = false;
      importProgress = const ImportProgress();
    });

    // 重新加载数据以确保UI显示导入的条目
    if (totalSuccess > 0) {
      await ref.read(vibeLibraryNotifierProvider.notifier).reload();
    }

    // 显示导入结果摘要
    if (mounted) {
      if (totalFail == 0) {
        AppToast.success(context, '成功导入 $totalSuccess 个 Vibe');
      } else {
        AppToast.warning(
          context,
          '导入完成: $totalSuccess 成功, $totalFail 失败',
        );
      }
    }
  }

  /// 构建导入进度覆盖层
  Widget buildImportOverlay(ThemeData theme) {
    final hasProgress = importProgress.isActive;
    final progressValue = importProgress.progress;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    value: progressValue,
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  hasProgress ? '正在导入...' : '正在处理...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasProgress) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${importProgress.current} / ${importProgress.total}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (importProgress.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    importProgress.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vibe库通知器导入仓库适配器
class _VibeLibraryNotifierImportRepository
    implements VibeLibraryImportRepository {
  _VibeLibraryNotifierImportRepository({
    required this.onGetAllEntries,
    required this.onSaveEntry,
  });

  final Future<List<VibeLibraryEntry>> Function() onGetAllEntries;
  final Future<VibeLibraryEntry?> Function(VibeLibraryEntry) onSaveEntry;

  @override
  Future<List<VibeLibraryEntry>> getAllEntries() async {
    return onGetAllEntries();
  }

  @override
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) async {
    final result = await onSaveEntry(entry);
    if (result == null) {
      throw StateError('Failed to save entry: ${entry.id}');
    }
    return result;
  }
}
