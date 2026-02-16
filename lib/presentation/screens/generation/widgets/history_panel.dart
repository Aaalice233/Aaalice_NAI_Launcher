import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/zip_utils.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/layout_state_provider.dart';
import '../../../providers/tag_library_page_provider.dart';
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
import '../../tag_library_page/widgets/entry_add_dialog.dart';
import 'empty_state_card.dart';

/// 历史面板组件
class HistoryPanel extends ConsumerStatefulWidget {
  const HistoryPanel({super.key});

  @override
  ConsumerState<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends ConsumerState<HistoryPanel> {
  final Set<String> _selectedIds = {};

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
              const EdgeInsets.only(left: 8, right: 4, top: 12, bottom: 12),
          child: Row(
            children: [
              // 折叠按钮
              _buildCollapseButton(theme),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.generation_historyRecord,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.history.isNotEmpty ||
                  state.currentImages.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_getAllSelectableImages(state).length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // 全选按钮
              if (state.history.isNotEmpty || state.currentImages.isNotEmpty)
                IconButton(
                  onPressed: () {
                    setState(() {
                      final allImages = _getAllSelectableImages(state);
                      if (_selectedIds.length == allImages.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.clear();
                        _selectedIds.addAll(allImages.map((img) => img.id));
                      }
                    });
                  },
                  icon: Icon(
                    _selectedIds.length == _getAllSelectableImages(state).length
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 20,
                  ),
                  tooltip: _selectedIds.length ==
                          _getAllSelectableImages(state).length
                      ? context.l10n.common_deselectAll
                      : context.l10n.common_selectAll,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              if (state.history.isNotEmpty || state.currentImages.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _showClearDialog(context, ref);
                  },
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: context.l10n.common_clear,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
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
        if (_selectedIds.isNotEmpty) _buildBottomActions(context, state, theme),
      ],
    );
  }

  Widget _buildCollapseButton(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref
            .read(layoutStateNotifierProvider.notifier)
            .setRightPanelExpanded(false),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // 图标
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_fix_high,
                size: 48,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            // 标题
            Text(
              context.l10n.generation_startCreating,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            // 副标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                context.l10n.generation_noHistoryGuide,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            // 快速操作卡片
            Row(
              children: [
                Expanded(
                  child: EmptyStateCard(
                    icon: Icons.shuffle,
                    title: context.l10n.generation_randomPrompt,
                    subtitle: context.l10n.generation_randomPromptSubtitle,
                    onTap: () => _generateRandomPrompt(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EmptyStateCard(
                    icon: Icons.clear_all,
                    title: context.l10n.generation_clearPrompt,
                    subtitle: context.l10n.generation_clearPromptSubtitle,
                    onTap: _clearPrompt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 生成随机提示词
  Future<void> _generateRandomPrompt(BuildContext context) async {
    try {
      // 使用统一的随机提示词生成并应用方法
      await ref
          .read(imageGenerationNotifierProvider.notifier)
          .generateAndApplyRandomPrompt();

      // 检查是否有角色被生成（用于 Toast 提示）
      final characterConfig = ref.read(characterPromptNotifierProvider);
      final hasCharacters = characterConfig.characters
          .any((c) => c.enabled && c.prompt.isNotEmpty);

      if (hasCharacters && context.mounted) {
        final count = characterConfig.characters
            .where((c) => c.enabled && c.prompt.isNotEmpty)
            .length;
        AppToast.success(
          context,
          context.l10n.tagLibrary_generatedCharacters(count.toString()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.tagLibrary_generateFailed(e.toString()),
        );
      }
    }
  }

  /// 清空提示词
  Future<void> _clearPrompt() async {
    ref.read(generationParamsNotifierProvider.notifier).updatePrompt('');
    // 同时清空角色提示词
    ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();

    AppToast.success(
      context,
      context.l10n.generation_promptCleared,
    );
  }

  /// 获取所有可选择的图像（当前批次已完成 + 去重后的历史）
  List<GeneratedImage> _getAllSelectableImages(ImageGenerationState state) {
    // 当前批次已完成的图像（不包括正在生成中的）
    final currentCompleted = state.currentImages;
    final currentIds = currentCompleted.map((img) => img.id).toSet();

    // 从历史中过滤掉已在 currentImages 中的图像
    final deduplicatedHistory =
        state.history.where((img) => !currentIds.contains(img.id)).toList();

    return [...currentCompleted, ...deduplicatedHistory];
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
    // 使用批次分辨率（点击生成时捕获），fallback 到全局参数
    final batchAspectRatio =
        (state.batchWidth != null && state.batchHeight != null)
            ? state.batchWidth! / state.batchHeight!
            : params.width / params.height;

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

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // 当前生成区块（不参与选择）- 使用批次分辨率
        if (index < currentGenerationCount) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AspectRatio(
              aspectRatio: batchAspectRatio.clamp(0.5, 2.0),
              child: _buildCurrentGenerationItem(
                context,
                index,
                state,
                state.batchWidth ?? params.width,
                state.batchHeight ?? params.height,
              ),
            ),
          );
        }

        // 历史图像（已去重）- 使用图像自己的宽高比
        final historyIndex = index - currentGenerationCount;
        final historyImage = deduplicatedHistory[historyIndex];
        // 计算在原始 history 中的真实索引（用于选择操作）
        final actualHistoryIndex = history.indexOf(historyImage);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AspectRatio(
            aspectRatio: historyImage.aspectRatio.clamp(0.5, 2.0),
            child: SelectableImageCard(
              imageBytes: historyImage.bytes,
              index: actualHistoryIndex,
              showIndex: false,
              isSelected: _selectedIds.contains(historyImage.id),
              onSelectionChanged: (selected) {
                setState(() {
                  if (selected) {
                    _selectedIds.add(historyImage.id);
                  } else {
                    _selectedIds.remove(historyImage.id);
                  }
                });
              },
              onFullscreen: () => _showFullscreen(context, historyImage.bytes),
              enableContextMenu: true,
              enableHoverScale: true,
              onOpenInExplorer: () =>
                  _saveAndOpenInExplorer(context, historyImage.bytes),
              onSaveToLibrary: (bytes, _) =>
                  _showSaveToLibraryDialog(context, bytes),
            ),
          ),
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

    // 已完成的当前图像（支持选择）
    if (index < completedImages.length) {
      final image = completedImages[index];
      final imageBytes = image.bytes;
      return SelectableImageCard(
        imageBytes: imageBytes,
        index: index,
        showIndex: true,
        isSelected: _selectedIds.contains(image.id),
        onSelectionChanged: (selected) {
          setState(() {
            if (selected) {
              _selectedIds.add(image.id);
            } else {
              _selectedIds.remove(image.id);
            }
          });
        },
        onFullscreen: () => _showFullscreen(context, imageBytes),
        enableContextMenu: true,
        enableHoverScale: true,
        onOpenInExplorer: () => _saveAndOpenInExplorer(context, imageBytes),
        onSaveToLibrary: (bytes, _) => _showSaveToLibraryDialog(context, bytes),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBottomActions(
    BuildContext context,
    ImageGenerationState state,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          // 打包按钮
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _packSelectedImages(context, state),
              icon: const Icon(Icons.archive_outlined, size: 20),
              label: Text('打包 (${_selectedIds.length})'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 保存按钮
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _saveSelectedImages(context, state),
              icon: const Icon(Icons.save_alt, size: 20),
              label:
                  Text('${context.l10n.image_save} (${_selectedIds.length})'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSelectedImages(
    BuildContext context,
    ImageGenerationState state,
  ) async {
    if (_selectedIds.isEmpty) return;

    try {
      final saveDir = await LocalGalleryRepository.instance.getImageDirectory();
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 从所有可选图像中查找选中的图像
      final allImages = _getAllSelectableImages(state);
      final selectedImages =
          allImages.where((img) => _selectedIds.contains(img.id)).toList();

      for (int i = 0; i < selectedImages.length; i++) {
        final fileName = 'NAI_${timestamp}_${i + 1}.png';
        final file = File('${saveDir.path}/$fileName');
        await file.writeAsBytes(selectedImages[i].bytes);
      }

      ref.read(localGalleryNotifierProvider.notifier).refresh();

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
        setState(() {
          _selectedIds.clear();
        });
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  /// 打包选中的图片成压缩包
  Future<void> _packSelectedImages(
    BuildContext context,
    ImageGenerationState state,
  ) async {
    if (_selectedIds.isEmpty) return;

    // 直接使用保存文件对话框，用户可以选择路径并输入文件名
    final defaultName = 'images_${DateTime.now().millisecondsSinceEpoch}';
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '保存压缩包',
      fileName: '$defaultName.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (outputPath == null || !context.mounted) return;

    // 确保文件名以 .zip 结尾
    final finalPath =
        outputPath.endsWith('.zip') ? outputPath : '$outputPath.zip';

    // 显示打包进度
    AppToast.info(context, '正在打包 ${_selectedIds.length} 张图片...');

    try {
      // 先将选中的图片保存到临时目录
      final tempDir = await Directory.systemTemp.createTemp('nai_pack_');
      final imagePaths = <String>[];

      final allImages = _getAllSelectableImages(state);
      final selectedImages =
          allImages.where((img) => _selectedIds.contains(img.id)).toList();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < selectedImages.length; i++) {
        final fileName = 'NAI_${timestamp}_${i + 1}.png';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(selectedImages[i].bytes);
        imagePaths.add(file.path);
      }

      // 执行打包
      final success = await ZipUtils.createZipFromImages(
        imagePaths,
        finalPath,
      );

      // 清理临时文件
      await tempDir.delete(recursive: true);

      if (context.mounted) {
        if (success) {
          AppToast.success(context, '已打包 ${selectedImages.length} 张图片');
          setState(() {
            _selectedIds.clear();
          });
        } else {
          AppToast.error(context, '打包失败');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '打包失败: $e');
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

  /// 显示保存到词库对话框
  Future<void> _showSaveToLibraryDialog(
    BuildContext context,
    Uint8List bytes,
  ) async {
    // 历史记录中的图像需要尝试从元数据解析提示词
    String prompt = '';

    try {
      final extractedMeta = await NaiMetadataParser.extractFromBytes(bytes);
      if (extractedMeta != null && extractedMeta.prompt.isNotEmpty) {
        prompt = extractedMeta.prompt;
      }
    } catch (e) {
      debugPrint('解析图像元数据失败: $e');
    }

    // 解析别名引用，保存实际内容到词库
    final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
    final resolvedPrompt = aliasResolver.resolveAliases(prompt);

    final tagLibraryState = ref.read(tagLibraryPageNotifierProvider);

    if (!context.mounted) return;

    await EntryAddDialog.show(
      context,
      categories: tagLibraryState.categories,
      initialContent: resolvedPrompt,
      initialImageBytes: bytes,
    );
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
        _selectedIds.clear();
      });
    }
  }
}
