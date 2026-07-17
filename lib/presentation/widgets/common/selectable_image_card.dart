import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/image/image_stream_chunk.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../themes/theme_extension.dart';
import '../../utils/clipboard_image.dart';
import 'pro_context_menu.dart';
import 'app_toast.dart';
import 'decoded_memory_image.dart';

typedef ImageClipboardWriter = Future<void> Function(Uint8List bytes);

final imageClipboardWriterProvider = Provider<ImageClipboardWriter>(
  (ref) => writeImageBytesToClipboardAsPng,
);

/// 可选择的图像卡片组件
///
/// 支持：
/// - 悬浮时显示操作按钮（保存、复制、放大）
/// - 边缘发光效果
/// - 光泽扫过动画（闪卡效果）
/// - 悬浮时轻微放大和阴影增强
/// - 生成中状态（流式预览、进度显示）
class SelectableImageCard extends ConsumerStatefulWidget {
  /// 图像数据（生成完成时必须提供，生成中时可为空）
  final Uint8List? imageBytes;
  final int? index;
  final bool isSelected;
  final bool showIndex;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onFullscreen;

  /// 是否启用右键菜单
  final bool enableContextMenu;

  /// 是否启用悬浮放大效果
  final bool enableHoverScale;

  /// 是否启用闪卡效果（边缘发光+光泽扫过）
  final bool enableGlossEffect;

  /// 是否启用悬浮状态下的视觉效果和操作栏
  final bool hoverEffectsEnabled;

  /// 是否允许卡片在悬浮时预热复制/拖拽缓存
  final bool shareWarmupEnabled;

  /// Whether save actions should be shown on hover and context menu.
  final bool enableSaveAction;

  /// Whether copy actions should be shown on hover and context menu.
  final bool enableCopyAction;

  /// Optional badge for read-only or special image states.
  final String? statusBadgeLabel;

  /// Optional tooltip for [statusBadgeLabel].
  final String? statusBadgeTooltip;

  /// 拖拽缓存是否已经准备完成。
  ///
  /// 历史面板会在缓存未准备好时禁用拖拽，并在预览图左下角保持
  /// 小环形进度和百分比，直到缓存可拖拽后再恢复正常图片卡片。
  final bool dragPreparationReady;

  /// 完成图第一帧解码前保留的上一张流式预览，避免生成态切完成态时闪空。
  final Uint8List? completionPlaceholderBytes;

  /// 完成图首帧已经显示，可以清理上一帧预览占位缓存。
  final VoidCallback? onCompletionPlaceholderSettled;

  /// 是否启用选择框
  final bool enableSelection;

  /// 放大回调（用于单图显示放大按钮）
  final VoidCallback? onUpscale;

  /// 发送到反推回调
  final VoidCallback? onReversePrompt;

  /// 发送到图生图回调
  final VoidCallback? onImageToImage;

  /// 发送到风格迁移回调
  final VoidCallback? onVibeTransfer;

  /// 发送到精准参考回调
  final VoidCallback? onPreciseReference;

  /// 编辑图像回调
  final VoidCallback? onEditImage;

  /// 局部重绘回调
  final VoidCallback? onInpaint;

  /// 生成变体回调
  final VoidCallback? onGenerateVariations;

  /// 发送到导演工具回调
  final VoidCallback? onDirectorTools;

  /// 发送到增强回调
  final VoidCallback? onEnhance;

  /// 发送到 Krita 回调
  final VoidCallback? onSendToKrita;

  /// 在文件夹中打开的回调（需要先保存图片）
  final VoidCallback? onOpenInExplorer;

  /// 已保存源文件路径（用于复制/拖拽时复用源文件，避免重复写临时文件）。
  final String? sourceFilePath;

  /// 保存到词库的回调（传入图像字节和合并后的提示词）
  final void Function(Uint8List imageBytes, String prompt)? onSaveToLibrary;

  /// 是否已被本地画廊收藏。
  final bool isFavorite;

  /// 切换本地画廊收藏状态。
  final VoidCallback? onFavoriteToggle;

  // ========== 生成中状态相关参数 ==========

  /// 是否处于生成中状态
  final bool isGenerating;

  /// 生成进度 (0.0-1.0)
  final double? progress;

  /// 当前第几张图像 (1-based)
  final int? currentImage;

  /// 总共几张图像
  final int? totalImages;

  /// 流式预览图像（渐进式生成中显示）
  final Uint8List? streamPreview;

  /// Focused inpaint 流式预览在原图上的覆盖位置。
  final FocusedStreamPreviewPlacement? focusedPreviewPlacement;

  /// 图像宽度（用于计算比例，生成中状态需要）
  final int? imageWidth;

  /// 图像高度（用于计算比例，生成中状态需要）
  final int? imageHeight;

  const SelectableImageCard({
    super.key,
    this.imageBytes,
    this.index,
    this.isSelected = false,
    this.showIndex = true,
    this.onTap,
    this.onSelectionChanged,
    this.onFullscreen,
    this.enableContextMenu = true,
    this.enableHoverScale = true,
    this.enableGlossEffect = true,
    this.hoverEffectsEnabled = true,
    this.shareWarmupEnabled = true,
    this.enableSaveAction = true,
    this.enableCopyAction = true,
    this.statusBadgeLabel,
    this.statusBadgeTooltip,
    this.dragPreparationReady = true,
    this.completionPlaceholderBytes,
    this.onCompletionPlaceholderSettled,
    this.enableSelection = true,
    this.onUpscale,
    this.onReversePrompt,
    this.onImageToImage,
    this.onVibeTransfer,
    this.onPreciseReference,
    this.onEditImage,
    this.onInpaint,
    this.onGenerateVariations,
    this.onDirectorTools,
    this.onEnhance,
    this.onSendToKrita,
    this.onOpenInExplorer,
    this.sourceFilePath,
    this.onSaveToLibrary,
    this.isFavorite = false,
    this.onFavoriteToggle,
    // 生成中状态参数
    this.isGenerating = false,
    this.progress,
    this.currentImage,
    this.totalImages,
    this.streamPreview,
    this.focusedPreviewPlacement,
    this.imageWidth,
    this.imageHeight,
  }) : assert(
         !isGenerating || (imageWidth != null && imageHeight != null),
         'imageWidth and imageHeight are required when isGenerating is true',
       );

  @override
  ConsumerState<SelectableImageCard> createState() =>
      _SelectableImageCardState();
}

class _SelectableImageCardState extends ConsumerState<SelectableImageCard>
    with TickerProviderStateMixin {
  static const double _dragPreparationProgressValue = 0.96;
  static const Duration _dragPreparationOverlayFadeDuration = Duration(
    milliseconds: 140,
  );
  static const Duration _completionPlaceholderFallbackDuration = Duration(
    milliseconds: 900,
  );

  bool _isHovering = false;
  late bool _showPreparedIndexBadge;
  late bool _completedImageHasFrame;
  bool _completionPlaceholderSettledNotified = false;
  Uint8List? _precachingCompletedImageBytes;
  Uint8List? _lastStreamPreviewBytes;
  Timer? _completionPlaceholderFallbackTimer;
  late AnimationController _glossController;
  late Animation<double> _glossAnimation;

  // 生成中状态的发光动画
  AnimationController? _glowController;
  Animation<double>? _glowAnimation;

  // 防止重复点击打开多个详情页
  bool _isTapping = false;
  ShareImageTransferCache? _shareTransferCache;

  @override
  void initState() {
    super.initState();
    _lastStreamPreviewBytes = widget.streamPreview?.isNotEmpty == true
        ? widget.streamPreview
        : null;
    _showPreparedIndexBadge = widget.dragPreparationReady;
    _completedImageHasFrame = _effectiveCompletionPlaceholderBytes == null;
    _scheduleCompletionPlaceholderFallback();
    _glossController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glossAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _glossController, curve: Curves.easeInOut),
    );

    // 如果是生成中状态，初始化发光动画
    if (widget.isGenerating) {
      _initGlowAnimation();
    }
    _shareTransferCache = _createShareTransferCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleCompletedImagePrecache();
  }

  void _initGlowAnimation() {
    _glowController?.dispose();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.1, end: 0.35).animate(
      CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(SelectableImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 状态变化时管理发光动画
    if (widget.isGenerating && !oldWidget.isGenerating) {
      _initGlowAnimation();
    } else if (!widget.isGenerating && oldWidget.isGenerating) {
      _glowController?.dispose();
      _glowController = null;
      _glowAnimation = null;
    }

    if (widget.streamPreview?.isNotEmpty == true) {
      _lastStreamPreviewBytes = widget.streamPreview;
    }

    if (oldWidget.imageBytes != widget.imageBytes ||
        oldWidget.sourceFilePath != widget.sourceFilePath) {
      final previousCache = _shareTransferCache;
      _shareTransferCache = _createShareTransferCache();
      if (previousCache != null) {
        unawaited(previousCache.dispose());
      }
    }

    if (oldWidget.imageBytes != widget.imageBytes ||
        oldWidget.completionPlaceholderBytes !=
            widget.completionPlaceholderBytes ||
        (oldWidget.isGenerating && !widget.isGenerating)) {
      _completedImageHasFrame = _effectiveCompletionPlaceholderBytes == null;
      _completionPlaceholderSettledNotified = false;
      _precachingCompletedImageBytes = null;
      _scheduleCompletionPlaceholderFallback();
      _scheduleCompletedImagePrecache();
    }

    if ((!widget.hoverEffectsEnabled || !widget.dragPreparationReady) &&
        _isHovering) {
      _isHovering = false;
    }

    if (!widget.dragPreparationReady ||
        (!oldWidget.dragPreparationReady && widget.dragPreparationReady)) {
      _showPreparedIndexBadge = false;
    }
  }

  @override
  void dispose() {
    _glossController.dispose();
    _glowController?.dispose();
    _completionPlaceholderFallbackTimer?.cancel();
    final cache = _shareTransferCache;
    if (cache != null) {
      unawaited(cache.dispose());
    }
    super.dispose();
  }

  void _onHoverEnter() {
    if (widget.shareWarmupEnabled) {
      _warmShareTransferCache();
    }
    if (!widget.hoverEffectsEnabled || !widget.dragPreparationReady) {
      return;
    }
    setState(() => _isHovering = true);
    if (widget.enableGlossEffect) {
      _glossController.forward(from: 0.0);
    }
  }

  void _onHoverExit() {
    if (!widget.hoverEffectsEnabled && !_isHovering) {
      return;
    }
    setState(() => _isHovering = false);
  }

  Uint8List? get _effectiveCompletionPlaceholderBytes {
    if (widget.isGenerating || widget.imageBytes == null) {
      return null;
    }
    return widget.completionPlaceholderBytes ?? _lastStreamPreviewBytes;
  }

  void _scheduleCompletedImagePrecache() {
    final imageBytes = widget.imageBytes;
    if (imageBytes == null ||
        _effectiveCompletionPlaceholderBytes == null ||
        _completedImageHasFrame ||
        identical(_precachingCompletedImageBytes, imageBytes)) {
      return;
    }

    _precachingCompletedImageBytes = imageBytes;
    unawaited(
      precacheImage(MemoryImage(imageBytes), context).then((_) {
        if (!mounted ||
            !identical(_precachingCompletedImageBytes, imageBytes)) {
          return;
        }
        _markCompletedImageReady();
      }),
    );
  }

  void _scheduleCompletionPlaceholderFallback() {
    _completionPlaceholderFallbackTimer?.cancel();
    if (_effectiveCompletionPlaceholderBytes == null ||
        _completedImageHasFrame) {
      return;
    }

    _completionPlaceholderFallbackTimer = Timer(
      _completionPlaceholderFallbackDuration,
      () {
        if (!mounted) {
          return;
        }
        _markCompletedImageReady();
      },
    );
  }

  void _markCompletedImageReady() {
    if (_completedImageHasFrame) {
      return;
    }
    _completionPlaceholderFallbackTimer?.cancel();
    _completionPlaceholderFallbackTimer = null;
    setState(() {
      _completedImageHasFrame = true;
      _lastStreamPreviewBytes = null;
    });
    if (!_completionPlaceholderSettledNotified) {
      _completionPlaceholderSettledNotified = true;
      widget.onCompletionPlaceholderSettled?.call();
    }
  }

  Widget _buildCompletedImageFrame(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if ((frame != null || wasSynchronouslyLoaded) && !_completedImageHasFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _completedImageHasFrame) {
          return;
        }
        _markCompletedImageReady();
      });
    }
    return child;
  }

  /// 获取边缘发光颜色
  Color _getGlowColor(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();
    return extension?.glowColor ?? theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 生成中状态使用专用的构建方法
    if (widget.isGenerating) {
      return _buildGeneratingCard(context, theme);
    }

    // 正常的已完成图像卡片
    return _buildCompletedCard(context, theme);
  }

  /// 构建生成中状态的卡片
  Widget _buildGeneratingCard(BuildContext context, ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final hasPreview =
        widget.streamPreview != null && widget.streamPreview!.isNotEmpty;

    // 如果有流式预览，显示预览图像
    if (hasPreview) {
      return _buildPreviewCard(primaryColor, surfaceColor, theme);
    }

    // 否则显示加载动画
    return _buildLoadingCard(primaryColor, surfaceColor, theme);
  }

  /// 构建带预览图像的生成中卡片
  Widget _buildPreviewCard(
    Color primaryColor,
    Color surfaceColor,
    ThemeData theme,
  ) {
    final progress = widget.progress ?? 0.0;
    final currentImage = widget.currentImage ?? 0;
    final totalImages = widget.totalImages ?? 0;

    return AnimatedBuilder(
      animation: _glowAnimation ?? const AlwaysStoppedAnimation(0.2),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(
                  alpha: _glowAnimation?.value ?? 0.2,
                ),
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
            _buildStreamPreviewImage(),
            // 半透明遮罩 + 进度指示
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
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
                      value: progress > 0 ? progress : null,
                      strokeWidth: 2,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 进度文字
                  Text(
                    '$currentImage/$totalImages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                  const Spacer(),
                  // 百分比
                  if (progress > 0)
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
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

  Widget _buildStreamPreviewImage() {
    final focusedPreviewPlacement = widget.focusedPreviewPlacement;
    if (focusedPreviewPlacement == null || !focusedPreviewPlacement.isValid) {
      return DecodedMemoryImage(
        bytes: widget.streamPreview!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    if (focusedPreviewPlacement.hasMask) {
      return _FocusedStreamPreviewImage(
        previewImage: widget.streamPreview!,
        placement: focusedPreviewPlacement,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return DecodedMemoryImage(
            bytes: widget.streamPreview!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }

        final xPercent = focusedPreviewPlacement.xPercent
            .clamp(0.0, 1.0)
            .toDouble();
        final yPercent = focusedPreviewPlacement.yPercent
            .clamp(0.0, 1.0)
            .toDouble();
        final widthPercent = focusedPreviewPlacement.widthPercent
            .clamp(0.0, 1.0 - xPercent)
            .toDouble();
        final heightPercent = focusedPreviewPlacement.heightPercent
            .clamp(0.0, 1.0 - yPercent)
            .toDouble();
        final overlayWidth = math.max(1.0, constraints.maxWidth * widthPercent);
        final overlayHeight = math.max(
          1.0,
          constraints.maxHeight * heightPercent,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            DecodedMemoryImage(
              bytes: focusedPreviewPlacement.sourceImage,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            Positioned(
              left: constraints.maxWidth * xPercent,
              top: constraints.maxHeight * yPercent,
              width: overlayWidth,
              height: overlayHeight,
              child: ClipRect(
                child: DecodedMemoryImage(
                  bytes: widget.streamPreview!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建加载动画卡片（无预览时）
  Widget _buildLoadingCard(
    Color primaryColor,
    Color surfaceColor,
    ThemeData theme, {
    double? progressOverride,
    int? currentImageOverride,
    int? totalImagesOverride,
    Key? progressKey,
  }) {
    final progress = progressOverride ?? widget.progress ?? 0.0;
    final currentImage = currentImageOverride ?? widget.currentImage ?? 0;
    final totalImages = totalImagesOverride ?? widget.totalImages ?? 0;

    return AnimatedBuilder(
      animation: _glowAnimation ?? const AlwaysStoppedAnimation(0.2),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(
                  alpha: _glowAnimation?.value ?? 0.2,
                ),
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
                    key: progressKey,
                    value: progress > 0 ? progress : null,
                    strokeWidth: 2.5,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    color: primaryColor,
                  ),
                ),
                Icon(Icons.auto_awesome_rounded, size: 22, color: primaryColor),
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
                  '$currentImage',
                  key: ValueKey(currentImage),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                    height: 1,
                  ),
                ),
              ),
              Text(
                '$totalImages',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建已完成状态的卡片
  Widget _buildCompletedCard(BuildContext context, ThemeData theme) {
    final glowColor = _getGlowColor(context);

    // 确保有图像数据
    if (widget.imageBytes == null) {
      return const SizedBox.shrink();
    }
    final showIndexBadge =
        widget.dragPreparationReady &&
        _showPreparedIndexBadge &&
        widget.showIndex &&
        widget.index != null &&
        !_isHovering;
    final indexLabel = widget.index == null ? '' : '${widget.index! + 1}';
    final completionPlaceholderBytes = _effectiveCompletionPlaceholderBytes;
    final showCompletionPlaceholder =
        completionPlaceholderBytes != null && !_completedImageHasFrame;

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // 防止重复点击
          if (_isTapping) return;
          _isTapping = true;

          final callback = widget.onTap ?? widget.onFullscreen;
          if (callback != null) {
            callback();
          }

          // 延迟重置标志，防止快速连续点击
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() => _isTapping = false);
            }
          });
        },
        onSecondaryTapDown: widget.enableContextMenu
            ? (details) {
                unawaited(_showContextMenu(context, details.globalPosition));
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.diagonal3Values(
            widget.enableHoverScale && _isHovering ? 1.03 : 1.0,
            widget.enableHoverScale && _isHovering ? 1.03 : 1.0,
            1.0,
          ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 3)
                : (_isHovering
                      ? Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          width: 2,
                        )
                      : null),
            boxShadow: [
              // 主阴影
              BoxShadow(
                color: widget.isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                    : (_isHovering
                          ? Colors.black.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.12)),
                blurRadius: widget.isSelected ? 16 : (_isHovering ? 28 : 10),
                offset: Offset(0, _isHovering ? 14 : 4),
                spreadRadius: _isHovering ? 2 : 0,
              ),
              // 次阴影（悬浮时增加深度感）
              if (_isHovering)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: -4,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. 图片层
                if (showCompletionPlaceholder)
                  RepaintBoundary(
                    child: DecodedMemoryImage(
                      key: const ValueKey(
                        'completed-image-preview-placeholder',
                      ),
                      bytes: completionPlaceholderBytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                RepaintBoundary(
                  child: DecodedMemoryImage(
                    key: const ValueKey('selectable-image-completed-image'),
                    bytes: widget.imageBytes!,
                    fit: BoxFit.cover,
                    frameBuilder: _buildCompletedImageFrame,
                  ),
                ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      key: const ValueKey(
                        'drag-preparation-preview-overlay-opacity',
                      ),
                      duration: _dragPreparationOverlayFadeDuration,
                      curve: Curves.easeOutCubic,
                      opacity: widget.dragPreparationReady ? 0 : 1,
                      onEnd: () {
                        if (!mounted ||
                            !widget.dragPreparationReady ||
                            _showPreparedIndexBadge) {
                          return;
                        }
                        setState(() {
                          _showPreparedIndexBadge = true;
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.38),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    key: const ValueKey(
                                      'drag-preparation-preview-progress-ring',
                                    ),
                                    value: _dragPreparationProgressValue,
                                    strokeWidth: 2,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Spacer(),
                                Text(
                                  '${(_dragPreparationProgressValue * 100).toInt()}%',
                                  key: const ValueKey(
                                    'drag-preparation-preview-progress-percent',
                                  ),
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
                  ),
                ),

                // 2. 边缘发光效果（悬浮时）
                if (_isHovering && widget.enableGlossEffect)
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return _EdgeGlowOverlay(
                          glowColor: glowColor,
                          intensity: value,
                        );
                      },
                    ),
                  ),

                // 3. 光泽扫过效果（悬浮时）
                if (_isHovering && widget.enableGlossEffect)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _glossAnimation,
                        builder: (context, child) {
                          return _GlossOverlay(progress: _glossAnimation.value);
                        },
                      ),
                    ),
                  ),

                // 4. 悬浮/选中时的渐变遮罩（使用 IgnorePointer 让点击穿透）
                if (_isHovering || widget.isSelected)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                if (widget.statusBadgeLabel != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildStatusBadge(context),
                  ),

                // 5. 左上角：选择框（悬浮或选中时显示）
                if (widget.enableSelection &&
                    widget.statusBadgeLabel == null &&
                    (_isHovering || widget.isSelected))
                  Positioned(top: 8, left: 8, child: _buildCheckbox(theme)),

                // 5.5 右上角：本地画廊收藏按钮
                if (widget.onFavoriteToggle != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildFavoriteButton(context),
                  ),

                // 6. 操作按钮（悬浮时显示）
                if (_isHovering && _hasHoverActions)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: _buildHoverActionBar(context),
                  ),

                // 7. 左下角：序号
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Offstage(
                    key: const ValueKey(
                      'selectable-image-index-badge-offstage',
                    ),
                    offstage: !showIndexBadge,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        indexLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                // 8. 选中覆盖层（使用 IgnorePointer 让点击穿透）
                if (widget.isSelected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final label = widget.statusBadgeLabel!;

    return Tooltip(
      message: widget.statusBadgeTooltip ?? label,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(BuildContext context) {
    return Tooltip(
      message: widget.isFavorite
          ? context.l10n.common_unfavorite
          : context.l10n.common_favorite,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onFavoriteToggle,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isFavorite
                    ? Colors.redAccent.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.65),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              widget.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: widget.isFavorite ? Colors.redAccent : Colors.white,
              size: 17,
            ),
          ),
        ),
      ),
    );
  }

  /// 悬浮时底部操作栏
  Widget _buildHoverActionBar(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            if (widget.enableSaveAction)
              _HoverActionButton(
                icon: Icons.save_alt_rounded,
                tooltip: context.l10n.image_save,
                onTap: () => _saveImage(context),
                isPrimary: true,
              ),
            if (widget.enableCopyAction)
              _HoverActionButton(
                icon: Icons.copy_rounded,
                tooltip: context.l10n.image_copy,
                onTap: () => _copyImage(context),
              ),
            if (widget.onReversePrompt != null)
              _HoverActionButton(
                icon: Icons.manage_search_rounded,
                tooltip: context.l10n.drop_reversePrompt,
                onTap: widget.onReversePrompt,
              ),
            if (widget.onImageToImage != null)
              _HoverActionButton(
                icon: Icons.image_outlined,
                tooltip: context.l10n.drop_img2img,
                onTap: widget.onImageToImage,
              ),
            if (widget.onVibeTransfer != null)
              _HoverActionButton(
                icon: Icons.palette_outlined,
                tooltip: context.l10n.drop_vibeTransfer,
                onTap: widget.onVibeTransfer,
              ),
            if (widget.onPreciseReference != null)
              _HoverActionButton(
                icon: Icons.center_focus_strong,
                tooltip: context.l10n.drop_characterReference,
                onTap: widget.onPreciseReference,
              ),
            if (widget.onEditImage != null)
              _HoverActionButton(
                icon: Icons.edit_outlined,
                tooltip: context.l10n.img2img_editImage,
                onTap: widget.onEditImage,
              ),
            if (widget.onInpaint != null)
              _HoverActionButton(
                icon: Icons.draw_outlined,
                tooltip: context.l10n.img2img_inpaint,
                onTap: widget.onInpaint,
              ),
            if (widget.onGenerateVariations != null)
              _HoverActionButton(
                icon: Icons.auto_awesome_motion_outlined,
                tooltip: context.l10n.img2img_generateVariations,
                onTap: widget.onGenerateVariations,
              ),
            if (widget.onDirectorTools != null)
              _HoverActionButton(
                icon: Icons.auto_fix_high_outlined,
                tooltip: context.l10n.img2img_directorTools,
                onTap: widget.onDirectorTools,
              ),
            if (widget.onEnhance != null)
              _HoverActionButton(
                icon: Icons.auto_awesome_outlined,
                tooltip: context.l10n.img2img_enhance,
                onTap: widget.onEnhance,
              ),
            if (widget.onUpscale != null)
              _HoverActionButton(
                icon: Icons.zoom_out_map_rounded,
                tooltip: context.l10n.image_upscale,
                onTap: widget.onUpscale,
              ),
            if (widget.onSendToKrita != null)
              _HoverActionButton(
                icon: Icons.brush_outlined,
                tooltip: context.l10n.gallery_sendToKritaAction,
                onTap: widget.onSendToKrita,
              ),
            if (widget.onSaveToLibrary != null)
              _HoverActionButton(
                icon: Icons.bookmark_add_rounded,
                tooltip: context.l10n.image_saveToLibrary,
                onTap: () => _saveToLibrary(context),
              ),
          ],
        ),
      ),
    );
  }

  bool get _hasHoverActions =>
      widget.enableSaveAction ||
      widget.enableCopyAction ||
      widget.onReversePrompt != null ||
      widget.onImageToImage != null ||
      widget.onVibeTransfer != null ||
      widget.onPreciseReference != null ||
      widget.onEditImage != null ||
      widget.onInpaint != null ||
      widget.onGenerateVariations != null ||
      widget.onDirectorTools != null ||
      widget.onEnhance != null ||
      widget.onUpscale != null ||
      widget.onSendToKrita != null ||
      widget.onSaveToLibrary != null;

  Widget _buildCheckbox(ThemeData theme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onSelectionChanged?.call(!widget.isSelected);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: widget.isSelected ? theme.colorScheme.primary : Colors.black45,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : Colors.white70,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.isSelected
            ? Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 18)
            : null,
      ),
    );
  }

  Future<void> _saveImage(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null || rootPath.isEmpty) {
        if (context.mounted) {
          AppToast.error(context, l10n.toast_saveDirNotSet);
        }
        return;
      }

      final saveDir = Directory(rootPath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(widget.imageBytes!);

      if (context.mounted) {
        AppToast.success(context, l10n.toast_savedTo(saveDir.path));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, l10n.image_saveFailed(e.toString()));
      }
    }
  }

  void _copyImage(BuildContext context) {
    _createCopyImageAction(context)();
  }

  VoidCallback _createCopyImageAction(BuildContext context) {
    final l10n = context.l10n;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    final clipboardWriter = ref.read(imageClipboardWriterProvider);
    final cache = _shareTransferCache ?? _createShareTransferCache();
    if (cache != null) {
      _shareTransferCache = cache;
    }

    return () {
      unawaited(
        _copyPreparedImage(
          cache: cache,
          stripMetadata: stripMetadata,
          clipboardWriter: clipboardWriter,
          overlay: overlay,
          l10n: l10n,
        ),
      );
    };
  }

  static Future<void> _copyPreparedImage({
    required ShareImageTransferCache? cache,
    required bool stripMetadata,
    required ImageClipboardWriter clipboardWriter,
    required OverlayState? overlay,
    required AppLocalizations l10n,
  }) async {
    try {
      if (cache == null) {
        throw StateError(l10n.toast_imageDataUnavailable);
      }
      final shareImage = await cache.prepareImage(stripMetadata: stripMetadata);

      // 跨平台复制到剪贴板（原 Windows 端走 PowerShell + System.Drawing，
      // macOS/Linux 不可用）。统一规范化为 PNG 写入，避免 jpg/webp 原始字节
      // 被当成 PNG 导致粘贴失败。
      await clipboardWriter(shareImage.bytes);
      AppToast.successOnOverlay(overlay, l10n.image_copiedToClipboard);
    } catch (e) {
      AppToast.errorOnOverlay(overlay, l10n.image_copyFailed(e.toString()));
    }
  }

  ShareImageTransferCache? _createShareTransferCache() {
    final imageBytes = widget.imageBytes;
    if (imageBytes == null) {
      return null;
    }
    return ShareImageTransferCache(
      imageBytes: imageBytes,
      fileName: 'generated.png',
      sourceFilePath: widget.sourceFilePath,
    );
  }

  void _warmShareTransferCache() {
    final cache = _shareTransferCache;
    if (cache == null) return;
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;
    cache.warmUp(stripMetadata: stripMetadata);
  }

  Future<void> _saveToLibrary(BuildContext context) async {
    if (widget.onSaveToLibrary == null || widget.imageBytes == null) return;

    // 调用保存到词库的回调
    widget.onSaveToLibrary!(widget.imageBytes!, '');
  }

  /// 显示右键菜单
  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final items = <ProMenuItem>[];
    final copyImageAction = widget.enableCopyAction
        ? _createCopyImageAction(context)
        : null;

    void addDividerIfNeeded() {
      if (items.isNotEmpty && !items.last.isDivider) {
        items.add(const ProMenuItem.divider());
      }
    }

    if (widget.enableSaveAction) {
      items.add(
        ProMenuItem(
          id: 'save',
          label: context.l10n.shortcut_action_save_image,
          icon: Icons.save_alt,
          onTap: () => _saveImage(context),
        ),
      );
    }

    if (widget.enableCopyAction) {
      items.add(
        ProMenuItem(
          id: 'copy',
          label: context.l10n.shortcut_action_copy_image,
          icon: Icons.copy,
          onTap: copyImageAction,
        ),
      );
    }

    if (widget.onOpenInExplorer != null) {
      addDividerIfNeeded();
      items.add(
        ProMenuItem(
          id: 'open_folder',
          label: context.l10n.shortcut_action_open_folder,
          icon: Icons.folder_open,
          onTap: widget.onOpenInExplorer!,
        ),
      );
    }

    if (widget.onReversePrompt != null ||
        widget.onImageToImage != null ||
        widget.onVibeTransfer != null ||
        widget.onPreciseReference != null) {
      addDividerIfNeeded();
      if (widget.onReversePrompt != null) {
        items.add(
          ProMenuItem(
            id: 'reverse_prompt',
            label: context.l10n.drop_reversePrompt,
            icon: Icons.manage_search_rounded,
            onTap: widget.onReversePrompt!,
          ),
        );
      }
      if (widget.onImageToImage != null) {
        items.add(
          ProMenuItem(
            id: 'image_to_image',
            label: context.l10n.drop_img2img,
            icon: Icons.image_outlined,
            onTap: widget.onImageToImage!,
          ),
        );
      }
      if (widget.onVibeTransfer != null) {
        items.add(
          ProMenuItem(
            id: 'vibe_transfer',
            label: context.l10n.drop_vibeTransfer,
            icon: Icons.palette_outlined,
            onTap: widget.onVibeTransfer!,
          ),
        );
      }
      if (widget.onPreciseReference != null) {
        items.add(
          ProMenuItem(
            id: 'precise_reference',
            label: context.l10n.drop_characterReference,
            icon: Icons.center_focus_strong,
            onTap: widget.onPreciseReference!,
          ),
        );
      }
    }

    if (widget.onEditImage != null ||
        widget.onInpaint != null ||
        widget.onGenerateVariations != null ||
        widget.onDirectorTools != null ||
        widget.onEnhance != null ||
        widget.onUpscale != null ||
        widget.onSendToKrita != null) {
      addDividerIfNeeded();
      if (widget.onEditImage != null) {
        items.add(
          ProMenuItem(
            id: 'edit_image',
            label: context.l10n.img2img_editImage,
            icon: Icons.edit_outlined,
            onTap: widget.onEditImage!,
          ),
        );
      }
      if (widget.onInpaint != null) {
        items.add(
          ProMenuItem(
            id: 'inpaint',
            label: context.l10n.img2img_inpaint,
            icon: Icons.draw_outlined,
            onTap: widget.onInpaint!,
          ),
        );
      }
      if (widget.onGenerateVariations != null) {
        items.add(
          ProMenuItem(
            id: 'generate_variations',
            label: context.l10n.img2img_generateVariations,
            icon: Icons.auto_awesome_motion_outlined,
            onTap: widget.onGenerateVariations!,
          ),
        );
      }
      if (widget.onDirectorTools != null) {
        items.add(
          ProMenuItem(
            id: 'director_tools',
            label: context.l10n.img2img_directorTools,
            icon: Icons.auto_fix_high_outlined,
            onTap: widget.onDirectorTools!,
          ),
        );
      }
      if (widget.onEnhance != null) {
        items.add(
          ProMenuItem(
            id: 'enhance',
            label: context.l10n.img2img_enhance,
            icon: Icons.auto_awesome_outlined,
            onTap: widget.onEnhance!,
          ),
        );
      }
      if (widget.onUpscale != null) {
        items.add(
          ProMenuItem(
            id: 'upscale',
            label: context.l10n.image_upscale,
            icon: Icons.zoom_out_map_rounded,
            onTap: widget.onUpscale!,
          ),
        );
      }
      if (widget.onSendToKrita != null) {
        items.add(
          ProMenuItem(
            id: 'send_to_krita',
            label: context.l10n.gallery_sendToKritaAction,
            icon: Icons.brush_outlined,
            onTap: widget.onSendToKrita!,
          ),
        );
      }
    }

    if (items.isEmpty) {
      return;
    }

    final navigator = Navigator.of(context);
    final route = _ContextMenuRoute(position: position, items: items);
    final selectedItem = await navigator.push<ProMenuItem>(route);
    await route.completed;
    if (selectedItem == null) {
      return;
    }
    selectedItem.onTap?.call();
  }
}

/// 右键菜单路由
class _ContextMenuRoute extends PopupRoute<ProMenuItem> {
  final Offset position;
  final List<ProMenuItem> items;

  _ContextMenuRoute({required this.position, required this.items});

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      child: Builder(
        builder: (context) {
          final screenSize = MediaQuery.of(context).size;
          const menuWidth = 180.0;
          final menuHeight =
              items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = position.dx;
          double top = position.dy;

          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - 16;
          }

          if (top + menuHeight > screenSize.height) {
            top = screenSize.height - menuHeight - 16;
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  onSelect: (item) {
                    Navigator.of(context).pop(item);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    final scaleAnimation = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(scale: scaleAnimation, child: child),
    );
  }
}

/// 悬浮操作按钮
class _HoverActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _HoverActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isPrimary
                  ? (_isHovered
                        ? primaryColor
                        : primaryColor.withValues(alpha: 0.9))
                  : (_isHovered
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: widget.isPrimary
                  ? Colors.white
                  : (_isHovered
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.8)),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusedStreamPreviewImage extends StatefulWidget {
  const _FocusedStreamPreviewImage({
    required this.previewImage,
    required this.placement,
  });

  final Uint8List previewImage;
  final FocusedStreamPreviewPlacement placement;

  @override
  State<_FocusedStreamPreviewImage> createState() =>
      _FocusedStreamPreviewImageState();
}

class _FocusedStreamPreviewImageState
    extends State<_FocusedStreamPreviewImage> {
  ui.Image? _sourceImage;
  ui.Image? _previewImage;
  ui.Image? _maskImage;
  Uint8List? _sourceBytes;
  Uint8List? _previewBytes;
  Uint8List? _maskBytes;
  int _decodeEpoch = 0;

  @override
  void initState() {
    super.initState();
    _decodeChangedImages();
  }

  @override
  void didUpdateWidget(covariant _FocusedStreamPreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _decodeChangedImages();
  }

  @override
  void dispose() {
    _decodeEpoch++;
    _sourceImage?.dispose();
    _previewImage?.dispose();
    _maskImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sourceImage = _sourceImage;
    final previewImage = _previewImage;
    final maskImage = _maskImage;
    if (sourceImage == null || previewImage == null || maskImage == null) {
      return DecodedMemoryImage(
        bytes: widget.placement.sourceImage,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return CustomPaint(
      painter: _FocusedStreamPreviewPainter(
        sourceImage: sourceImage,
        previewImage: previewImage,
        maskImage: maskImage,
        placement: widget.placement,
      ),
    );
  }

  void _decodeChangedImages() {
    final maskBytes = widget.placement.maskImage;
    if (maskBytes == null || maskBytes.isEmpty) {
      return;
    }

    final sourceChanged = !_sameBytes(
      _sourceBytes,
      widget.placement.sourceImage,
    );
    final previewChanged = !_sameBytes(_previewBytes, widget.previewImage);
    final maskChanged = !_sameBytes(_maskBytes, maskBytes);
    if (!sourceChanged && !previewChanged && !maskChanged) {
      return;
    }

    final epoch = ++_decodeEpoch;
    unawaited(
      Future.wait<ui.Image?>([
        sourceChanged
            ? _decodeUiImage(widget.placement.sourceImage)
            : Future<ui.Image?>.value(_sourceImage),
        previewChanged
            ? _decodeUiImage(widget.previewImage)
            : Future<ui.Image?>.value(_previewImage),
        maskChanged
            ? _decodeUiImage(maskBytes)
            : Future<ui.Image?>.value(_maskImage),
      ]).then((images) {
        if (!mounted || epoch != _decodeEpoch) {
          if (sourceChanged) images[0]?.dispose();
          if (previewChanged) images[1]?.dispose();
          if (maskChanged) images[2]?.dispose();
          return;
        }

        setState(() {
          if (sourceChanged) {
            _sourceImage?.dispose();
            _sourceImage = images[0];
            _sourceBytes = widget.placement.sourceImage;
          }
          if (previewChanged) {
            _previewImage?.dispose();
            _previewImage = images[1];
            _previewBytes = widget.previewImage;
          }
          if (maskChanged) {
            _maskImage?.dispose();
            _maskImage = images[2];
            _maskBytes = maskBytes;
          }
        });
      }),
    );
  }

  static bool _sameBytes(Uint8List? a, Uint8List b) {
    return identical(a, b) || (a != null && listEquals(a, b));
  }

  static Future<ui.Image?> _decodeUiImage(Uint8List bytes) async {
    try {
      return await decodeImageFromList(bytes);
    } catch (_) {
      return null;
    }
  }
}

class _FocusedStreamPreviewPainter extends CustomPainter {
  _FocusedStreamPreviewPainter({
    required this.sourceImage,
    required this.previewImage,
    required this.maskImage,
    required this.placement,
  });

  final ui.Image sourceImage;
  final ui.Image previewImage;
  final ui.Image maskImage;
  final FocusedStreamPreviewPlacement placement;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final imagePaint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = false;
    _drawCoverImage(canvas, sourceImage, Offset.zero & size, imagePaint);

    final xPercent = placement.xPercent.clamp(0.0, 1.0).toDouble();
    final yPercent = placement.yPercent.clamp(0.0, 1.0).toDouble();
    final widthPercent = placement.widthPercent
        .clamp(0.0, 1.0 - xPercent)
        .toDouble();
    final heightPercent = placement.heightPercent
        .clamp(0.0, 1.0 - yPercent)
        .toDouble();
    if (widthPercent <= 0 || heightPercent <= 0) return;

    final overlayRect = Rect.fromLTWH(
      size.width * xPercent,
      size.height * yPercent,
      math.max(1.0, size.width * widthPercent),
      math.max(1.0, size.height * heightPercent),
    );
    final imageSourceRect = Rect.fromLTWH(
      0,
      0,
      previewImage.width.toDouble(),
      previewImage.height.toDouble(),
    );
    final maskSourceRect = Rect.fromLTWH(
      0,
      0,
      maskImage.width.toDouble(),
      maskImage.height.toDouble(),
    );
    final previewPaint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = false;
    final maskPaint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = false
      ..blendMode = BlendMode.dstIn;

    canvas.saveLayer(overlayRect, Paint());
    canvas.drawImageRect(
      previewImage,
      imageSourceRect,
      overlayRect,
      previewPaint,
    );
    canvas.drawImageRect(maskImage, maskSourceRect, overlayRect, maskPaint);
    canvas.restore();
  }

  void _drawCoverImage(
    Canvas canvas,
    ui.Image image,
    Rect outputRect,
    Paint paint,
  ) {
    final inputSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, inputSize, outputRect.size);
    final sourceRect = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & inputSize,
    );
    final destinationRect = Alignment.center.inscribe(
      fitted.destination,
      outputRect,
    );
    canvas.drawImageRect(image, sourceRect, destinationRect, paint);
  }

  @override
  bool shouldRepaint(covariant _FocusedStreamPreviewPainter oldDelegate) {
    return oldDelegate.sourceImage != sourceImage ||
        oldDelegate.previewImage != previewImage ||
        oldDelegate.maskImage != maskImage ||
        oldDelegate.placement.xPercent != placement.xPercent ||
        oldDelegate.placement.yPercent != placement.yPercent ||
        oldDelegate.placement.widthPercent != placement.widthPercent ||
        oldDelegate.placement.heightPercent != placement.heightPercent;
  }
}

/// 边缘发光效果覆盖层
class _EdgeGlowOverlay extends StatelessWidget {
  final Color glowColor;
  final double intensity;

  const _EdgeGlowOverlay({required this.glowColor, this.intensity = 1.0});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EdgeGlowPainter(glowColor: glowColor, intensity: intensity),
      ),
    );
  }
}

/// 边缘发光绘制器
class _EdgeGlowPainter extends CustomPainter {
  final Color glowColor;
  final double intensity;

  _EdgeGlowPainter({required this.glowColor, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // 多层内发光效果
    for (int i = 0; i < 3; i++) {
      final inset = (i + 1) * 1.5;
      final innerRect = rect.deflate(inset);
      final innerRRect = RRect.fromRectAndRadius(
        innerRect,
        Radius.circular(math.max(0, 12 - inset)),
      );

      final opacity = 0.12 * intensity * (3 - i) / 3;
      final blurAmount = (3 - i) * 2.0;

      final paint = Paint()
        ..color = glowColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurAmount);

      canvas.drawRRect(innerRRect, paint);
    }

    // 外部高光边框
    final borderPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.25 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    canvas.drawRRect(rrect, borderPaint);

    // 角落高光点
    _drawCornerHighlights(canvas, size, glowColor, intensity);
  }

  void _drawCornerHighlights(
    Canvas canvas,
    Size size,
    Color color,
    double intensity,
  ) {
    final highlightPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    const radius = 3.0;
    const offset = 16.0;

    final corners = [
      const Offset(offset, offset),
      Offset(size.width - offset, offset),
      Offset(offset, size.height - offset),
      Offset(size.width - offset, size.height - offset),
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, radius, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(_EdgeGlowPainter oldDelegate) {
    return oldDelegate.glowColor != glowColor ||
        oldDelegate.intensity != intensity;
  }
}

/// 光泽扫过效果覆盖层
class _GlossOverlay extends StatelessWidget {
  final double progress;

  const _GlossOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlossPainter(progress: progress),
      ),
    );
  }
}

/// 光泽绘制器
class _GlossPainter extends CustomPainter {
  final double progress;

  _GlossPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // 主光泽层 - 白色高光
    final mainPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.06),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
          ).createShader(
            Rect.fromLTWH(
              size.width * progress - size.width * 0.5,
              size.height * progress - size.height * 0.5,
              size.width,
              size.height,
            ),
          );

    canvas.drawRect(Offset.zero & size, mainPaint);

    // 珠光层 - 微妙的彩色光泽
    final pearlPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              const Color(0xFFB8E6F5).withValues(alpha: 0.03), // 浅青色
              const Color(0xFFFFF5E1).withValues(alpha: 0.05), // 浅金色
              const Color(0xFFE6B8F5).withValues(alpha: 0.03), // 浅紫色
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
          ).createShader(
            Rect.fromLTWH(
              size.width * progress - size.width * 0.6,
              size.height * progress - size.height * 0.6,
              size.width * 1.2,
              size.height * 1.2,
            ),
          )
      ..blendMode = BlendMode.screen;

    canvas.drawRect(Offset.zero & size, pearlPaint);
  }

  @override
  bool shouldRepaint(_GlossPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
