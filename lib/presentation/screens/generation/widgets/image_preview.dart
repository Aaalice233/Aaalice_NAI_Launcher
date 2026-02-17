import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/nai_metadata_parser.dart';
import '../../../../data/repositories/local_gallery_repository.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/image_detail/image_detail_data.dart';
import '../../../widgets/common/image_detail/image_detail_viewer.dart';
import '../../../widgets/common/selectable_image_card.dart';
import '../../tag_library_page/widgets/entry_add_dialog.dart';
import 'upscale_dialog.dart';

/// 图像预览组件
class ImagePreviewWidget extends ConsumerStatefulWidget {
  const ImagePreviewWidget({super.key});

  @override
  ConsumerState<ImagePreviewWidget> createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends ConsumerState<ImagePreviewWidget> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageGenerationNotifierProvider);
    final theme = Theme.of(context);

    // 使用 GestureDetector 吸收整个区域的点击事件，避免 Windows 系统提示音
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // 空回调，仅吸收点击
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _buildContent(context, ref, state, theme),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ImageGenerationState state,
    ThemeData theme,
  ) {
    // 错误状态
    if (state.status == GenerationStatus.error) {
      return _buildErrorState(theme, state.errorMessage, context);
    }

    // 使用批次分辨率（点击生成时捕获），fallback 到全局参数
    final params = ref.watch(generationParamsNotifierProvider);
    final batchWidth = state.batchWidth ?? params.width;
    final batchHeight = state.batchHeight ?? params.height;

    // 生成中状态
    if (state.isGenerating) {
      // 如果有已完成的图像，显示混合视图（已完成图像 + 生成中卡片）
      if (state.currentImages.isNotEmpty) {
        return _buildGeneratingWithCompletedImages(
          context,
          ref,
          state,
          theme,
          batchWidth,
          batchHeight,
        );
      }
      // 否则只显示生成中卡片
      return _buildSingleGeneratingState(
        context,
        state,
        theme,
        batchWidth,
        batchHeight,
      );
    }

    // 有图像：根据数量决定布局（使用 displayImages）
    if (state.hasImages) {
      if (state.displayImages.length == 1) {
        // 单图：居中显示
        return _buildImageView(
          context,
          ref,
          state.displayImages.first,
          theme,
        );
      } else {
        // 多图：自适应网格
        return _buildMultiImageGrid(context, ref, state.displayImages, theme);
      }
    }

    // 空状态
    return _buildEmptyState(theme, context);
  }

  /// 计算自适应列数（基于可用宽度和最小/最大卡片尺寸）
  int _calculateColumnCount(int imageCount, double availableWidth) {
    // 最小卡片宽度: 150px，最大卡片宽度: 280px
    const minCardWidth = 150.0;
    const maxCardWidth = 280.0;
    const spacing = 12.0;

    // 计算基于图片数量的理想列数
    int idealColumns;
    if (imageCount <= 2) {
      idealColumns = 2;
    } else if (imageCount <= 4) {
      idealColumns = 2;
    } else if (imageCount <= 6) {
      idealColumns = 3;
    } else {
      idealColumns = 4;
    }

    // 根据可用宽度调整列数，确保卡片尺寸在合理范围内
    // 计算每种列数下的卡片宽度
    for (int cols = idealColumns; cols >= 2; cols--) {
      final cardWidth =
          (availableWidth - spacing * (cols - 1) - 16) / cols; // 16 = padding
      if (cardWidth >= minCardWidth && cardWidth <= maxCardWidth) {
        return cols;
      }
    }

    // 如果空间不足，尝试更多列数
    for (int cols = idealColumns + 1; cols <= 6; cols++) {
      final cardWidth = (availableWidth - spacing * (cols - 1) - 16) / cols;
      if (cardWidth >= minCardWidth) {
        return cols;
      }
    }

    // 回退到理想列数
    return idealColumns;
  }

  /// 构建多图网格视图
  Widget _buildMultiImageGrid(
    BuildContext context,
    WidgetRef ref,
    List<GeneratedImage> images,
    ThemeData theme,
  ) {
    // 使用第一张图像的宽高比（同一批次图像分辨率相同）
    final aspectRatio = images.isNotEmpty ? images.first.aspectRatio : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            _calculateColumnCount(images.length, constraints.maxWidth);

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final imageBytes = images[index].bytes;
            return SelectableImageCard(
              imageBytes: imageBytes,
              index: index,
              showIndex: true,
              enableSelection: false,
              onTap: () => _showFullscreenImage(imageBytes),
              onUpscale: () => UpscaleDialog.show(context, image: imageBytes),
              onSaveToLibrary: (bytes, _) =>
                  _showSaveToLibraryDialog(context, bytes),
            );
          },
        );
      },
    );
  }

  /// 生成中 + 有已完成图像的混合视图
  Widget _buildGeneratingWithCompletedImages(
    BuildContext context,
    WidgetRef ref,
    ImageGenerationState state,
    ThemeData theme,
    int imageWidth,
    int imageHeight,
  ) {
    final completedImages = state.currentImages;
    // 总数 = 已完成 + 1个生成中卡片
    final totalItems = completedImages.length + 1;
    final aspectRatio = imageWidth / imageHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            _calculateColumnCount(totalItems, constraints.maxWidth);

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            // 最后一个位置显示生成中卡片
            if (index == completedImages.length) {
              return SelectableImageCard(
                isGenerating: true,
                currentImage: state.currentImage,
                totalImages: state.totalImages,
                progress: state.progress,
                streamPreview: state.streamPreview,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                enableSelection: false,
              );
            }

            // 已完成的图像
            final imageBytes = completedImages[index].bytes;
            return SelectableImageCard(
              imageBytes: imageBytes,
              index: index,
              showIndex: true,
              enableSelection: false,
              onTap: () => _showFullscreenImage(imageBytes),
              onUpscale: () => UpscaleDialog.show(context, image: imageBytes),
              onSaveToLibrary: (bytes, _) =>
                  _showSaveToLibraryDialog(context, bytes),
            );
          },
        );
      },
    );
  }

  /// 生成中的居中显示（无已完成图像时）
  Widget _buildSingleGeneratingState(
    BuildContext context,
    ImageGenerationState state,
    ThemeData theme,
    int imageWidth,
    int imageHeight,
  ) {
    final aspectRatio = imageWidth / imageHeight;
    const maxHeight = 400.0;
    const maxWidth = 400.0;

    double cardWidth, cardHeight;
    if (aspectRatio > 1) {
      cardWidth = maxWidth;
      cardHeight = maxWidth / aspectRatio;
    } else {
      cardHeight = maxHeight;
      cardWidth = maxHeight * aspectRatio;
    }

    return Center(
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: SelectableImageCard(
          isGenerating: true,
          currentImage: state.currentImage,
          totalImages: state.totalImages,
          progress: state.progress,
          streamPreview: state.streamPreview,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          enableSelection: false,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          size: 80,
          color: theme.colorScheme.onSurface.withOpacity(0.2),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.generation_emptyPromptHint,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.generation_imageWillShowHere,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
    String? message,
    BuildContext context,
  ) {
    // 解析错误代码和详情
    final (errorTitle, errorHint) = _parseApiError(message, context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          errorTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        if (errorHint != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  /// 解析 API 错误代码，返回 (标题, 提示)
  (String, String?) _parseApiError(String? message, BuildContext context) {
    if (message == null || message.isEmpty) {
      return (context.l10n.generation_generationFailed, null);
    }

    // 取消操作
    if (message == 'Cancelled') {
      return (context.l10n.generation_cancelGeneration, null);
    }

    // 解析错误代码格式: "ERROR_CODE|详情"
    final parts = message.split('|');
    final errorCode = parts[0];
    final details = parts.length > 1 ? parts[1] : null;

    switch (errorCode) {
      case 'API_ERROR_429':
        return (
          context.l10n.api_error_429,
          context.l10n.api_error_429_hint,
        );
      case 'API_ERROR_401':
        return (
          context.l10n.api_error_401,
          context.l10n.api_error_401_hint,
        );
      case 'API_ERROR_402':
        return (
          context.l10n.api_error_402,
          context.l10n.api_error_402_hint,
        );
      case 'API_ERROR_400':
        return (
          '${context.l10n.common_error} (400)',
          details,
        );
      case 'API_ERROR_500':
        return (
          context.l10n.api_error_500,
          context.l10n.api_error_500_hint,
        );
      case 'API_ERROR_503':
        return (
          context.l10n.api_error_503,
          context.l10n.api_error_503_hint,
        );
      case 'API_ERROR_TIMEOUT':
        return (
          context.l10n.api_error_timeout,
          context.l10n.api_error_timeout_hint,
        );
      case 'API_ERROR_NETWORK':
        return (
          context.l10n.api_error_network,
          context.l10n.api_error_network_hint,
        );
      default:
        // 未知错误或其他 HTTP 错误
        if (errorCode.startsWith('API_ERROR_HTTP_')) {
          final code = errorCode.replaceFirst('API_ERROR_HTTP_', '');
          return (
            '${context.l10n.common_error} (HTTP $code)',
            details,
          );
        }
        return (context.l10n.generation_generationFailed, message);
    }
  }

  Widget _buildImageView(
    BuildContext context,
    WidgetRef ref,
    GeneratedImage image,
    ThemeData theme,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 650,
        ),
        child: AspectRatio(
          aspectRatio: image.aspectRatio,
          child: SelectableImageCard(
            imageBytes: image.bytes,
            showIndex: false,
            enableSelection: false,
            onTap: () => _showFullscreenImage(image.bytes),
            onUpscale: () => UpscaleDialog.show(context, image: image.bytes),
            onSaveToLibrary: (bytes, _) =>
                _showSaveToLibraryDialog(context, bytes),
          ),
        ),
      ),
    );
  }

  /// 显示保存到词库对话框
  Future<void> _showSaveToLibraryDialog(
    BuildContext context,
    Uint8List bytes,
  ) async {
    final params = ref.read(generationParamsNotifierProvider);
    final characterConfig = ref.read(characterPromptNotifierProvider);

    // 使用竖线格式合并正面提示词和角色提示词
    final positivePrompt = params.prompt;
    final enabledCharacters = characterConfig.characters
        .where((c) => c.enabled && c.prompt.isNotEmpty)
        .toList();

    final String combinedPrompt;
    if (enabledCharacters.isEmpty) {
      combinedPrompt = positivePrompt;
    } else {
      // 使用竖线格式：主提示词 | 角色1 | 角色2
      final buffer = StringBuffer(positivePrompt);
      for (final char in enabledCharacters) {
        buffer.write('\n| ${char.prompt}');
      }
      combinedPrompt = buffer.toString();
    }

    // 解析别名引用，保存实际内容到词库
    final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
    final resolvedPrompt = aliasResolver.resolveAliases(combinedPrompt);

    final tagLibraryState = ref.read(tagLibraryPageNotifierProvider);

    if (!context.mounted) return;

    await EntryAddDialog.show(
      context,
      categories: tagLibraryState.categories,
      initialContent: resolvedPrompt,
      initialImageBytes: bytes,
    );
  }

  void _showFullscreenImage(Uint8List imageBytes) async {
    final state = ref.read(imageGenerationNotifierProvider);
    final params = ref.read(generationParamsNotifierProvider);
    final characterConfig = ref.read(characterPromptNotifierProvider);

    // 将中央区域显示的所有图像转换为 GeneratedImageDetailData
    // 需要从每张图片中提取实际的 seed 值
    final allImages = <GeneratedImageDetailData>[];
    for (final img in state.displayImages) {
      // 尝试从图片中提取实际的 seed
      int actualSeed = params.seed;
      if (params.seed == -1) {
        final extractedMeta =
            await NaiMetadataParser.extractFromBytes(img.bytes);
        if (extractedMeta != null &&
            extractedMeta.seed != null &&
            extractedMeta.seed! > 0) {
          actualSeed = extractedMeta.seed!;
        }
      }

      allImages.add(
        GeneratedImageDetailData.fromParams(
          imageBytes: img.bytes,
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
          seed: actualSeed,
          steps: params.steps,
          scale: params.scale,
          width: params.width,
          height: params.height,
          model: params.model,
          sampler: params.sampler,
          smea: params.smea,
          smeaDyn: params.smeaDyn,
          noiseSchedule: params.noiseSchedule,
          cfgRescale: params.cfgRescale,
          characterPrompts: characterConfig.characters
              .where((c) => c.enabled && c.prompt.isNotEmpty)
              .map((c) => c.prompt)
              .toList(),
          characterNegativePrompts: characterConfig.characters
              .where((c) => c.enabled)
              .map((c) => c.negativePrompt)
              .toList(),
          id: img.id,
        ),
      );
    }

    // 找到当前点击图像的索引
    final initialIndex = state.displayImages
        .indexWhere((img) => img.bytes == imageBytes)
        .clamp(0, allImages.length - 1);

    if (!mounted) return;

    ImageDetailViewer.show(
      context,
      images: allImages,
      initialIndex: initialIndex,
      showMetadataPanel: true,
      showThumbnails: allImages.length > 1,
      callbacks: ImageDetailCallbacks(
        onSave: (image) => _saveImage(context, image),
      ),
    );
  }

  /// 获取保存目录
  Future<Directory> _getSaveDirectory() async {
    final dir = await LocalGalleryRepository.instance.getImageDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 保存图像
  Future<void> _saveImage(BuildContext context, ImageDetailData image) async {
    try {
      final imageBytes = await image.getImageBytes();
      final saveDir = await _getSaveDirectory();
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');

      final params = ref.read(generationParamsNotifierProvider);
      final characterConfig = ref.read(characterPromptNotifierProvider);

      // 解析别名
      final aliasResolver = ref.read(aliasResolverServiceProvider.notifier);
      final resolvedPrompt = aliasResolver.resolveAliases(params.prompt);
      final resolvedNegative =
          aliasResolver.resolveAliases(params.negativePrompt);

      // 尝试从图片元数据中提取实际的 seed
      int actualSeed = params.seed;
      if (actualSeed == -1) {
        final extractedMeta =
            await NaiMetadataParser.extractFromBytes(imageBytes);
        if (extractedMeta != null &&
            extractedMeta.seed != null &&
            extractedMeta.seed! > 0) {
          actualSeed = extractedMeta.seed!;
        } else {
          actualSeed = Random().nextInt(4294967295);
        }
      }

      // 构建 V4 多角色提示词结构（解析别名）
      final charCaptions = <Map<String, dynamic>>[];
      final charNegCaptions = <Map<String, dynamic>>[];

      for (final char in characterConfig.characters
          .where((c) => c.enabled && c.prompt.isNotEmpty)) {
        charCaptions.add({
          'char_caption': aliasResolver.resolveAliases(char.prompt),
          'centers': [
            {'x': 0.5, 'y': 0.5},
          ],
        });
        charNegCaptions.add({
          'char_caption': aliasResolver.resolveAliases(char.negativePrompt),
          'centers': [
            {'x': 0.5, 'y': 0.5},
          ],
        });
      }

      final commentJson = <String, dynamic>{
        'prompt': resolvedPrompt,
        'uc': resolvedNegative,
        'seed': actualSeed,
        'steps': params.steps,
        'width': params.width,
        'height': params.height,
        'scale': params.scale,
        'uncond_scale': 0.0,
        'cfg_rescale': params.cfgRescale,
        'n_samples': 1,
        'noise_schedule': params.noiseSchedule,
        'sampler': params.sampler,
        'sm': params.smea,
        'sm_dyn': params.smeaDyn,
      };

      if (charCaptions.isNotEmpty) {
        commentJson['v4_prompt'] = {
          'caption': {
            'base_caption': resolvedPrompt,
            'char_captions': charCaptions,
          },
          'use_coords': !characterConfig.globalAiChoice,
          'use_order': true,
        };
        commentJson['v4_negative_prompt'] = {
          'caption': {
            'base_caption': resolvedNegative,
            'char_captions': charNegCaptions,
          },
          'use_coords': false,
          'use_order': false,
        };
      }

      final metadata = {
        'Description': resolvedPrompt,
        'Software': 'NovelAI',
        'Source': _getModelSourceName(params.model),
        'Comment': jsonEncode(commentJson),
      };

      final embeddedBytes = await NaiMetadataParser.embedMetadata(
        imageBytes,
        jsonEncode(metadata),
      );

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

  String _getModelSourceName(String model) {
    if (model.contains('diffusion-4-5')) {
      return 'NovelAI Diffusion V4.5';
    } else if (model.contains('diffusion-4')) {
      return 'NovelAI Diffusion V4';
    } else if (model.contains('diffusion-3')) {
      return 'NovelAI Diffusion V3';
    }
    return 'NovelAI Diffusion';
  }
}
