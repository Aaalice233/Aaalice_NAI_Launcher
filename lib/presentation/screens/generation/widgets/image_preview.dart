import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/image_generation_provider.dart';
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
  Set<int> _selectedIndices = {};
  int _lastImageCount = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageGenerationNotifierProvider);
    final theme = Theme.of(context);

    // 当图片数量变化时，自动全选新增的图片
    if (state.currentImages.length > _lastImageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          // 全选所有图片
          _selectedIndices = Set.from(
            List.generate(state.currentImages.length, (i) => i),
          );
          _lastImageCount = state.currentImages.length;
        });
      });
    } else if (state.currentImages.isEmpty && _lastImageCount > 0) {
      // 清空时重置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedIndices = {};
          _lastImageCount = 0;
        });
      });
    }

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

    // 单抽生成中：居中显示生成卡片
    if (state.isGenerating &&
        state.totalImages == 1 &&
        state.currentImages.isEmpty) {
      final params = ref.watch(generationParamsNotifierProvider);
      return _buildSingleGeneratingState(
        context,
        state,
        theme,
        params.width,
        params.height,
      );
    }

    // 多张图片生成中或已完成多张：显示网格视图
    if (state.isGenerating || state.currentImages.length > 1) {
      final params = ref.watch(generationParamsNotifierProvider);
      return _buildMultiImageView(
        context,
        ref,
        state,
        theme,
        params.width,
        params.height,
      );
    }

    // 单张图片完成
    if (state.hasImages) {
      return _buildImageView(context, ref, state.currentImages.first, theme);
    }

    // 空状态
    return _buildEmptyState(theme, context);
  }

  /// 单抽生成中的居中显示
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

  /// 构建多图网格视图（包含生成中的卡片）
  Widget _buildMultiImageView(
    BuildContext context,
    WidgetRef ref,
    ImageGenerationState state,
    ThemeData theme,
    int imageWidth,
    int imageHeight,
  ) {
    final images = state.currentImages;
    final isGenerating = state.isGenerating;
    final totalItems = isGenerating ? images.length + 1 : images.length;

    return Column(
      children: [
        // 图片网格
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 根据容器大小计算列数
              final crossAxisCount = constraints.maxWidth > 800
                  ? 4
                  : constraints.maxWidth > 500
                      ? 3
                      : 2;

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: imageWidth / imageHeight,
                ),
                itemCount: totalItems,
                itemBuilder: (context, index) {
                  // 最后一个是生成中卡片
                  if (isGenerating && index == images.length) {
                    return _GeneratingImageCard(
                      currentImage: state.currentImage,
                      totalImages: state.totalImages,
                      progress: state.progress,
                      imageWidth: imageWidth,
                      imageHeight: imageHeight,
                      theme: theme,
                      streamPreview: state.streamPreview,
                    );
                  }

                  // 已生成的图片（使用可选择的卡片）
                  return SelectableImageCard(
                    imageBytes: images[index],
                    index: index,
                    isSelected: _selectedIndices.contains(index),
                    onSelectionChanged: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedIndices.add(index);
                        } else {
                          _selectedIndices.remove(index);
                        }
                      });
                    },
                    onFullscreen: () =>
                        _showFullscreenImage(context, images[index]),
                  );
                },
              );
            },
          ),
        ),

        // 底部操作栏（仅当有选中图片时显示）
        if (_selectedIndices.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildMultiImageActions(context, ref, images, theme),
        ],
      ],
    );
  }

  /// 构建多图操作栏
  Widget _buildMultiImageActions(
    BuildContext context,
    WidgetRef ref,
    List<Uint8List> images,
    ThemeData theme,
  ) {
    final selectedCount = _selectedIndices.length;
    final allSelected = selectedCount == images.length;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // 全选/取消全选按钮
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              if (allSelected) {
                _selectedIndices.clear();
              } else {
                _selectedIndices = Set.from(
                  List.generate(images.length, (i) => i),
                );
              }
            });
          },
          icon: Icon(
            allSelected ? Icons.deselect : Icons.select_all,
            size: 20,
          ),
          label: Text(allSelected
              ? context.l10n.common_deselectAll
              : context.l10n.common_selectAll),
        ),
        // 保存选中按钮
        FilledButton.icon(
          onPressed: () => _saveSelectedImages(context, images),
          icon: const Icon(Icons.save_alt, size: 20),
          label: Text('${context.l10n.image_save} ($selectedCount)'),
        ),
      ],
    );
  }

  /// 保存选中的图片
  Future<void> _saveSelectedImages(
      BuildContext context, List<Uint8List> images) async {
    if (_selectedIndices.isEmpty) return;

    try {
      final saveDir = await _getSaveDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final sortedIndices = _selectedIndices.toList()..sort();
      for (int i = 0; i < sortedIndices.length; i++) {
        final index = sortedIndices[i];
        final fileName = 'NAI_${timestamp}_${i + 1}.png';
        final file = File('${saveDir.path}/$fileName');
        await file.writeAsBytes(images[index]);
      }

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
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
      ThemeData theme, String? message, BuildContext context) {
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
          context.l10n.generation_generationFailed,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
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

  Widget _buildImageView(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // 图像显示
        Expanded(
          child: GestureDetector(
            onTap: () => _showFullscreenImage(context, imageBytes),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),

        // 操作按钮
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            // 保存按钮
            FilledButton.icon(
              onPressed: () => _saveImage(context, imageBytes),
              icon: const Icon(Icons.save_alt, size: 20),
              label: Text(context.l10n.image_save),
            ),
            // 复制按钮
            OutlinedButton.icon(
              onPressed: () => _copyImage(context, imageBytes),
              icon: const Icon(Icons.copy, size: 20),
              label: Text(context.l10n.image_copy),
            ),
            // 放大按钮
            OutlinedButton.icon(
              onPressed: () => UpscaleDialog.show(context, image: imageBytes),
              icon: const Icon(Icons.zoom_out_map, size: 20),
              label: Text(context.l10n.image_upscale),
            ),
          ],
        ),
      ],
    );
  }

  /// 获取保存目录
  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      // Android: 保存到外部存储的 Pictures/NAI_Launcher 目录
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // 尝试保存到 Pictures 目录
        final picturesPath = externalDir.path.replaceFirst(
          RegExp(r'/Android/data/[^/]+/files'),
          '/Pictures/NAI_Launcher',
        );
        final picturesDir = Directory(picturesPath);
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }
        return picturesDir;
      }
    }

    // 其他平台或备用: 使用文档目录
    final docDir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${docDir.path}/NAI_Launcher');
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
    return saveDir;
  }

  /// 保存图片到文件
  Future<void> _saveImage(BuildContext context, Uint8List imageBytes) async {
    try {
      final saveDir = await _getSaveDirectory();
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  /// 复制图片到剪贴板
  Future<void> _copyImage(BuildContext context, Uint8List imageBytes) async {
    try {
      await Clipboard.setData(ClipboardData(text: '')); // 清空剪贴板
      // Windows 使用 native 方式复制图片
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/NAI_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);

      // 使用 PowerShell 复制图片到剪贴板
      await Process.run('powershell', [
        '-command',
        'Set-Clipboard -Path "${file.path}"',
      ]);

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_copiedToClipboard);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_copyFailed(e.toString()));
      }
    }
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
class _FullscreenImageView extends StatefulWidget {
  final Uint8List imageBytes;

  const _FullscreenImageView({required this.imageBytes});

  @override
  State<_FullscreenImageView> createState() => _FullscreenImageViewState();
}

class _FullscreenImageViewState extends State<_FullscreenImageView> {
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

  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final picturesPath = externalDir.path.replaceFirst(
          RegExp(r'/Android/data/[^/]+/files'),
          '/Pictures/NAI_Launcher',
        );
        final picturesDir = Directory(picturesPath);
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }
        return picturesDir;
      }
    }

    final docDir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${docDir.path}/NAI_Launcher');
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
    return saveDir;
  }

  Future<void> _saveImage(BuildContext context) async {
    try {
      final saveDir = await _getSaveDirectory();
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(widget.imageBytes);

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
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
    final hasPreview = widget.streamPreview != null && widget.streamPreview!.isNotEmpty;

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
      return _buildPreviewCard(cardWidth, cardHeight, primaryColor, surfaceColor);
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
