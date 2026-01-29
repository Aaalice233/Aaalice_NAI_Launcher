import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_metadata_parser.dart';
import '../../../../data/repositories/local_gallery_repository.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';
import '../../../widgets/common/image_detail/image_detail_viewer.dart';
import '../../../widgets/common/selectable_image_card.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../widgets/common/themed_divider.dart';

/// 历史面板组件
class HistoryPanel extends ConsumerStatefulWidget {
  const HistoryPanel({super.key});

  @override
  ConsumerState<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends ConsumerState<HistoryPanel> {
  final Set<int> _selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageGenerationNotifierProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Padding(
          padding:
              const EdgeInsets.only(left: 36, right: 12, top: 12, bottom: 12),
          child: Row(
            children: [
              Text(
                context.l10n.generation_historyRecord,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (state.history.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${state.history.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // 全选按钮
              if (state.history.isNotEmpty)
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedIndices.length == state.history.length) {
                        _selectedIndices.clear();
                      } else {
                        _selectedIndices.clear();
                        _selectedIndices.addAll(
                          List.generate(state.history.length, (i) => i),
                        );
                      }
                    });
                  },
                  icon: Icon(
                    _selectedIndices.length == state.history.length
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 20,
                  ),
                  tooltip: _selectedIndices.length == state.history.length
                      ? context.l10n.common_deselectAll
                      : context.l10n.common_selectAll,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              if (state.history.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    _showClearDialog(context, ref);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(context.l10n.common_clear),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
        ),
        const ThemedDivider(height: 1),

        // 历史列表
        Expanded(
          child: state.history.isEmpty && !_hasCurrentGeneration(state)
              ? _buildEmptyState(theme, context)
              : _buildHistoryGrid(state, theme, ref),
        ),

        // 底部操作栏（有选中时显示）
        if (_selectedIndices.isNotEmpty)
          _buildBottomActions(context, state.history, theme),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.generation_noHistory,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 判断是否有当前正在生成的图像
  bool _hasCurrentGeneration(ImageGenerationState state) {
    return state.isGenerating || state.currentImages.isNotEmpty;
  }

  /// 计算当前生成区块的项目数
  int _getCurrentGenerationCount(ImageGenerationState state) {
    if (!_hasCurrentGeneration(state)) return 0;
    int count = state.currentImages.length;
    if (state.isGenerating) {
      count += 1; // 加上生成中卡片
    }
    return count;
  }

  Widget _buildHistoryGrid(
    ImageGenerationState state,
    ThemeData theme,
    WidgetRef ref,
  ) {
    final params = ref.watch(generationParamsNotifierProvider);
    final history = state.history;
    final aspectRatio = params.width / params.height;

    // 计算当前生成区块的项目数
    final currentGenerationCount = _getCurrentGenerationCount(state);

    // 使用唯一 ID 去重：收集 currentImages 的 ID
    final currentImageIds = <String>{};
    for (final img in state.currentImages) {
      currentImageIds.add(img.id);
    }

    // 从历史中过滤掉已在 currentImages 中显示的图像
    final deduplicatedHistory =
        history.where((img) => !currentImageIds.contains(img.id)).toList();

    final totalCount = currentGenerationCount + deduplicatedHistory.length;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: aspectRatio.clamp(0.5, 2.0),
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // 当前生成区块（不参与选择）
        if (index < currentGenerationCount) {
          return _buildCurrentGenerationItem(
            context,
            index,
            state,
            params.width,
            params.height,
          );
        }

        // 历史图像（已去重）
        final historyIndex = index - currentGenerationCount;
        final historyImage = deduplicatedHistory[historyIndex];
        // 计算在原始 history 中的真实索引（用于选择操作）
        final actualHistoryIndex = history.indexOf(historyImage);
        return SelectableImageCard(
          imageBytes: historyImage.bytes,
          index: actualHistoryIndex,
          showIndex: false,
          isSelected: _selectedIndices.contains(actualHistoryIndex),
          onSelectionChanged: (selected) {
            setState(() {
              if (selected) {
                _selectedIndices.add(actualHistoryIndex);
              } else {
                _selectedIndices.remove(actualHistoryIndex);
              }
            });
          },
          onFullscreen: () => _showFullscreen(context, historyImage.bytes),
          enableContextMenu: true,
          enableHoverScale: true,
          onOpenInExplorer: () =>
              _saveAndOpenInExplorer(context, historyImage.bytes),
        );
      },
    );
  }

  /// 构建当前生成区块的单个项目
  Widget _buildCurrentGenerationItem(
    BuildContext context,
    int index,
    ImageGenerationState state,
    int imageWidth,
    int imageHeight,
  ) {
    final completedImages = state.currentImages;

    // 如果正在生成，最后一个位置显示生成中卡片
    if (state.isGenerating && index == completedImages.length) {
      return SelectableImageCard(
        isGenerating: true,
        currentImage: state.currentImage,
        totalImages: state.totalImages,
        progress: state.progress,
        streamPreview: state.streamPreview,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        enableSelection: false,
        enableContextMenu: false,
      );
    }

    // 已完成的当前图像（不可选择）
    if (index < completedImages.length) {
      final imageBytes = completedImages[index].bytes;
      return SelectableImageCard(
        imageBytes: imageBytes,
        index: index,
        showIndex: true,
        enableSelection: false,
        onTap: () => _showFullscreen(context, imageBytes),
        enableContextMenu: true,
        enableHoverScale: true,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBottomActions(
    BuildContext context,
    List<GeneratedImage> history,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.3))),
      ),
      child: FilledButton.icon(
        onPressed: () => _saveSelectedImages(context, history),
        icon: const Icon(Icons.save_alt, size: 20),
        label: Text('${context.l10n.image_save} (${_selectedIndices.length})'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
        ),
      ),
    );
  }

  Future<void> _saveSelectedImages(
    BuildContext context,
    List<GeneratedImage> history,
  ) async {
    if (_selectedIndices.isEmpty) return;

    try {
      final saveDir = await LocalGalleryRepository.instance.getImageDirectory();
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sortedIndices = _selectedIndices.toList()..sort();

      for (int i = 0; i < sortedIndices.length; i++) {
        final index = sortedIndices[i];
        final fileName = 'NAI_${timestamp}_${i + 1}.png';
        final file = File('${saveDir.path}/$fileName');
        await file.writeAsBytes(history[index].bytes);
      }

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
        setState(() {
          _selectedIndices.clear();
        });
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  /// 保存图片并在文件夹中打开
  Future<void> _saveAndOpenInExplorer(
    BuildContext context,
    Uint8List imageBytes,
  ) async {
    try {
      final saveDir = await LocalGalleryRepository.instance.getImageDirectory();
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 保存图片
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      // 在文件夹中打开并选中文件
      await Process.start('explorer', ['/select,${file.path}']);

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  void _showFullscreen(BuildContext context, Uint8List imageBytes) async {
    // 从图像中提取元数据
    final metadata = await NaiMetadataParser.extractFromBytes(imageBytes);

    final imageData = GeneratedImageDetailData.fromParams(
      imageBytes: imageBytes,
      prompt: metadata?.prompt ?? '',
      negativePrompt: metadata?.negativePrompt ?? '',
      seed: metadata?.seed ?? 0,
      steps: metadata?.steps ?? 28,
      scale: metadata?.scale ?? 5.0,
      width: metadata?.width ?? 832,
      height: metadata?.height ?? 1216,
      model: metadata?.source ?? 'nai-diffusion-4-full',
      sampler: metadata?.sampler ?? 'k_euler_ancestral',
      smea: metadata?.smea ?? true,
      smeaDyn: metadata?.smeaDyn ?? false,
      noiseSchedule: metadata?.noiseSchedule ?? 'native',
      cfgRescale: metadata?.cfgRescale ?? 0.0,
      characterPrompts: metadata?.characterPrompts ?? [],
      characterNegativePrompts: metadata?.characterNegativePrompts ?? [],
    );

    if (!context.mounted) return;

    ImageDetailViewer.showSingle(
      context,
      image: imageData,
      showMetadataPanel: true,
      callbacks: ImageDetailCallbacks(
        onSave: (image) => _saveImageFromDetail(context, image),
      ),
    );
  }

  /// 从详情页保存图像
  Future<void> _saveImageFromDetail(
    BuildContext context,
    ImageDetailData image,
  ) async {
    try {
      final imageBytes = await image.getImageBytes();
      final saveDir = await LocalGalleryRepository.instance.getImageDirectory();
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 从图像中提取元数据以获取正确的参数
      final metadata = await NaiMetadataParser.extractFromBytes(imageBytes);

      final commentJson = <String, dynamic>{
        'prompt': metadata?.prompt ?? '',
        'uc': metadata?.negativePrompt ?? '',
        'seed': metadata?.seed ?? Random().nextInt(4294967295),
        'steps': metadata?.steps ?? 28,
        'width': metadata?.width ?? 832,
        'height': metadata?.height ?? 1216,
        'scale': metadata?.scale ?? 5.0,
        'uncond_scale': 0.0,
        'cfg_rescale': metadata?.cfgRescale ?? 0.0,
        'n_samples': 1,
        'noise_schedule': metadata?.noiseSchedule ?? 'native',
        'sampler': metadata?.sampler ?? 'k_euler_ancestral',
        'sm': metadata?.smea ?? true,
        'sm_dyn': metadata?.smeaDyn ?? false,
      };

      // 添加 V4 多角色信息
      if (metadata?.characterPrompts.isNotEmpty == true) {
        final charCaptions = <Map<String, dynamic>>[];
        final charNegCaptions = <Map<String, dynamic>>[];

        for (int i = 0; i < metadata!.characterPrompts.length; i++) {
          charCaptions.add({
            'char_caption': metadata.characterPrompts[i],
            'centers': [
              {'x': 0.5, 'y': 0.5},
            ],
          });
          if (i < metadata.characterNegativePrompts.length) {
            charNegCaptions.add({
              'char_caption': metadata.characterNegativePrompts[i],
              'centers': [
                {'x': 0.5, 'y': 0.5},
              ],
            });
          }
        }

        commentJson['v4_prompt'] = {
          'caption': {
            'base_caption': metadata.prompt,
            'char_captions': charCaptions,
          },
          'use_coords': false,
          'use_order': true,
        };
        commentJson['v4_negative_prompt'] = {
          'caption': {
            'base_caption': metadata.negativePrompt,
            'char_captions': charNegCaptions,
          },
          'use_coords': false,
          'use_order': false,
        };
      }

      final embeddedMetadata = {
        'Description': metadata?.prompt ?? '',
        'Software': 'NovelAI',
        'Source': metadata?.source ?? 'NovelAI Diffusion',
        'Comment': jsonEncode(commentJson),
      };

      final embeddedBytes = await NaiMetadataParser.embedMetadata(
        imageBytes,
        jsonEncode(embeddedMetadata),
      );

      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(embeddedBytes);

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.generation_clearHistory,
      content: context.l10n.generation_clearHistoryConfirm,
      confirmText: context.l10n.common_clear,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_sweep_outlined,
    );

    if (confirmed) {
      ref.read(imageGenerationNotifierProvider.notifier).clearHistory();
      setState(() {
        _selectedIndices.clear();
      });
    }
  }
}
