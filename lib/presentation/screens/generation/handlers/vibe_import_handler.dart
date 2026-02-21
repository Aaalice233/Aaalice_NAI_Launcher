import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/vibe_library_extensions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_file_parser.dart';
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
  VibeImportHandler({
    required this.ref,
    required this.context,
  });

  final WidgetRef ref;
  final BuildContext context;

  static const String _tag = 'VibeImportHandler';

  /// 从文件系统选择并导入 Vibe 文件
  ///
  /// 支持格式：png, jpg, jpeg, webp, naiv4vibe, naiv4vibebundle
  /// 对于原始图片，会显示编码确认对话框
  Future<void> importFromFiles() async {
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
                    // 编码成功后自动保存到库
                    if (autoSaveToLibrary && context.mounted) {
                      await _saveEncodedVibesToLibrary(encodedVibes, fileName);
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
            } catch (e) {
              if (context.mounted) {
                AppToast.error(context, 'Failed to parse $fileName: $e');
              }
            }
          }
        }
        // 保存生成状态
        await notifier.saveGenerationState();
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.img2img_selectFailed(e.toString()),
        );
      }
    }
  }

  /// 显示编码确认对话框
  Future<(bool confirmed, bool encode, bool autoSave)?> _showEncodingConfirmDialog(
    String fileName,
  ) async {
    return showDialog<(bool confirmed, bool encode, bool autoSave)>(
      context: context,
      builder: (context) {
        // 默认都勾选
        var encodeChecked = true;
        var autoSaveChecked = true;
        return StatefulBuilder(
          builder: (context, setState) {
            // 根据勾选状态动态确定按钮文本
            final confirmButtonText =
                encodeChecked ? context.l10n.vibeConfirmEncode : context.l10n.vibeAddImageOnly;

            return AlertDialog(
              title: Text(context.l10n.vibeNoEncodingWarning),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.vibeWillCostAnlas(2),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.vibeEncodeConfirm,
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
                            context.l10n.vibeEncodeImmediately(2),
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
                            context.l10n.vibeAutoSaveToLibrary,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: encodeChecked
                                      ? null
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.4),
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
                  onPressed: () => Navigator.of(context).pop((false, false, false)),
                  child: Text(context.l10n.vibeCancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .pop((true, encodeChecked, autoSaveChecked)),
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
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.vibeEncodingFailed),
        content: Text(context.l10n.vibeEncodingFailedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.vibeCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.vibeContinue),
          ),
        ],
      ),
    );
  }

  /// 立即编码 Vibes（调用 API）
  Future<List<VibeReference>?> _encodeVibesNow(
    List<VibeReference> vibes,
  ) async {
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
                Text(context.l10n.vibeEncoding),
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
              vibe.copyWith(
                vibeEncoding: encoding,
                sourceType: VibeSourceType.naiv4vibe,
                rawImageData: null, // 编码后不需要原始图片数据
              ),
            );
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

      if (allEncoded) {
        if (context.mounted) {
          AppToast.success(context, context.l10n.vibeEncodingComplete);
        }
        return encodedVibes;
      } else {
        if (context.mounted) {
          AppToast.warning(context, context.l10n.vibeEncodingPartialFailed);
        }
        return encodedVibes;
      }
    } on TimeoutException catch (e) {
      AppLogger.e('Vibe encoding timeout', e, null, _tag);
      closeDialog();
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibeEncodingTimeout);
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to encode vibes', e, stackTrace, _tag);
      closeDialog();
      return null;
    }
  }

  /// 保存已编码的 Vibes 到库
  ///
  /// 会检查库中是否已存在相同的 vibe，如果存在则只更新使用记录
  Future<void> _saveEncodedVibesToLibrary(
    List<VibeReference> vibes,
    String baseName,
  ) async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);

    try {
      var savedCount = 0;
      var reusedCount = 0;

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
          AppLogger.i(
            'New Vibe saved: ${entry.id}, name=${entry.name}',
            _tag,
          );
        }
      }

      if (context.mounted) {
        String message;
        if (savedCount > 0 && reusedCount > 0) {
          message = context.l10n.vibeSavedAndReused(savedCount, reusedCount);
        } else if (savedCount > 0) {
          message = context.l10n.vibeSavedToLibrary(savedCount);
        } else {
          message = context.l10n.vibeReusedFromLibrary(reusedCount);
        }
        AppToast.success(context, message);
        // 通知 Vibe 库刷新
        ref.read(vibeLibraryNotifierProvider.notifier).reload();
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save encoded vibes to library', e, stackTrace, _tag);
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibeSaveToLibraryFailed);
      }
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
    final allEntries = await storageService.getAllEntries();
    return allEntries.findMatchingEntry(vibe);
  }

  /// 从库导入 Vibes
  ///
  /// 显示选择器对话框，支持替换或追加模式
  Future<void> importFromLibrary() async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);

    try {
      // 显示选择器对话框
      final result = await VibeSelectorDialog.show(
        context: context,
        initialSelectedIds: const {},
        showReplaceOption: true,
        title: context.l10n.vibeImportFromLibrary,
      );

      if (result == null || result.selectedEntries.isEmpty) return;

      final notifier = ref.read(generationParamsNotifierProvider.notifier);

      if (result.shouldReplace) {
        // 替换模式：清除现有并添加新的
        notifier.clearVibeReferences();
      }

      // 处理每个选中的条目（支持 bundle 展开）
      var totalAdded = 0;
      for (final entry in result.selectedEntries) {
        final currentCount =
            ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
        if (currentCount >= 16) break;

        if (entry.isBundle) {
          // 从 bundle 提取 vibes
          final added = await _extractAndAddBundleVibes(entry);
          totalAdded += added;
        } else {
          // 普通 vibe
          final existingNames = ref
              .read(generationParamsNotifierProvider)
              .vibeReferencesV4
              .map((v) => v.displayName)
              .toSet();
          if (!existingNames.contains(entry.displayName)) {
            final vibe = entry.toVibeReference();
            notifier.addVibeReferences([vibe]);
            totalAdded++;
          }
        }

        // 更新使用统计
        await storageService.incrementUsedCount(entry.id);
      }

      if (context.mounted) {
        AppToast.success(
          context,
          context.l10n.vibeImportSuccess(totalAdded),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import from library', e, stackTrace, _tag);
      if (context.mounted) {
        AppToast.error(context, context.l10n.vibeImportFailed(e.toString()));
      }
    }
  }

  /// 从 bundle 提取 vibes 并添加到生成参数
  ///
  /// 返回实际添加的数量
  Future<int> _extractAndAddBundleVibes(VibeLibraryEntry entry) async {
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
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentCount =
        ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
    final availableSlots = maxCount - currentCount;

    if (availableSlots <= 0 || entry.filePath == null) return 0;

    try {
      final fileStorage = VibeFileStorageService();
      final extractedVibes = <VibeReference>[];

      for (int i = 0;
          i < entry.bundledVibeCount.clamp(0, availableSlots);
          i++) {
        final vibe =
            await fileStorage.extractVibeFromBundle(entry.filePath!, i);
        if (vibe != null) extractedVibes.add(vibe);
      }

      if (extractedVibes.isNotEmpty) {
        // 设置 bundle 来源
        final vibesWithSource = extractedVibes
            .map((vibe) => vibe.copyWith(
                  bundleSource: entry.displayName,
                ))
            .toList();
        notifier.addVibeReferences(vibesWithSource);

        if (showToast && context.mounted) {
          AppToast.success(
              context, context.l10n.vibeAddedCount(extractedVibes.length));
        }
      }

      return extractedVibes.length;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to extract vibes from bundle', e, stackTrace, _tag);
      return 0;
    }
  }

  /// 保存 Vibes 到库
  ///
  /// 显示保存对话框，允许用户设置名称和参数
  Future<void> saveToLibrary(List<VibeReference> vibes) async {
    if (vibes.isEmpty) return;

    // 检查是否有未编码的原始图片
    final unencodedVibes = vibes
        .where(
          (v) => v.sourceType == VibeSourceType.rawImage && v.vibeEncoding.isEmpty,
        )
        .toList();

    if (unencodedVibes.isNotEmpty) {
      AppToast.warning(
        context,
        context.l10n.vibeNeedEncoding(unencodedVibes.length),
      );
      return;
    }

    // 使用第一个 vibe 的默认值
    final firstVibe = vibes.first;
    final nameController = TextEditingController(
      text: vibes.length == 1 ? firstVibe.displayName : '',
    );

    final result = await showDialog<
        (bool confirmed, double strength, double infoExtracted)?>(
      context: context,
      builder: (context) {
        var strengthValue = firstVibe.strength;
        var infoExtractedValue = firstVibe.infoExtracted;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(context.l10n.vibeSaveToLibrary),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.vibeSaveCount(vibes.length)),
                    const SizedBox(height: 16),
                    // 名称输入
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.vibeNameLabel,
                        hintText: context.l10n.vibeNameHint,
                        border: const OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    // Reference Strength 滑条
                    _buildDialogSlider(
                      context,
                      label: context.l10n.vibe_strength,
                      value: strengthValue,
                      onChanged: (value) =>
                          setState(() => strengthValue = value),
                    ),
                    const SizedBox(height: 16),
                    // Information Extracted 滑条
                    _buildDialogSlider(
                      context,
                      label: context.l10n.vibe_infoExtracted,
                      value: infoExtractedValue,
                      onChanged: (value) =>
                          setState(() => infoExtractedValue = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(context.l10n.common_cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      Navigator.of(context).pop(
                        (true, strengthValue, infoExtractedValue),
                      );
                    }
                  },
                  child: Text(context.l10n.common_save),
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

      try {
        var savedCount = 0;
        var reusedCount = 0;

        for (final vibe in vibes) {
          // 使用用户设置的参数创建新的 vibe
          final vibeWithParams = vibe.copyWith(
            strength: strength,
            infoExtracted: infoExtracted,
          );

          // 检查是否已存在相同名称的 vibe
          final allEntries = await storageService.getAllEntries();
          final existingEntry = allEntries.firstWhereOrNull((entry) {
            return entry.name.toLowerCase() == name.toLowerCase();
          });

          if (existingEntry != null) {
            // 已存在相同名称：删除旧条目
            await storageService.deleteEntry(existingEntry.id);
            reusedCount++;
          }

          // 创建新条目
          final entry = VibeLibraryEntry.fromVibeReference(
            name: vibes.length == 1 ? name : '$name - ${vibe.displayName}',
            vibeData: vibeWithParams,
          );
          await storageService.saveEntry(entry);
          savedCount++;
        }

        if (context.mounted) {
          String message;
          if (savedCount > 0 && reusedCount > 0) {
            message = context.l10n.vibeSavedAndReused(savedCount, reusedCount);
          } else if (savedCount > 0) {
            message = context.l10n.vibeSavedToLibrary(savedCount);
          } else {
            message = context.l10n.vibeReusedFromLibrary(reusedCount);
          }
          AppToast.success(context, message);
          // 通知 Vibe 库刷新
          ref.read(vibeLibraryNotifierProvider.notifier).reload();
        }
      } catch (e, stackTrace) {
        AppLogger.e('Failed to save to library', e, stackTrace, _tag);
        if (context.mounted) {
          AppToast.error(context, context.l10n.vibeSaveFailed);
        }
      }
    }

    nameController.dispose();
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
