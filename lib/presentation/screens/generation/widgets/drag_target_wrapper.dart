import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../l10n/app_localizations.dart';
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
class DragTargetWrapper extends ConsumerWidget {
  final ImageParams params;
  final List<VibeReference> vibes;
  final bool showBackground;

  const DragTargetWrapper({
    super.key,
    required this.params,
    required this.vibes,
    required this.showBackground,
  });

  bool get hasVibes => vibes.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final panelState = ref.watch(referencePanelNotifierProvider);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    return DragTarget<VibeLibraryEntry>(
      onWillAcceptWithDetails: (details) {
        // 检查是否超过 16 个限制
        final currentCount =
            ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
        if (currentCount >= 16) {
          AppToast.warning(context, '已达到最大数量 (16张)');
          return false;
        }
        panelNotifier.setDraggingOver(true);
        return true;
      },
      onAcceptWithDetails: (details) async {
        HapticFeedback.heavyImpact();
        panelNotifier.setDraggingOver(false);
        await _addLibraryVibe(context, ref, details.data);
      },
      onLeave: (_) {
        panelNotifier.setDraggingOver(false);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: panelState.isDraggingOver
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : null,
            color: panelState.isDraggingOver
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasVibes) ...[
                ...List.generate(vibes.length, (index) {
                  final vibe = vibes[index];
                  final bundleSource = panelState.vibeBundleSources[vibe.displayName];
                  return VibeCard(
                    index: index,
                    vibe: vibe,
                    bundleSource: bundleSource,
                    onRemove: () => _removeVibe(context, ref, index),
                    onStrengthChanged: (value) =>
                        _updateVibeStrength(ref, index, value),
                    onInfoExtractedChanged: (value) =>
                        _updateVibeInfoExtracted(ref, index, value),
                    showBackground: showBackground,
                  );
                }),
                const SizedBox(height: 12),

                // 库操作按钮行
                LibraryActionsRow(
                  vibes: vibes,
                  onSaveToLibrary: () => _saveToLibrary(context, ref),
                  onImportFromLibrary: () => _importFromLibrary(context, ref),
                ),
                const SizedBox(height: 8),
              ] else ...[
                // 空状态优化
                _buildEmptyState(context, ref, theme),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 构建空状态 - 双卡片并排布局：从文件添加 + 从库导入
  Widget _buildEmptyState(BuildContext context, WidgetRef ref, ThemeData theme) {
    return Row(
      children: [
        // 从文件添加
        Expanded(
          child: EmptyStateCard(
            icon: Icons.add_photo_alternate_outlined,
            title: context.l10n.vibe_addFromFileTitle,
            subtitle: context.l10n.vibe_addFromFileSubtitle,
            onTap: () async => await _addVibe(context, ref),
          ),
        ),
        const SizedBox(width: 12),
        // 从库导入
        Expanded(
          child: EmptyStateCard(
            icon: Icons.folder_open_outlined,
            title: context.l10n.vibe_addFromLibraryTitle,
            subtitle: context.l10n.vibe_addFromLibrarySubtitle,
            onTap: () async => await _importFromLibrary(context, ref),
          ),
        ),
      ],
    );
  }

  void _removeVibe(BuildContext context, WidgetRef ref, int index) {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);
    final currentVibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    // 清理 bundle 来源记录
    if (index < currentVibes.length) {
      final vibeName = currentVibes[index].displayName;
      panelNotifier.removeBundleSource(vibeName);
    }

    notifier.removeVibeReference(index);
    notifier.saveGenerationState();
  }

  void _updateVibeStrength(WidgetRef ref, int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, strength: value);
  }

  void _updateVibeInfoExtracted(WidgetRef ref, int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, infoExtracted: value);
  }

  /// 从文件添加 Vibe（供外部调用）
  static Future<void> addVibeFromFile(BuildContext context, WidgetRef ref) async {
    await _addVibeStatic(context, ref);
  }

  static Future<void> _addVibeStatic(BuildContext context, WidgetRef ref) async {
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
        final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

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
              if (needsEncoding && context.mounted) {
                final dialogResult = await showDialog<
                    (bool confirmed, bool encode, bool autoSave)?>(
                  context: context,
                  // ignore: use_build_context_synchronously
                  builder: (context) => _buildEncodingDialogStatic(context, fileName),
                );

                if (dialogResult == null || dialogResult.$1 != true) {
                  continue;
                }
                encodeNow = dialogResult.$2;
                autoSaveToLibrary = dialogResult.$3;

                if (encodeNow && context.mounted) {
                  final params = ref.read(generationParamsNotifierProvider);
                  final encodedVibes = await panelNotifier.encodeVibesNow(
                    vibes,
                    model: params.model,
                  );
                  if (!context.mounted) continue;
                  if (encodedVibes != null) {
                    vibes = encodedVibes;
                    if (autoSaveToLibrary && context.mounted) {
                      await _saveEncodedVibesToLibrary(
                        context, ref, encodedVibes, fileName);
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
              if (context.mounted) {
                AppToast.error(context, 'Failed to parse $fileName: $e');
              }
            }
          }
        }
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

  static Widget _buildEncodingDialogStatic(BuildContext context, String fileName) {
    return _buildEncodingDialogInternal(context, fileName, AppLocalizations.of(context)!, Theme.of(context));
  }

  static Widget _buildEncodingDialogInternal(BuildContext context, String fileName, AppLocalizations l10n, ThemeData theme) {
    var encodeChecked = true;
    var autoSaveChecked = true;

    return StatefulBuilder(
      builder: (context, setState) {
        final confirmButtonText = encodeChecked ? '确认编码' : '仅添加图片';

        return AlertDialog(
          title: Text(l10n.vibeNoEncodingWarning),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName),
              const SizedBox(height: 8),
              Text(
                l10n.vibeWillCostAnlas(2),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.vibeEncodeConfirm,
                style: theme.textTheme.bodySmall,
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
                        style: theme.textTheme.bodyMedium,
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: encodeChecked
                              ? null
                              : theme.colorScheme.onSurface.withOpacity(0.4),
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
              child: Text(l10n.vibeCancel),
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

  Widget _buildEncodingDialog(BuildContext context, String fileName) {
    return _buildEncodingDialogInternal(context, fileName, context.l10n, Theme.of(context));
  }

  Future<void> _saveEncodedVibesToLibrary(
    BuildContext context,
    WidgetRef ref,
    List<VibeReference> vibes,
    String baseName,
  ) async {
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);
    final result = await panelNotifier.saveEncodedVibesToLibrary(vibes, baseName);

    if (context.mounted) {
      String message;
      if (result.savedCount > 0 && result.reusedCount > 0) {
        message = '新增 ${result.savedCount} 个，复用 ${result.reusedCount} 个';
      } else if (result.savedCount > 0) {
        message = '已保存 ${result.savedCount} 个编码后的 Vibe 到库中';
      } else {
        message = '库中已存在 ${result.reusedCount} 个，已更新使用记录';
      }
      AppToast.success(context, message);
    }
  }

  Future<void> _saveToLibrary(BuildContext context, WidgetRef ref) async {
    final params = ref.read(generationParamsNotifierProvider);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);
    final currentVibes = params.vibeReferencesV4;

    if (currentVibes.isEmpty) return;

    final firstVibe = currentVibes.first;
    final nameController = TextEditingController(
      text: currentVibes.length == 1 ? firstVibe.displayName : '',
    );

    final result = await showDialog<
        (bool confirmed, double strength, double infoExtracted)?>(
      context: context,
      builder: (context) => _buildSaveToLibraryDialog(context, nameController, firstVibe),
    );

    if (result != null && result.$1 && context.mounted) {
      final saveResult = await panelNotifier.saveCurrentVibesToLibrary(
        currentVibes,
        nameController.text.trim(),
        strength: result.$2,
        infoExtracted: result.$3,
      );

      if (context.mounted) {
        String message;
        if (saveResult.savedCount > 0 && saveResult.reusedCount > 0) {
          message = '新增 ${saveResult.savedCount} 个，复用 ${saveResult.reusedCount} 个';
        } else if (saveResult.savedCount > 0) {
          message = '已保存到 Vibe 库';
        } else {
          message = '库中已存在，已更新使用记录';
        }
        AppToast.success(context, message);
      }
    }

    nameController.dispose();
  }

  Widget _buildSaveToLibraryDialog(
    BuildContext context,
    TextEditingController nameController,
    VibeReference firstVibe,
  ) {
    var strengthValue = firstVibe.strength;
    var infoExtractedValue = firstVibe.infoExtracted;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('保存到 Vibe 库'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('保存 ${vibes.length} 个 Vibe 到库中'),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    hintText: '输入保存名称',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                _buildDialogSlider(
                  label: 'Reference Strength',
                  value: strengthValue,
                  onChanged: (value) => setState(() => strengthValue = value),
                ),
                const SizedBox(height: 16),
                _buildDialogSlider(
                  label: 'Information Extracted',
                  value: infoExtractedValue,
                  onChanged: (value) => setState(() => infoExtractedValue = value),
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
                  Navigator.of(context).pop((true, strengthValue, infoExtractedValue));
                }
              },
              child: Text(context.l10n.common_save),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogSlider({
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

  Future<void> _importFromLibrary(BuildContext context, WidgetRef ref) async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    try {
      final result = await VibeSelectorDialog.show(
        context: context,
        initialSelectedIds: const {},
        showReplaceOption: true,
        title: '从库导入 Vibe',
      );

      if (result == null || result.selectedEntries.isEmpty) return;

      final notifier = ref.read(generationParamsNotifierProvider.notifier);

      if (result.shouldReplace) {
        notifier.clearVibeReferences();
      }

      var totalAdded = 0;
      for (final entry in result.selectedEntries) {
        final currentCount =
            ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
        if (currentCount >= 16) break;

        if (entry.isBundle) {
          final added = await panelNotifier.extractAndAddBundleVibes(
            entry,
            maxCount: 16,
          );
          totalAdded += added;
        } else {
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

        await storageService.incrementUsedCount(entry.id);
      }

      await panelNotifier.loadRecentEntries();

      if (context.mounted) {
        AppToast.success(context, '已导入 $totalAdded 个 Vibe');
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import from library', e, stackTrace);
      if (context.mounted) {
        AppToast.error(context, '导入失败: $e');
      }
    }
  }

  Future<void> _addLibraryVibe(
    BuildContext context,
    WidgetRef ref,
    VibeLibraryEntry entry,
  ) async {
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    final success = await panelNotifier.addLibraryVibe(entry);

    if (context.mounted) {
      if (success) {
        AppToast.success(context, '已添加 Vibe: ${entry.displayName}');
      } else {
        AppToast.warning(context, '已达到最大数量 (16张)，请先移除一些 Vibe');
      }
    }
  }
}
