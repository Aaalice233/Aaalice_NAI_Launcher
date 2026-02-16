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
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../providers/generation/reference_panel_notifier.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../vibe_library/widgets/vibe_selector_dialog.dart';
import 'empty_state_card.dart';
import 'recent_vibe_item.dart';
import 'vibe_card.dart';

/// Vibe Transfer 参考面板 - V4 Vibe Transfer（最多16张、预编码、编码成本显示）
///
/// 支持功能：
/// - V4 Vibe Transfer（16张、预编码、编码成本显示）
/// - Normalize 强度标准化开关
/// - 保存到库 / 从库导入
/// - 最近使用的 Vibes
/// - 源类型图标显示
class UnifiedReferencePanel extends ConsumerWidget {
  const UnifiedReferencePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final panelState = ref.watch(referencePanelNotifierProvider);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);
    final vibes = params.vibeReferencesV4;
    final hasVibes = vibes.isNotEmpty;

    // 判断是否显示背景（折叠且有数据时显示）
    final showBackground = hasVibes && !panelState.isExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.vibe_title,
      icon: Icons.auto_fix_high,
      isExpanded: panelState.isExpanded,
      onToggle: panelNotifier.toggleExpanded,
      hasData: hasVibes,
      backgroundImage: _buildBackgroundImage(vibes),
      badge: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: showBackground
              ? Colors.white.withOpacity(0.2)
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${params.vibeReferencesV4.length}/16',
          style: theme.textTheme.labelSmall?.copyWith(
            color: showBackground
                ? Colors.white
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),

            // Vibe Transfer 内容
            _buildVibeContent(
              context,
              ref,
              theme,
              params,
              panelState,
              showBackground,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建背景图片
  Widget _buildBackgroundImage(List<VibeReference> vibes) {
    if (vibes.isEmpty) {
      return const SizedBox.shrink();
    }

    if (vibes.length == 1) {
      // 单张风格迁移：全屏背景
      final imageData = vibes.first.rawImageData ?? vibes.first.thumbnail;
      if (imageData != null) {
        return Image.memory(imageData, fit: BoxFit.cover);
      }
    } else {
      // 多张风格迁移：横向并列
      return Row(
        children: vibes.map((vibe) {
          final imageData = vibe.rawImageData ?? vibe.thumbnail;
          return Expanded(
            child: imageData != null
                ? Image.memory(imageData, fit: BoxFit.cover)
                : const SizedBox.shrink(),
          );
        }).toList(),
      );
    }
    return const SizedBox.shrink();
  }

  /// 构建 Vibe Transfer 内容
  Widget _buildVibeContent(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ImageParams params,
    ReferencePanelState panelState,
    bool showBackground,
  ) {
    final vibes = params.vibeReferencesV4;
    final hasVibes = vibes.isNotEmpty;
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    // 构建 Vibe 列表或空状态内容
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 说明文字
        Text(
          context.l10n.vibe_description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: showBackground
                ? Colors.white70
                : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),

        // Normalize 复选框
        _buildNormalizeOption(context, ref, params, showBackground),
        const SizedBox(height: 12),

        // Vibe 列表或空状态（包裹 DragTarget 支持拖拽）
        _buildDragTargetWrapper(
          context,
          ref,
          theme,
          params,
          hasVibes,
          vibes,
          showBackground,
        ),

        // 添加按钮（有数据时显示）
        if (hasVibes && vibes.length < 16)
          OutlinedButton.icon(
            onPressed: () => _addVibe(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.vibe_addReference),
            style: showBackground
                ? OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  )
                : null,
          ),

        // 最近使用的 Vibes
        if (panelState.recentEntries.isNotEmpty && vibes.length < 16) ...[
          const SizedBox(height: 16),
          _buildRecentVibes(context, ref, theme, panelState),
        ],

        // 清除全部按钮
        if (hasVibes) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _clearAllVibes(context, ref),
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(context.l10n.vibe_clearAll),
            style: TextButton.styleFrom(
              foregroundColor:
                  showBackground ? Colors.red[300] : theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  /// 构建库操作按钮（保存到库、从库导入）
  Widget _buildLibraryActions(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    List<VibeReference> vibes,
  ) {
    return Row(
      children: [
        // 保存到库按钮
        Expanded(
          child: OutlinedButton.icon(
            onPressed: vibes.isNotEmpty ? () => _saveToLibrary(context, ref) : null,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('保存到库'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 从库导入按钮
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _importFromLibrary(context, ref),
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('从库导入'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
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

  /// 构建最近使用的 Vibes
  Widget _buildRecentVibes(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ReferencePanelState panelState,
  ) {
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 可点击的标题栏
        InkWell(
          onTap: panelNotifier.toggleRecentCollapsed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '最近使用',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 4),
                // 折叠/展开图标
                AnimatedRotation(
                  turns: panelState.isRecentCollapsed ? 0.75 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_left,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 可折叠的内容区域
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: panelState.recentEntries.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = panelState.recentEntries[index];
                  return RecentVibeItem(
                    entry: entry,
                    onTap: () => _addRecentVibe(context, ref, entry),
                  );
                },
              ),
            ),
          ),
          crossFadeState: panelState.isRecentCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildNormalizeOption(
    BuildContext context,
    WidgetRef ref,
    ImageParams params,
    bool showBackground,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Checkbox(
          value: params.normalizeVibeStrength,
          onChanged: (value) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .setNormalizeVibeStrength(value ?? true);
          },
          visualDensity: VisualDensity.compact,
          fillColor: showBackground
              ? WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.transparent;
                })
              : null,
          checkColor: showBackground ? Colors.black : null,
          side: showBackground ? const BorderSide(color: Colors.white) : null,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .setNormalizeVibeStrength(!params.normalizeVibeStrength);
            },
            child: Text(
              context.l10n.vibe_normalize,
              style: theme.textTheme.bodySmall?.copyWith(
                color: showBackground ? Colors.white : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建 DragTarget 包装器，支持从库拖拽 Vibe
  Widget _buildDragTargetWrapper(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ImageParams params,
    bool hasVibes,
    List<VibeReference> vibes,
    bool showBackground,
  ) {
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
                _buildLibraryActions(context, ref, theme, vibes),
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

  Future<void> _addVibe(BuildContext context, WidgetRef ref) async {
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
        withData: false, // 优化：不直接读取文件数据，通过路径读取
        lockParentWindow: true, // 优化：锁定父窗口提高 Windows 性能
      );

      if (result != null && result.files.isNotEmpty) {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);
        final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

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
                final dialogResult = await showDialog<
                    (bool confirmed, bool encode, bool autoSave)>(
                  context: context,
                  builder: (context) {
                    // 默认都勾选
                    var encodeChecked = true;
                    var autoSaveChecked = true;
                    return StatefulBuilder(
                      builder: (context, setState) {
                        // 根据勾选状态动态确定按钮文本
                        final confirmButtonText =
                            encodeChecked ? '确认编码' : '仅添加图片';

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
                                        '立即编码（消耗 2 Anlas）',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
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
                                                autoSaveChecked =
                                                    value ?? false;
                                              });
                                            }
                                          : null,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '编码后自动保存到 Vibe 库',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
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
                              onPressed: () => Navigator.of(context)
                                  .pop((false, false, false)),
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

                if (dialogResult == null || dialogResult.$1 != true) {
                  continue; // 用户取消，跳过此文件
                }
                encodeNow = dialogResult.$2;
                autoSaveToLibrary = dialogResult.$3;

                // 如果需要提前编码
                if (encodeNow && context.mounted) {
                  final params = ref.read(generationParamsNotifierProvider);
                  final encodedVibes = await panelNotifier.encodeVibesNow(
                    vibes,
                    model: params.model,
                  );
                  if (!context.mounted) continue;
                  if (encodedVibes != null) {
                    vibes = encodedVibes;
                    // 编码成功后自动保存到库
                    if (autoSaveToLibrary && context.mounted) {
                      await _saveEncodedVibesToLibrary(
                        context, ref, encodedVibes, fileName);
                    }
                  } else {
                    // 编码失败，询问是否继续添加未编码的
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

  void _removeVibe(BuildContext context, WidgetRef ref, int index) {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    // 清理 bundle 来源记录
    if (index < vibes.length) {
      final vibeName = vibes[index].displayName;
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

  void _clearAllVibes(BuildContext context, WidgetRef ref) {
    final params = ref.read(generationParamsNotifierProvider);
    final count = params.vibeReferencesV4.length;

    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    notifier.clearVibeReferences();
    notifier.saveGenerationState();

    // 清空 bundle 来源记录
    panelNotifier.clearBundleSources();

    if (context.mounted && count > 0) {
      AppToast.success(context, '已删除 $count 个 Vibe');
    }
  }

  /// 保存已编码的 Vibes 到库
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

  /// 保存当前 Vibes 到库（支持命名和参数设置）
  Future<void> _saveToLibrary(BuildContext context, WidgetRef ref) async {
    final params = ref.read(generationParamsNotifierProvider);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);
    final vibes = params.vibeReferencesV4;

    if (vibes.isEmpty) return;

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
              title: const Text('保存到 Vibe 库'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('保存 ${vibes.length} 个 Vibe 到库中'),
                    const SizedBox(height: 16),
                    // 名称输入
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
                    // Reference Strength 滑条
                    _buildDialogSlider(
                      label: 'Reference Strength',
                      value: strengthValue,
                      onChanged: (value) =>
                          setState(() => strengthValue = value),
                    ),
                    const SizedBox(height: 16),
                    // Information Extracted 滑条
                    _buildDialogSlider(
                      label: 'Information Extracted',
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
                        (
                          true,
                          strengthValue,
                          infoExtractedValue,
                        ),
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
      final saveResult = await panelNotifier.saveCurrentVibesToLibrary(
        vibes,
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

  /// 构建对话框中的滑条
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

  /// 从库导入 Vibes
  Future<void> _importFromLibrary(BuildContext context, WidgetRef ref) async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    try {
      // 显示选择器对话框
      final result = await VibeSelectorDialog.show(
        context: context,
        initialSelectedIds: const {},
        showReplaceOption: true,
        title: '从库导入 Vibe',
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
          final added = await panelNotifier.extractAndAddBundleVibes(
            entry,
            maxCount: 16,
          );
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

      // 刷新最近使用列表
      await panelNotifier.loadRecentEntries();

      if (context.mounted) {
        AppToast.success(
          context,
          '已导入 $totalAdded 个 Vibe',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import from library', e, stackTrace);
      if (context.mounted) {
        AppToast.error(context, '导入失败: $e');
      }
    }
  }

  /// 添加最近使用的 Vibe
  Future<void> _addRecentVibe(
    BuildContext context,
    WidgetRef ref,
    VibeLibraryEntry entry,
  ) async {
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    final success = await panelNotifier.addRecentVibe(entry);

    if (context.mounted) {
      if (success) {
        AppToast.success(context, '已添加: ${entry.displayName}');
      } else {
        AppToast.warning(context, '已达到最大数量 (16张)');
      }
    }
  }

  /// 从库中添加 Vibe（用于拖拽）
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
