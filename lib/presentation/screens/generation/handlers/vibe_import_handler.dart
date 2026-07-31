import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import for locale-aware string comparison

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../core/utils/vibe_performance_diagnostics.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/services/vibe_file_storage_service.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/vibe_library_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../vibe_library/widgets/vibe_selector_dialog.dart';

/// Vibe 导入处理器
///
/// 封装 Vibe 文件导入相关逻辑，包括：
/// - 从文件系统选择并导入 Vibe 文件
/// - 即时编码处理
/// - 保存到 Vibe 库
/// - 从 Vibe 库导入
class VibeImportHandler {
  VibeImportHandler({required this.ref, required this.context});

  final WidgetRef ref;
  final BuildContext context;

  static const String _tag = 'VibeImportHandler';

  /// 从文件系统选择并导入 Vibe 文件
  ///
  /// 支持格式：png, jpg, jpeg, webp, naiv4vibe, naiv4vibebundle
  /// 对于原始图片，会显示编码确认对话框
  Future<void> importFromFiles() async {
    final span = VibePerformanceDiagnostics.start(
      'importHandler.importFromFiles',
    );
    var pickedFiles = 0;
    var parsedFiles = 0;
    var parsedVibes = 0;
    var addedVibes = 0;
    var encodedFiles = 0;
    var autoSavedFiles = 0;
    try {
      // 使用 withData: false 提高文件选择器打开速度
      // 通过路径异步读取文件内容，避免阻塞 UI
      // lockParentWindow: true 在 Windows 上可提高对话框打开性能
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'naiv4vibe',
          'naiv4vibebundle',
        ],
        allowMultiple: true,
        withData: false,
        lockParentWindow: true,
      );

      if (result != null && result.files.isNotEmpty) {
        pickedFiles = result.files.length;
        final notifier = ref.read(generationParamsNotifierProvider.notifier);

        for (final file in result.files) {
          Uint8List? bytes;
          final String fileName = file.name;

          // 优先使用已加载的字节（如果有），否则通过路径读取
          if (file.bytes != null) {
            bytes = file.bytes;
          } else if (file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }

          if (bytes != null) {
            try {
              var vibes = await VibeFileParser.parseFile(fileName, bytes);
              parsedFiles++;
              parsedVibes += vibes.length;

              // 检查是否需要编码
              final needsEncoding = vibes.any(
                (v) => v.sourceType == VibeSourceType.rawImage,
              );

              // 如果需要编码，显示确认对话框
              var encodeNow = false;
              var autoSaveToLibrary = false;
              if (needsEncoding && context.mounted) {
                final dialogResult = await _showEncodingConfirmDialog(fileName);

                if (dialogResult == null || !dialogResult.$1) {
                  continue; // 用户取消，跳过此文件
                }
                encodeNow = dialogResult.$2;
                autoSaveToLibrary = dialogResult.$3;

                // 如果需要提前编码
                if (encodeNow && context.mounted) {
                  final encodedVibes = await _encodeVibesNow(vibes);
                  if (!context.mounted) continue;
                  if (encodedVibes != null) {
                    vibes = encodedVibes;
                    encodedFiles++;
                    // 编码成功后自动保存到库
                    if (autoSaveToLibrary && context.mounted) {
                      await _saveEncodedVibesToLibrary(encodedVibes, fileName);
                      autoSavedFiles++;
                    }
                  } else {
                    // 编码失败，询问是否继续添加未编码的
                    final continueAnyway = await _showEncodingFailedDialog();
                    if (continueAnyway != true) {
                      continue; // 跳过此文件
                    }
                  }
                }
              }

              notifier.addVibeReferences(vibes);
              addedVibes += vibes.length;
            } catch (e) {
              if (context.mounted) {
                AppLogger.e('Failed to parse file: $fileName', e, null, _tag);
                AppToast.error(
                  context,
                  context.l10n.vibe_import_fileParseFailed,
                );
              }
            }
          }
        }
        // 保存生成状态
        await notifier.saveGenerationState();
      }
    } catch (e) {
      AppLogger.e('File selection failed', e, null, _tag);
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibe_import_fileSelectionFailed);
      }
    } finally {
      span.finish(
        details: {
          'pickedFiles': pickedFiles,
          'parsedFiles': parsedFiles,
          'parsedVibes': parsedVibes,
          'addedVibes': addedVibes,
          'encodedFiles': encodedFiles,
          'autoSavedFiles': autoSavedFiles,
        },
      );
    }
  }

  /// 导入已经由拖拽读取到的单个 Vibe/图片文件。
  ///
  /// 用于局部 DropRegion，保留与“从文件添加”一致的解析和编码确认行为。
  Future<int> importDroppedFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final span = VibePerformanceDiagnostics.start(
      'importHandler.importDroppedFile',
      details: {'fileName': fileName},
    );
    var parsedVibes = 0;
    var addedVibes = 0;
    var encoded = false;
    try {
      final notifier = ref.read(generationParamsNotifierProvider.notifier);
      var vibes = await VibeFileParser.parseFile(fileName, bytes);
      parsedVibes = vibes.length;

      final needsEncoding = vibes.any(
        (v) => v.sourceType == VibeSourceType.rawImage,
      );

      if (needsEncoding && context.mounted) {
        final dialogResult = await _showEncodingConfirmDialog(fileName);
        if (dialogResult == null || !dialogResult.$1) {
          return 0;
        }

        final encodeNow = dialogResult.$2;
        final autoSaveToLibrary = dialogResult.$3;
        if (encodeNow && context.mounted) {
          final encodedVibes = await _encodeVibesNow(vibes);
          if (!context.mounted) {
            return 0;
          }

          if (encodedVibes != null) {
            vibes = encodedVibes;
            encoded = true;
            if (autoSaveToLibrary && context.mounted) {
              await _saveEncodedVibesToLibrary(encodedVibes, fileName);
            }
          } else {
            final continueAnyway = await _showEncodingFailedDialog();
            if (continueAnyway != true) {
              return 0;
            }
          }
        }
      }

      final beforeCount = ref
          .read(generationParamsNotifierProvider)
          .vibeReferencesV4
          .length;
      notifier.addVibeReferences(vibes);
      await notifier.saveGenerationState();

      final afterCount = ref
          .read(generationParamsNotifierProvider)
          .vibeReferencesV4
          .length;
      if (afterCount > beforeCount) {
        addedVibes = afterCount - beforeCount;
      }
      return addedVibes;
    } catch (e) {
      AppLogger.e('Failed to parse dropped file: $fileName', e, null, _tag);
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibe_import_fileParseFailed);
      }
      return 0;
    } finally {
      span.finish(
        details: {
          'parsedVibes': parsedVibes,
          'addedVibes': addedVibes,
          'encoded': encoded,
        },
      );
    }
  }

  /// 显示编码确认对话框
  Future<(bool confirmed, bool encode, bool autoSave)?>
  _showEncodingConfirmDialog(String fileName) async {
    final l10n = context.l10n;
    return showDialog<(bool confirmed, bool encode, bool autoSave)>(
      context: context,
      builder: (context) {
        // 默认都勾选
        var encodeChecked = true;
        var autoSaveChecked = true;
        return StatefulBuilder(
          builder: (context, setState) {
            // 根据勾选状态动态确定按钮文本
            final confirmButtonText = encodeChecked
                ? l10n.vibe_import_encodeNow
                : l10n.vibe_addImageOnly;

            return AlertDialog(
              title: Text(l10n.vibe_import_noEncodingData),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName),
                  const SizedBox(height: 8),
                  Text(
                    l10n.vibe_import_encodingCost,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.vibe_import_confirmCost,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  // 提前编码复选框
                  InkWell(
                    onTap: () {
                      setState(() {
                        encodeChecked = !encodeChecked;
                        if (!encodeChecked) {
                          autoSaveChecked = false;
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: encodeChecked,
                          onChanged: (value) {
                            setState(() {
                              encodeChecked = value ?? false;
                              if (!encodeChecked) {
                                autoSaveChecked = false;
                              }
                            });
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l10n.vibe_import_encodeNow,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 自动保存到库复选框（仅在提前编码时可用）
                  InkWell(
                    onTap: encodeChecked
                        ? () {
                            setState(() {
                              autoSaveChecked = !autoSaveChecked;
                            });
                          }
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: autoSaveChecked,
                          onChanged: encodeChecked
                              ? (value) {
                                  setState(() {
                                    autoSaveChecked = value ?? false;
                                  });
                                }
                              : null,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l10n.vibe_import_autoSave,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: encodeChecked
                                      ? null
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop((false, false, false)),
                  child: Text(context.l10n.common_cancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop((true, encodeChecked, autoSaveChecked)),
                  child: Text(confirmButtonText),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 显示编码失败对话框
  Future<bool?> _showEncodingFailedDialog() async {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.vibe_import_encodingFailed),
        content: Text(l10n.vibe_import_encodingFailedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_continue),
          ),
        ],
      ),
    );
  }

  /// 立即编码 Vibes（调用 API）
  Future<List<VibeReference>?> _encodeVibesNow(
    List<VibeReference> vibes,
  ) async {
    final span = VibePerformanceDiagnostics.start(
      'importHandler.encodeVibesNow',
      details: {
        'inputVibes': vibes.length,
        'rawImageVibes': vibes
            .where(
              (v) =>
                  v.sourceType == VibeSourceType.rawImage &&
                  v.rawImageData != null,
            )
            .length,
      },
    );
    var encodedCount = 0;
    var returnedCount = 0;
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final params = ref.read(generationParamsNotifierProvider);
    final model = params.model;

    // 显示编码进度对话框，使用 rootNavigator 确保正确关闭
    final dialogCompleter = Completer<void>();
    BuildContext? dialogContext;

    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) {
          dialogContext = ctx;
          dialogCompleter.complete();
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(context.l10n.vibe_import_encodingInProgress),
              ],
            ),
          );
        },
      ),
    );

    // 等待对话框显示完成
    await dialogCompleter.future;

    void closeDialog() {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
    }

    try {
      final encodedVibes = <VibeReference>[];
      for (final vibe in vibes) {
        if (vibe.sourceType == VibeSourceType.rawImage &&
            vibe.rawImageData != null) {
          // 添加 30 秒超时保护，防止 API 无限卡住
          final encoding = await notifier
              .encodeVibeWithCache(
                vibe.rawImageData!,
                model: model,
                informationExtracted: vibe.infoExtracted,
                vibeName: vibe.displayName,
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  AppLogger.w(
                    'Vibe encoding timeout: ${vibe.displayName}',
                    _tag,
                  );
                  return null;
                },
              );

          if (encoding != null) {
            encodedVibes.add(
              buildEncodedImportVibe(vibe, encoding, model: model),
            );
            encodedCount++;
          } else {
            // 编码失败，保留原始 vibe
            encodedVibes.add(vibe);
          }
        } else {
          // 不需要编码或已有编码
          encodedVibes.add(vibe);
        }
      }

      closeDialog();

      // 检查是否全部编码成功
      final allEncoded = encodedVibes.every(
        (v) =>
            v.sourceType != VibeSourceType.rawImage ||
            v.vibeEncoding.isNotEmpty,
      );
      returnedCount = encodedVibes.length;

      if (allEncoded) {
        if (context.mounted) {
          AppToast.success(context, context.l10n.vibe_import_encodingComplete);
        }
        return encodedVibes;
      } else {
        if (context.mounted) {
          AppToast.warning(context, context.l10n.vibe_import_partialFailed);
        }
        return encodedVibes;
      }
    } on TimeoutException catch (e) {
      AppLogger.e('Vibe encoding timeout', e, null, _tag);
      closeDialog();
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibe_import_timeout);
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to encode vibes', e, stackTrace, _tag);
      closeDialog();
      return null;
    } finally {
      span.finish(
        details: {'encoded': encodedCount, 'returnedVibes': returnedCount},
      );
    }
  }

  /// 保存已编码的 Vibes 到库
  ///
  /// 会检查库中是否已存在相同的 vibe，如果存在则只更新使用记录
  Future<void> _saveEncodedVibesToLibrary(
    List<VibeReference> vibes,
    String baseName,
  ) async {
    final span = VibePerformanceDiagnostics.start(
      'importHandler.saveEncodedVibesToLibrary',
      details: {'vibes': vibes.length},
    );
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    var savedCount = 0;
    var reusedCount = 0;

    try {
      for (final vibe in vibes) {
        // 检查是否已存在相同的 vibe
        final existingEntry = await _findExistingEntry(storageService, vibe);

        AppLogger.d(
          'Saving Vibe: name=${vibe.displayName}, encoding=${vibe.vibeEncoding.substring(0, vibe.vibeEncoding.length > 20 ? 20 : vibe.vibeEncoding.length)}..., existing=${existingEntry?.id ?? "null"}',
          _tag,
        );

        if (existingEntry != null) {
          // 已存在：更新使用记录
          await storageService.incrementUsedCount(existingEntry.id);
          reusedCount++;
          AppLogger.d(
            'Vibe already exists, updating usage: ${existingEntry.id}',
            _tag,
          );
        } else {
          // 不存在：创建新条目
          final entry = VibeLibraryEntry.fromVibeReference(
            name: vibes.length == 1
                ? baseName
                : '$baseName - ${vibe.displayName}',
            vibeData: vibe,
          );
          await storageService.saveEntry(entry);
          savedCount++;
          AppLogger.i('New Vibe saved: ${entry.id}, name=${entry.name}', _tag);
        }
      }

      if (context.mounted) {
        final message = _buildSaveMessage(savedCount, reusedCount);
        AppToast.success(context, message);
        // 通知 Vibe 库刷新
        ref.read(vibeLibraryNotifierProvider.notifier).reload();
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to save encoded vibes to library',
        e,
        stackTrace,
        _tag,
      );
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibe_saveToLibrary_saveFailed);
      }
    } finally {
      span.finish(details: {'saved': savedCount, 'reused': reusedCount});
    }
  }

  /// 在库中查找已存在的相同 vibe 条目
  ///
  /// 基于 vibeEncoding 或缩略图哈希进行匹配
  /// 返回匹配的条目，如果没有找到返回 null
  Future<VibeLibraryEntry?> _findExistingEntry(
    VibeLibraryStorageService storageService,
    VibeReference vibe,
  ) async {
    return storageService.findMatchingEntry(vibe);
  }

  /// 从库导入 Vibes
  ///
  /// 显示选择器对话框，支持替换或追加模式
  Future<void> importFromLibrary() async {
    final span = VibePerformanceDiagnostics.start(
      'importHandler.importFromLibrary',
    );
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    var selectedEntries = 0;
    var totalAdded = 0;
    var bundleEntries = 0;
    var replacedExisting = false;

    try {
      // 显示选择器对话框
      final result = await VibeSelectorDialog.show(
        context: context,
        initialSelectedIds: const {},
        showReplaceOption: true,
        title: context.l10n.vibe_import_title,
      );

      if (result == null || result.selectedEntries.isEmpty) return;
      selectedEntries = result.selectedEntries.length;

      final notifier = ref.read(generationParamsNotifierProvider.notifier);

      if (result.shouldReplace) {
        // 替换模式：清除现有并添加新的
        notifier.clearVibeReferences();
        replacedExisting = true;
      }

      // 处理每个选中的条目（支持 bundle 展开）
      for (final selectedEntry in result.selectedEntries) {
        final currentCount = ref
            .read(generationParamsNotifierProvider)
            .vibeReferencesV4
            .length;
        if (currentCount >= 16) break;

        var addedForEntry = 0;
        var canRecordUsage = selectedEntry.filePath != null;

        if (selectedEntry.isBundle) {
          bundleEntries++;
          final hydratedEntry = selectedEntry.filePath == null
              ? await storageService.getEntry(selectedEntry.id)
              : null;
          final importEntry = hydratedEntry ?? selectedEntry;
          canRecordUsage = canRecordUsage || hydratedEntry != null;

          // 从 bundle 提取 vibes；display entry 已包含 filePath 和数量缓存。
          addedForEntry = await extractAndAddBundleVibes(importEntry);
          totalAdded += addedForEntry;
        } else {
          final hydratedEntry = await storageService.getEntry(selectedEntry.id);
          final importEntry = hydratedEntry ?? selectedEntry;
          canRecordUsage = canRecordUsage || hydratedEntry != null;

          // 普通 vibe
          final existingNames = ref
              .read(generationParamsNotifierProvider)
              .vibeReferencesV4
              .map((v) => v.displayName)
              .toSet();
          if (!existingNames.contains(importEntry.displayName)) {
            final vibe = importEntry.toVibeReference();
            notifier.addVibeReferences([vibe], recordUsage: false);
            addedForEntry = 1;
            totalAdded++;
          }
        }

        // 仅在真正添加成功后记录一次库条目使用次数。
        if (addedForEntry > 0 && canRecordUsage) {
          await storageService.incrementUsedCount(selectedEntry.id);
        }
      }

      if (context.mounted) {
        AppToast.success(context, context.l10n.vibe_import_result(totalAdded));
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import from library', e, stackTrace, _tag);
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibe_import_importFailed);
      }
    } finally {
      span.finish(
        details: {
          'selectedEntries': selectedEntries,
          'bundleEntries': bundleEntries,
          'totalAdded': totalAdded,
          'replacedExisting': replacedExisting,
        },
      );
    }
  }

  /// 从 bundle 提取 vibes 并添加到生成参数
  ///
  /// 返回实际添加的数量
  Future<int> extractAndAddBundleVibes(VibeLibraryEntry entry) async {
    return _addBundleVibesToGeneration(
      entry: entry,
      maxCount: 16,
      showToast: false,
    );
  }

  /// 添加 bundle vibes 到生成参数
  Future<int> _addBundleVibesToGeneration({
    required VibeLibraryEntry entry,
    required int maxCount,
    required bool showToast,
  }) async {
    final span = VibePerformanceDiagnostics.start(
      'importHandler.addBundleVibesToGeneration',
      details: {
        'entryId': entry.id,
        'bundledVibes': entry.bundledVibeCount,
        'maxCount': maxCount,
        'showToast': showToast,
      },
    );
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentCount = ref
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4
        .length;
    final availableSlots = maxCount - currentCount;
    var extractedCount = 0;

    try {
      if (availableSlots <= 0 || entry.filePath == null) return 0;

      final fileStorage = VibeFileStorageService();
      final extractLimit = entry.bundledVibeCount
          .clamp(0, availableSlots)
          .toInt();
      final extractedVibes = await fileStorage.extractVibesFromBundle(
        entry.filePath!,
        limit: extractLimit,
      );

      if (extractedVibes.isNotEmpty) {
        // 设置 bundle 来源
        final vibesWithSource = extractedVibes
            .map((vibe) => vibe.copyWith(bundleSource: entry.displayName))
            .toList();
        notifier.addVibeReferences(vibesWithSource, recordUsage: false);

        if (showToast && context.mounted) {
          AppToast.success(
            context,
            context.l10n.vibe_addedCount(extractedVibes.length),
          );
        }
      }
      extractedCount = extractedVibes.length;

      return extractedVibes.length;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to extract vibes from bundle', e, stackTrace, _tag);
      return 0;
    } finally {
      span.finish(
        details: {
          'availableSlots': availableSlots,
          'extracted': extractedCount,
        },
      );
    }
  }

  /// 保存 Vibes 到库
  ///
  /// 显示保存对话框，允许用户设置名称和参数
  Future<void> saveToLibrary(List<VibeReference> vibes) async {
    if (vibes.isEmpty) return;

    final l10n = context.l10n;

    // 检查是否有未编码的原始图片
    final unencodedVibes = vibes.where((v) => v.vibeEncoding.isEmpty).toList();

    if (unencodedVibes.isNotEmpty) {
      AppToast.warning(
        context,
        l10n.vibe_saveToLibrary_saving(unencodedVibes.length),
      );
      return;
    }

    // 使用第一个 vibe 的默认值
    final firstVibe = vibes.first;
    final nameController = TextEditingController(
      text: vibes.length == 1 ? firstVibe.displayName : '',
    );

    final overwriteCandidate = await ref
        .read(vibeLibraryStorageServiceProvider)
        .findOverwriteCandidate(vibes);
    final showInfoExtractedControl = shouldShowInfoExtractedForLibrarySave(
      vibes,
    );

    if (!context.mounted) {
      nameController.dispose();
      return;
    }

    final result =
        await showDialog<
          (
            bool confirmed,
            double strength,
            double infoExtracted,
            bool overwriteOriginal,
          )?
        >(
          context: context,
          builder: (context) {
            var strengthValue = firstVibe.strength;
            var infoExtractedValue = firstVibe.infoExtracted;
            var overwriteOriginal = false;

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text(l10n.vibe_saveToLibrary_title),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.vibe_saveToLibrary_savingCount(vibes.length)),
                        const SizedBox(height: 16),
                        // 名称输入
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: l10n.vibe_saveToLibrary_nameLabel,
                            hintText: l10n.vibe_saveToLibrary_nameHint,
                            border: const OutlineInputBorder(),
                          ),
                          autofocus: true,
                        ),
                        const SizedBox(height: 24),
                        // Reference Strength 滑条
                        _buildDialogSlider(
                          context,
                          label: l10n.vibe_saveToLibrary_strength,
                          value: strengthValue,
                          onChanged: (value) =>
                              setState(() => strengthValue = value),
                        ),
                        if (showInfoExtractedControl) ...[
                          const SizedBox(height: 16),
                          _buildDialogSlider(
                            context,
                            label: l10n.vibe_saveToLibrary_infoExtracted,
                            value: infoExtractedValue,
                            onChanged: (value) =>
                                setState(() => infoExtractedValue = value),
                          ),
                        ],
                        if (overwriteCandidate != null) ...[
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            value: overwriteOriginal,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('直接替换原 Vibe 参数'),
                            subtitle: Text(
                              '仅覆盖 ${overwriteCandidate.displayName} 的库内参数，默认不勾选',
                            ),
                            onChanged: (value) => setState(
                              () => overwriteOriginal = value ?? false,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text(l10n.common_cancel),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isNotEmpty) {
                          Navigator.of(context).pop((
                            true,
                            strengthValue,
                            infoExtractedValue,
                            overwriteOriginal,
                          ));
                        }
                      },
                      child: Text(l10n.common_save),
                    ),
                  ],
                );
              },
            );
          },
        );

    if (result != null && result.$1 && context.mounted) {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final name = nameController.text.trim();
      final strength = result.$2;
      final infoExtracted = result.$3;
      final overwriteOriginal = result.$4;

      try {
        var savedCount = 0;
        var reusedCount = 0;
        final generationParams = ref.read(generationParamsNotifierProvider);
        final paramsNotifier = ref.read(
          generationParamsNotifierProvider.notifier,
        );

        for (final vibe in vibes) {
          final preparedVibe = await paramsNotifier
              .prepareVibeForLibraryParamSave(
                vibe,
                strength: strength,
                infoExtracted: infoExtracted,
                model: generationParams.model,
              );
          if (preparedVibe == null) {
            throw StateError('Vibe 重新编码失败: ${vibe.displayName}');
          }

          // 使用用户设置的参数创建新的 vibe
          final vibeWithParams = preparedVibe.normalizedForLibraryStorage();

          final existingEntry = await storageService.findEntryByName(name);

          if (!overwriteOriginal && existingEntry != null) {
            // 已存在相同名称：删除旧条目
            await storageService.deleteEntry(existingEntry.id);
            reusedCount++;
          }

          final shouldOverwrite =
              overwriteOriginal &&
              overwriteCandidate != null &&
              vibes.length == 1;
          final entry = shouldOverwrite
              ? overwriteCandidate.update(
                  vibeDisplayName: vibeWithParams.displayName,
                  vibeEncoding: vibeWithParams.vibeEncoding,
                  vibeThumbnail: vibeWithParams.thumbnail,
                  rawImageData: vibeWithParams.rawImageData,
                  strength: vibeWithParams.strength,
                  infoExtracted: vibeWithParams.infoExtracted,
                  sourceType: vibeWithParams.sourceType,
                  thumbnail:
                      overwriteCandidate.thumbnail ?? vibeWithParams.thumbnail,
                )
              : VibeLibraryEntry.fromVibeReference(
                  name: vibes.length == 1
                      ? name
                      : '$name - ${vibe.displayName}',
                  vibeData: vibeWithParams,
                );
          await storageService.saveEntry(entry);
          savedCount++;
        }

        if (context.mounted) {
          final message = _buildSaveMessage(savedCount, reusedCount);
          AppToast.success(context, message);
          // 通知 Vibe 库刷新
          ref.read(vibeLibraryNotifierProvider.notifier).reload();
        }
      } catch (e, stackTrace) {
        AppLogger.e('Failed to save to library', e, stackTrace, _tag);
        if (context.mounted) {
          AppToast.error(context, context.l10n.vibe_saveToLibrary_saveFailed);
        }
      }
    }

    nameController.dispose();
  }

  /// 构建保存消息
  String _buildSaveMessage(int savedCount, int reusedCount) {
    final l10n = context.l10n;
    if (savedCount > 0 && reusedCount > 0) {
      return l10n.vibe_saveToLibrary_mixed(savedCount, reusedCount);
    } else if (savedCount > 0) {
      return l10n.vibe_saveToLibrary_saved(savedCount);
    } else {
      return l10n.vibe_saveToLibrary_reused(reusedCount);
    }
  }

  /// 构建对话框中的滑条
  Widget _buildDialogSlider(
    BuildContext context, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          divisions: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

VibeLibraryEntry? findOriginalLibraryEntryForOverwrite(
  List<VibeReference> vibes,
  List<VibeLibraryEntry> entries,
) {
  if (vibes.length != 1) {
    return null;
  }

  final vibe = vibes.single;
  return entries.firstWhereOrNull((entry) {
    final sameDisplayName = entry.displayName == vibe.displayName;
    final sameEncoding = entry.vibeEncoding == vibe.vibeEncoding;
    final sameRawImage = const ListEquality<int>().equals(
      entry.rawImageData,
      vibe.rawImageData,
    );
    return sameDisplayName && (sameEncoding || sameRawImage);
  });
}

bool shouldShowInfoExtractedForLibrarySave(List<VibeReference> vibes) {
  if (vibes.isEmpty) {
    return false;
  }
  return vibes.every((vibe) => vibe.canReencodeFromRawSource);
}

VibeReference buildEncodedImportVibe(
  VibeReference vibe,
  String encoding, {
  String? model,
}) {
  return vibe.withEncodedVibe(encoding, model: model);
}
