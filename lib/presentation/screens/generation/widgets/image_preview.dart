import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_metadata_parser.dart';
import '../../../../data/repositories/local_gallery_repository.dart';
import '../../../providers/character_prompt_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/local_gallery_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/selectable_image_card.dart';
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

    // 生成中：显示生成卡片
    if (state.isGenerating && state.currentImages.isEmpty) {
      final params = ref.watch(generationParamsNotifierProvider);
      return _buildSingleGeneratingState(
        context,
        state,
        theme,
        params.width,
        params.height,
      );
    }

    // 有图像：显示最新一张（固定单图显示，历史在队列中）
    if (state.hasImages) {
      return _buildImageView(context, ref, state.currentImages.first, theme);
    }

    // 空状态
    return _buildEmptyState(theme, context);
  }

  /// 生成中的居中显示
  Widget _buildSingleGeneratingState(
    BuildContext context,
    ImageGenerationState state,
    ThemeData theme,
    int imageWidth,
    int imageHeight,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: 400 * imageHeight / imageWidth,
        ),
        child: _GeneratingImageCard(
          currentImage: state.currentImage,
          totalImages: state.totalImages,
          progress: state.progress,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          theme: theme,
          streamPreview: state.streamPreview,
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
    Uint8List imageBytes,
    ThemeData theme,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 650,
        ),
        child: AspectRatio(
          aspectRatio: ref.watch(generationParamsNotifierProvider).width /
              ref.watch(generationParamsNotifierProvider).height,
          child: SelectableImageCard(
            imageBytes: imageBytes,
            showIndex: false,
            enableSelection: false,
            onTap: () => _showFullscreenImage(context, imageBytes),
            onUpscale: () => UpscaleDialog.show(context, image: imageBytes),
          ),
        ),
      ),
    );
  }

  void _showFullscreenImage(BuildContext context, Uint8List imageBytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenImageView(imageBytes: imageBytes);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}

/// 沉浸式全屏图像查看器
class _FullscreenImageView extends ConsumerStatefulWidget {
  final Uint8List imageBytes;

  const _FullscreenImageView({required this.imageBytes});

  @override
  ConsumerState<_FullscreenImageView> createState() =>
      _FullscreenImageViewState();
}

class _FullscreenImageViewState extends ConsumerState<_FullscreenImageView> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景 + 图像（点击关闭）
          GestureDetector(
            onTap: _close,
            child: Container(
              color: Colors.black.withOpacity(0.95),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // 左上角返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: _buildControlButton(
              icon: Icons.arrow_back_rounded,
              onTap: _close,
              tooltip: context.l10n.common_back,
            ),
          ),

          // 右上角保存按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: _buildControlButton(
              icon: Icons.save_alt_rounded,
              onTap: () => _saveImage(context),
              tooltip: context.l10n.image_save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  /// 获取保存目录（统一使用 LocalGalleryRepository）
  Future<Directory> _getSaveDirectory() async {
    // 使用 LocalGalleryRepository 获取保存目录，保证路径一致性
    final dir = await LocalGalleryRepository.instance.getImageDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _saveImage(BuildContext context) async {
    try {
      final saveDir = await _getSaveDirectory();
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');

      // 获取当前生成参数
      final params = ref.read(generationParamsNotifierProvider);
      final characterConfig = ref.read(characterPromptNotifierProvider);

      // 尝试从 API 返回的图片中提取实际使用的 seed
      int actualSeed = params.seed;
      if (actualSeed == -1) {
        // 尝试从图片元数据中提取实际的 seed
        final extractedMeta =
            await NaiMetadataParser.extractFromBytes(widget.imageBytes);
        if (extractedMeta != null &&
            extractedMeta.seed != null &&
            extractedMeta.seed! > 0) {
          actualSeed = extractedMeta.seed!;
        } else {
          // 如果无法提取，生成随机种子
          actualSeed = Random().nextInt(4294967295);
        }
      }

      // 构建 V4 多角色提示词结构
      final charCaptions = <Map<String, dynamic>>[];
      final charNegCaptions = <Map<String, dynamic>>[];

      for (final char in characterConfig.characters
          .where((c) => c.enabled && c.prompt.isNotEmpty)) {
        charCaptions.add({
          'char_caption': char.prompt,
          'centers': [
            {'x': 0.5, 'y': 0.5},
          ],
        });
        charNegCaptions.add({
          'char_caption': char.negativePrompt,
          'centers': [
            {'x': 0.5, 'y': 0.5},
          ],
        });
      }

      // 构造 NAI Comment 格式的元数据 JSON（与官网格式完全对齐）
      final commentJson = <String, dynamic>{
        'prompt': params.prompt,
        'uc': params.negativePrompt,
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

      // 如果有角色提示词，添加 V4 格式
      if (charCaptions.isNotEmpty) {
        commentJson['v4_prompt'] = {
          'caption': {
            'base_caption': params.prompt,
            'char_captions': charCaptions,
          },
          'use_coords': !characterConfig.globalAiChoice,
          'use_order': true,
        };
        commentJson['v4_negative_prompt'] = {
          'caption': {
            'base_caption': params.negativePrompt,
            'char_captions': charNegCaptions,
          },
          'use_coords': false,
          'use_order': false,
        };
      }

      // 构造完整的官网格式元数据
      final metadata = {
        'Description': params.prompt,
        'Software': 'NovelAI',
        'Source': _getModelSourceName(params.model),
        'Comment': jsonEncode(commentJson),
      };

      // 嵌入元数据
      final embeddedBytes = await NaiMetadataParser.embedMetadata(
        widget.imageBytes,
        jsonEncode(metadata),
      );

      await file.writeAsBytes(embeddedBytes);

      // 通知本地画廊刷新
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

  /// 获取模型的 Source 名称
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

/// 生成中的图像卡片组件 - 支持流式预览
class _GeneratingImageCard extends StatefulWidget {
  final int currentImage;
  final int totalImages;
  final double progress;
  final int imageWidth;
  final int imageHeight;
  final ThemeData theme;

  /// 流式预览图像（渐进式生成中显示）
  final Uint8List? streamPreview;

  const _GeneratingImageCard({
    required this.currentImage,
    required this.totalImages,
    required this.progress,
    required this.imageWidth,
    required this.imageHeight,
    required this.theme,
    this.streamPreview,
  });

  @override
  State<_GeneratingImageCard> createState() => _GeneratingImageCardState();
}

class _GeneratingImageCardState extends State<_GeneratingImageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.1, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.theme.colorScheme.primary;
    final surfaceColor = widget.theme.colorScheme.surface;
    final hasPreview =
        widget.streamPreview != null && widget.streamPreview!.isNotEmpty;

    // 计算卡片尺寸（基于图像比例，限制最大尺寸）
    final aspectRatio = widget.imageWidth / widget.imageHeight;
    const maxHeight = 400.0;
    const maxWidth = 400.0;

    double cardWidth, cardHeight;
    if (aspectRatio > 1) {
      // 横向图
      cardWidth = maxWidth;
      cardHeight = maxWidth / aspectRatio;
    } else {
      // 纵向图或方形
      cardHeight = maxHeight;
      cardWidth = maxHeight * aspectRatio;
    }

    // 如果有流式预览，显示预览图像
    if (hasPreview) {
      return _buildPreviewCard(
        cardWidth,
        cardHeight,
        primaryColor,
        surfaceColor,
      );
    }

    // 否则显示原来的加载动画
    return _buildLoadingCard(cardWidth, cardHeight, primaryColor, surfaceColor);
  }

  /// 构建带预览图像的卡片
  Widget _buildPreviewCard(
    double cardWidth,
    double cardHeight,
    Color primaryColor,
    Color surfaceColor,
  ) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(_glowAnimation.value),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 流式预览图像
            Image.memory(
              widget.streamPreview!,
              fit: BoxFit.cover,
              gaplessPlayback: true, // 平滑过渡，避免闪烁
            ),
            // 半透明遮罩 + 进度指示
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
            // 底部进度信息
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  // 进度环
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: widget.progress > 0 ? widget.progress : null,
                      strokeWidth: 2,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 进度文字
                  Text(
                    '${widget.currentImage}/${widget.totalImages}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 百分比
                  if (widget.progress > 0)
                    Text(
                      '${(widget.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建加载动画卡片（无预览时）
  Widget _buildLoadingCard(
    double cardWidth,
    double cardHeight,
    Color primaryColor,
    Color surfaceColor,
  ) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(_glowAnimation.value),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 进度环 + 图标
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    value: widget.progress > 0 ? widget.progress : null,
                    strokeWidth: 2.5,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    color: primaryColor,
                  ),
                ),
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 22,
                  color: primaryColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 当前 / 总数
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  '${widget.currentImage}',
                  key: ValueKey(widget.currentImage),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: widget.theme.colorScheme.onSurface,
                    height: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 18,
                    color: widget.theme.colorScheme.onSurface.withOpacity(0.25),
                    height: 1,
                  ),
                ),
              ),
              Text(
                '${widget.totalImages}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: widget.theme.colorScheme.onSurface.withOpacity(0.4),
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
