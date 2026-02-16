import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../vibe_library/widgets/vibe_selector_dialog.dart';
import 'empty_state_card.dart';
import 'library_actions_row.dart';
import 'vibe_card.dart';

/// DragTarget 包装器，支持从库拖拽 Vibe
class DragTargetWrapper extends ConsumerStatefulWidget {
  final ImageParams params;
  final List<VibeReference> vibes;
  final bool showBackground;
  final Map<String, String> vibeBundleSources;
  final Function(int) onRemoveVibe;
  final Function(int, double) onUpdateStrength;
  final Function(int, double) onUpdateInfoExtracted;
  final VoidCallback onClearAll;
  final VoidCallback onSaveToLibrary;
  final VoidCallback onImportFromLibrary;

  const DragTargetWrapper({
    super.key,
    required this.params,
    required this.vibes,
    required this.showBackground,
    required this.vibeBundleSources,
    required this.onRemoveVibe,
    required this.onUpdateStrength,
    required this.onUpdateInfoExtracted,
    required this.onClearAll,
    required this.onSaveToLibrary,
    required this.onImportFromLibrary,
  });

  @override
  ConsumerState<DragTargetWrapper> createState() => _DragTargetWrapperState();
}

class _DragTargetWrapperState extends ConsumerState<DragTargetWrapper> {
  bool _isDraggingOver = false;

  bool get hasVibes => widget.vibes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<VibeLibraryEntry>(
      onWillAcceptWithDetails: (details) {
        // 检查是否超过 16 个限制
        final currentCount =
            ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
        if (currentCount >= 16) {
          AppToast.warning(context, '已达到最大数量 (16张)');
          return false;
        }
        setState(() => _isDraggingOver = true);
        return true;
      },
      onAcceptWithDetails: (details) async {
        HapticFeedback.heavyImpact();
        setState(() => _isDraggingOver = false);
        await _addLibraryVibe(details.data);
      },
      onLeave: (_) {
        setState(() => _isDraggingOver = false);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: _isDraggingOver
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : null,
            color: _isDraggingOver
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasVibes) ...[
                ...List.generate(widget.vibes.length, (index) {
                  final vibe = widget.vibes[index];
                  final bundleSource = widget.vibeBundleSources[vibe.displayName];
                  return VibeCard(
                    index: index,
                    vibe: vibe,
                    bundleSource: bundleSource,
                    onRemove: () => widget.onRemoveVibe(index),
                    onStrengthChanged: (value) =>
                        widget.onUpdateStrength(index, value),
                    onInfoExtractedChanged: (value) =>
                        widget.onUpdateInfoExtracted(index, value),
                    showBackground: widget.showBackground,
                  );
                }),
                const SizedBox(height: 12),

                // 库操作按钮行
                LibraryActionsRow(
                  vibes: widget.vibes,
                  onSaveToLibrary: widget.onSaveToLibrary,
                  onImportFromLibrary: widget.onImportFromLibrary,
                ),
                const SizedBox(height: 8),
              ] else ...[
                // 空状态优化
                _buildEmptyState(context, theme),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 构建空状态 - 双卡片并排布局：从文件添加 + 从库导入
  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        // 从文件添加
        Expanded(
          child: EmptyStateCard(
            icon: Icons.add_photo_alternate_outlined,
            title: context.l10n.vibe_addFromFileTitle,
            subtitle: context.l10n.vibe_addFromFileSubtitle,
            onTap: () async => await _addVibe(),
          ),
        ),
        const SizedBox(width: 12),
        // 从库导入
        Expanded(
          child: EmptyStateCard(
            icon: Icons.folder_open_outlined,
            title: context.l10n.vibe_addFromLibraryTitle,
            subtitle: context.l10n.vibe_addFromLibrarySubtitle,
            onTap: () async => await _importFromLibrary(),
          ),
        ),
      ],
    );
  }

  Future<void> _addVibe() async {
    try {
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

          if (file.bytes != null) {
            bytes = file.bytes;
          } else if (file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }

          if (bytes != null) {
            try {
              var vibes = await VibeFileParser.parseFile(fileName, bytes);

              final needsEncoding = vibes.any(
                (v) => v.sourceType == VibeSourceType.rawImage,
              );

              var encodeNow = false;
              var autoSaveToLibrary = false;
              if (needsEncoding && mounted) {
                final dialogResult = await showDialog<
                    (bool confirmed, bool encode, bool autoSave)?>(
                  context: context,
                  builder: (context) => _buildEncodingDialog(context, fileName),
                );

                if (dialogResult == null || dialogResult.$1 != true) {
                  continue;
                }
                encodeNow = dialogResult.$2;
                autoSaveToLibrary = dialogResult.$3;

                if (encodeNow && mounted) {
                  final encodedVibes = await _encodeVibesNow(vibes);
                  if (!mounted) continue;
                  if (encodedVibes != null) {
                    vibes = encodedVibes;
                    if (autoSaveToLibrary && mounted) {
                      await _saveEncodedVibesToLibrary(encodedVibes, fileName);
                    }
                  } else {
                    final continueAnyway = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('编码失败'),
                        content:
                            const Text('图片编码失败，是否继续添加未编码的图片？\n\n生成时会再次尝试编码。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('继续'),
                          ),
                        ],
                      ),
                    );
                    if (continueAnyway != true) {
                      continue;
                    }
                  }
                }
              }

              notifier.addVibeReferences(vibes);
            } catch (e) {
              if (mounted) {
                AppToast.error(context, 'Failed to parse $fileName: $e');
              }
            }
          }
        }
        await notifier.saveGenerationState();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.img2img_selectFailed(e.toString()),
        );
      }
    }
  }

  Widget _buildEncodingDialog(BuildContext context, String fileName) {
    var encodeChecked = true;
    var autoSaveChecked = true;

    return StatefulBuilder(
      builder: (context, setState) {
        final confirmButtonText = encodeChecked ? '确认编码' : '仅添加图片';

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
                        '立即编码（消耗 2 Anlas）',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
                        '编码后自动保存到 Vibe 库',
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
  }

  Future<List<VibeReference>?> _encodeVibesNow(
    List<VibeReference> vibes,
  ) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final params = ref.read(generationParamsNotifierProvider);
    final model = params.model;

    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        dialogContext = ctx;
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在编码 Vibe...'),
            ],
          ),
        );
      },
    );

    try {
      final encodedVibes = <VibeReference>[];
      for (final vibe in vibes) {
        if (vibe.sourceType == VibeSourceType.rawImage &&
            vibe.rawImageData != null) {
          final encoding = await notifier.encodeVibeWithCache(
            vibe.rawImageData!,
            model: model,
            informationExtracted: vibe.infoExtracted,
            vibeName: vibe.displayName,
          );

          if (encoding != null) {
            encodedVibes.add(
              vibe.copyWith(
                vibeEncoding: encoding,
                sourceType: VibeSourceType.naiv4vibe,
                rawImageData: null,
              ),
            );
          } else {
            encodedVibes.add(vibe);
          }
        } else {
          encodedVibes.add(vibe);
        }
      }

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      final allEncoded = encodedVibes.every(
        (v) =>
            v.sourceType != VibeSourceType.rawImage ||
            v.vibeEncoding.isNotEmpty,
      );

      if (allEncoded) {
        if (mounted) {
          AppToast.success(context, 'Vibe 编码完成');
        }
        return encodedVibes;
      } else {
        if (mounted) {
          AppToast.warning(context, '部分 Vibe 编码失败');
        }
        return encodedVibes;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to encode vibes', e, stackTrace);
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      return null;
    }
  }

  Future<void> _saveEncodedVibesToLibrary(
    List<VibeReference> vibes,
    String baseName,
  ) async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);

    try {
      var savedCount = 0;
      var reusedCount = 0;

      for (final vibe in vibes) {
        final allEntries = await storageService.getAllEntries();
        VibeLibraryEntry? existingEntry;

        for (final entry in allEntries) {
          if (entry.vibeEncoding.isNotEmpty &&
              entry.vibeEncoding == vibe.vibeEncoding) {
            existingEntry = entry;
            break;
          }
        }

        if (existingEntry != null) {
          await storageService.incrementUsedCount(existingEntry.id);
          reusedCount++;
        } else {
          final entry = VibeLibraryEntry.fromVibeReference(
            name: vibes.length == 1
                ? baseName
                : '$baseName - ${vibe.displayName}',
            vibeData: vibe,
          );
          await storageService.saveEntry(entry);
          savedCount++;
        }
      }

      if (mounted) {
        String message;
        if (savedCount > 0 && reusedCount > 0) {
          message = '新增 $savedCount 个，复用 $reusedCount 个';
        } else if (savedCount > 0) {
          message = '已保存 $savedCount 个编码后的 Vibe 到库中';
        } else {
          message = '库中已存在 $reusedCount 个，已更新使用记录';
        }
        AppToast.success(context, message);
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save encoded vibes to library', e, stackTrace);
      if (mounted) {
        AppToast.error(context, '保存到库失败: $e');
      }
    }
  }

  Future<void> _importFromLibrary() async {
    widget.onImportFromLibrary();
  }

  Future<void> _addLibraryVibe(VibeLibraryEntry entry) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    if (vibes.length >= 16) {
      AppToast.warning(context, '已达到最大数量 (16张)，请先移除一些 Vibe');
      return;
    }

    if (entry.isBundle) {
      await _addVibesFromBundle(entry);
      return;
    }

    final vibe = entry.toVibeReference();
    notifier.addVibeReferences([vibe]);

    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    await storageService.incrementUsedCount(entry.id);

    if (mounted) {
      AppToast.success(context, '已添加 Vibe: ${entry.displayName}');
    }
  }

  Future<void> _addVibesFromBundle(VibeLibraryEntry entry) async {
    if (entry.filePath == null) {
      AppToast.error(context, 'Bundle 文件路径不存在');
      return;
    }

    final currentCount =
        ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
    final availableSlots = 16 - currentCount;
    final bundleCount = entry.bundledVibeCount;

    if (availableSlots <= 0) {
      AppToast.warning(context, '已达到最大数量 (16张)，请先移除一些 Vibe');
      return;
    }

    if (bundleCount > availableSlots) {
      AppToast.warning(
        context,
        'Bundle 包含 $bundleCount 个 Vibe，只能添加前 $availableSlots 个',
      );
    }

    AppToast.info(context, '正在提取 Bundle 中的 Vibe...');

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
        final notifier = ref.read(generationParamsNotifierProvider.notifier);
        notifier.addVibeReferences(extractedVibes);

        if (mounted) {
          AppToast.success(context, '已添加 ${extractedVibes.length} 个 Vibe');
        }
      }

      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      await storageService.incrementUsedCount(entry.id);
    } catch (e, stackTrace) {
      AppLogger.e('从 Bundle 提取 Vibe 失败', e, stackTrace);
      if (mounted) {
        AppToast.error(context, '提取 Bundle 失败: $e');
      }
    }
  }
}
