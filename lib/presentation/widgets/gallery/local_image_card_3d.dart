import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/thumbnail_cache_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/services/thumbnail_service.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../themes/theme_extension.dart';
import '../../utils/clipboard_image.dart';
import '../common/app_toast.dart';
import '../common/floating_action_buttons.dart';
import 'local_image_context_menu.dart';
import 'local_image_hover_preview.dart';

enum _ImageLoadState { idle, loading, loaded, error }

/// Steam风格本地图片卡片，包含边缘发光、光泽扫过、悬停动画效果
class LocalImageCard3D extends ConsumerStatefulWidget {
  final LocalImageRecord record;
  final double width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final bool isSelected;
  final bool showFavoriteIndicator;
  final VoidCallback? onFavoriteToggle;
  final Future<void> Function(LocalImageContextAction action)? onSendAction;
  final bool isKritaConnected;
  final bool isVisible;
  final int priority;

  /// 可选的拖拽包装器，用于将卡片内容包装在 DragItemWidget 中
  /// 解决 GestureDetector 与拖拽手势冲突的问题
  final Widget Function(Widget child)? dragWrapper;

  const LocalImageCard3D({
    super.key,
    required this.record,
    required this.width,
    this.height,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.isSelected = false,
    this.showFavoriteIndicator = true,
    this.onFavoriteToggle,
    this.onSendAction,
    this.isKritaConnected = false,
    this.isVisible = false,
    this.priority = 5,
    this.dragWrapper,
  });

  @override
  ConsumerState<LocalImageCard3D> createState() => _LocalImageCard3DState();
}

class _LocalImageCard3DState extends ConsumerState<LocalImageCard3D>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glossController;
  late Animation<double> _glossAnimation;
  String? _thumbnailPath;
  String? _displayPath;
  ThumbnailCacheService? _thumbnailService;
  _ImageLoadState _loadState = _ImageLoadState.idle;
  bool _isLoadingThumbnail = false;
  bool _isCopyingImage = false;
  bool _suppressCardTap = false;

  @override
  void initState() {
    super.initState();
    _glossController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glossAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _glossController, curve: Curves.easeInOut),
    );
    _initAndLoadThumbnail();
  }

  @override
  void didUpdateWidget(LocalImageCard3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.priority != widget.priority ||
        (oldWidget.isVisible != widget.isVisible && widget.isVisible)) {
      if (_thumbnailPath == null && !_isLoadingThumbnail) {
        _loadThumbnail();
      }
    }
  }

  Future<void> _initAndLoadThumbnail() async {
    _thumbnailService = ThumbnailCacheService.instance;
    await _thumbnailService!.init();
    await _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (_isLoadingThumbnail) return;

    _isLoadingThumbnail = true;
    final path = widget.record.path;
    final fileName = path.split(Platform.pathSeparator).last;

    // 只在调试模式下记录日志，避免影响性能
    // AppLogger.i('[CardLoad] START: $fileName, priority=${widget.priority}', 'LocalImageCard3D');

    try {
      setState(() => _loadState = _ImageLoadState.loading);

      final originalFile = File(path);
      if (!await originalFile.exists()) {
        AppLogger.e(
          '[CardLoad] Original file NOT FOUND: $path',
          'LocalImageCard3D',
        );
        if (mounted) {
          setState(() => _loadState = _ImageLoadState.error);
        }
        return;
      }

      final existingPath = await _thumbnailService?.getThumbnailPath(path);
      if (existingPath != null && await File(existingPath).exists()) {
        // AppLogger.i('[CardLoad] Using existing thumbnail: $fileName', 'LocalImageCard3D');
        if (mounted) {
          setState(() {
            _thumbnailPath = existingPath;
            _displayPath = existingPath;
            _loadState = _ImageLoadState.loaded;
          });
        }
        return;
      }

      final thumbnailService = ThumbnailService.instance;
      await thumbnailService.initialize();
      thumbnailService.updateVisibility(
        path,
        isVisible: widget.isVisible,
        priority: widget.priority,
      );

      final generatedPath = await thumbnailService.getThumbnail(
        path,
        size: ThumbnailSize.small,
        priority: widget.priority,
      );

      if (!mounted || widget.record.path != path) return;

      if (generatedPath != null) {
        setState(() {
          _thumbnailPath = generatedPath;
          _displayPath = generatedPath;
          _loadState = _ImageLoadState.loaded;
        });
      } else {
        setState(() {
          _displayPath = path;
          _loadState = _ImageLoadState.loaded;
        });
      }
    } catch (e, stack) {
      AppLogger.e('[CardLoad] ERROR: $fileName', e, stack, 'LocalImageCard3D');
      if (mounted) {
        setState(() {
          _displayPath = path;
          _loadState = _ImageLoadState.loaded;
        });
      }
    } finally {
      _isLoadingThumbnail = false;
    }
  }

  void _onHoverEnter(PointerEvent event) {
    setState(() => _isHovered = true);
    _glossController.forward(from: 0.0);
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
  }

  Future<void> _copyImageToClipboard() async {
    if (_isCopyingImage) return;
    setState(() => _isCopyingImage = true);

    try {
      final sourceFile = File(widget.record.path);
      if (!await sourceFile.exists()) {
        if (mounted) AppToast.error(context, context.l10n.gallery_fileMissing);
        return;
      }

      final stripMetadata = ref
          .read(shareImageSettingsProvider)
          .effectiveStripMetadataForCopyAndDrag;
      final sourceParts = sourceFile.path.split(RegExp(r'[/\\]'));
      final sourceName =
          sourceParts.isNotEmpty ? sourceParts.last : 'shared.png';
      final originalBytes = await sourceFile.readAsBytes();
      final shareImage =
          await ImageShareSanitizer.prepareForCopyOrDragInBackground(
        originalBytes,
        fileName: sourceName,
        stripMetadata: stripMetadata,
      );

      // 跨平台复制到剪贴板（原 Windows 端走 PowerShell + System.Drawing，
      // macOS/Linux 不可用）。统一规范化为 PNG，避免 jpg/webp 原始字节被当成
      // PNG 导致粘贴失败。
      await writeImageBytesToClipboardAsPng(shareImage.bytes);

      if (mounted) {
        AppToast.success(context, context.l10n.gallery_copiedToClipboard);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.gallery_copyFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _isCopyingImage = false);
    }
  }

  void _handleCardTap() {
    if (_suppressCardTap || _isCopyingImage) return;
    widget.onTap?.call();
  }

  void _releaseActionPointerAfterGesture() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _suppressCardTap = false;
    });
  }

  (_EffectIntensity, Color) _getEffectConfig(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();

    final intensity =
        switch ((extension?.enableNeonGlow, extension?.isLightTheme)) {
      (true, _) => (edgeGlow: 1.3, gloss: 1.0),
      (_, true) => (edgeGlow: 0.6, gloss: 1.0),
      _ => (edgeGlow: 1.0, gloss: 0.8),
    };

    final glowColor = extension?.glowColor ?? theme.colorScheme.primary;
    return (
      _EffectIntensity(edgeGlow: intensity.edgeGlow, gloss: intensity.gloss),
      glowColor
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = theme.colorScheme;
    final (intensity, glowColor) = _getEffectConfig(context);

    Widget cardContent = GestureDetector(
      onTap: widget.onTap == null ? null : _handleCardTap,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      onSecondaryTapDown: widget.onSecondaryTapDown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..scaleByDouble(
            _isHovered ? 1.03 : 1.0,
            _isHovered ? 1.03 : 1.0,
            _isHovered ? 1.03 : 1.0,
            1,
          ),
        transformAlignment: Alignment.center,
        child: Container(
          width: widget.width,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(color: colorScheme.primary, width: 3)
                : _isHovered
                    ? Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      )
                    : null,
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.12),
                blurRadius: _isHovered ? 28 : 10,
                offset: Offset(0, _isHovered ? 14 : 4),
                spreadRadius: _isHovered ? 2 : 0,
              ),
              if (_isHovered)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: -4,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImageLayer(),
                if (_isHovered)
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      builder: (context, value, child) => _EdgeGlowOverlay(
                        glowColor: glowColor,
                        intensity: value * intensity.edgeGlow,
                      ),
                    ),
                  ),
                if (_isHovered)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _glossAnimation,
                        builder: (context, child) => _GlossOverlay(
                          progress: _glossAnimation.value,
                          intensity: intensity.gloss,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildActionButtons(),
                ),
                if (widget.isSelected)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildSelectionIndicator(colorScheme),
                  ),
                if (widget.isSelected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (_isHovered && widget.record.metadata != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildMetadataPreview(theme),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // 如果提供了 dragWrapper，使用它包装卡片内容
    // 这样 DragItemWidget 可以正确接收拖拽手势
    if (widget.dragWrapper != null) {
      cardContent = widget.dragWrapper!(cardContent);
    }

    return LocalImageHoverPreview(
      record: widget.record,
      child: MouseRegion(
        onEnter: _onHoverEnter,
        onExit: _onHoverExit,
        cursor: SystemMouseCursors.click,
        child: cardContent,
      ),
    );
  }

  Widget _buildImageLayer() => switch (_loadState) {
        _ImageLoadState.error => _buildErrorPlaceholder(),
        _ImageLoadState.loading when _displayPath == null =>
          _buildLoadingPlaceholder(),
        _ when _displayPath != null => _buildOptimizedImage(_displayPath!),
        _ => _buildLoadingPlaceholder(),
      };

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[850],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.common_loading,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.red[900]?.withValues(alpha: 0.3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: Colors.red[400], size: 40),
            const SizedBox(height: 8),
            Text(
              context.l10n.onlineGallery_loadFailed,
              style: TextStyle(color: Colors.red[300], fontSize: 12),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _loadThumbnail,
              icon: Icon(Icons.refresh, color: Colors.red[300], size: 16),
              label: Text(
                context.l10n.common_retry,
                style: TextStyle(color: Colors.red[300], fontSize: 11),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizedImage(String imagePath) {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.width * pixelRatio * 1.5).toInt();
    final cacheHeight =
        ((widget.height ?? widget.width) * pixelRatio * 1.5).toInt();

    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return Container(
          color: Colors.grey[850],
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white38,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        AppLogger.w(
          'Image load failed, attempting fallback: $imagePath',
          'LocalImageCard3D',
        );
        return _buildErrorFallback(imagePath);
      },
    );
  }

  Widget _buildErrorFallback(String failedPath) {
    if (failedPath != widget.record.path) {
      return Image.file(
        File(widget.record.path),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
      );
    }
    return _buildErrorPlaceholder();
  }

  Widget _buildActionButtons() {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _suppressCardTap = true,
      onPointerUp: (_) => _releaseActionPointerAfterGesture(),
      onPointerCancel: (_) => _releaseActionPointerAfterGesture(),
      child: FloatingActionButtons(
        isVisible: _isHovered,
        axis: Axis.horizontal,
        spacing: 6,
        padding: const EdgeInsets.all(4),
        buttons: [
          FloatingActionButtonData(
            icon: widget.record.isFavorite
                ? Icons.favorite
                : Icons.favorite_border,
            onTap: widget.onFavoriteToggle,
            iconColor: widget.record.isFavorite ? Colors.red : Colors.white,
            visible: widget.onFavoriteToggle != null,
          ),
          FloatingActionButtonData(
            icon: Icons.copy,
            onTap: _copyImageToClipboard,
            isLoading: _isCopyingImage,
            tooltip: context.l10n.shortcut_action_copy_image,
          ),
          FloatingActionButtonData(
            icon: Icons.text_snippet_outlined,
            onTap: () => unawaited(
              widget.onSendAction?.call(LocalImageContextAction.copyPrompt),
            ),
            tooltip: context.l10n.localGallery_copyPrompt,
            visible: widget.onSendAction != null,
          ),
          FloatingActionButtonData(
            icon: Icons.delete_outline,
            onTap: () => unawaited(
              widget.onSendAction?.call(LocalImageContextAction.delete),
            ),
            hoverIconColor: Colors.white,
            hoverBackgroundColor: Colors.red.shade700,
            tooltip: context.l10n.common_delete,
            visible: widget.onSendAction != null,
          ),
          FloatingActionButtonData(
            icon: Icons.send,
            onTap: () => unawaited(_showSendMenu(context)),
            tooltip: context.l10n.detail_sendToImg2Img,
            visible: widget.onSendAction != null,
          ),
        ],
      ),
    );
  }

  Future<void> _showSendMenu(BuildContext context) async {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;

    final offset = button.localToGlobal(Offset.zero);
    const menuWidth = 320.0;
    double left = offset.dx - menuWidth - 8;
    final top = offset.dy;

    if (left < 8) left = offset.dx + button.size.width + 8;

    final action = await LocalImageContextMenu.showSendActions(
      context,
      position: Offset(left, top),
      isKritaConnected: widget.isKritaConnected,
    );
    if (action == null || !mounted) return;

    await widget.onSendAction?.call(action);
  }

  Widget _buildSelectionIndicator(ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.check, color: colorScheme.onPrimary, size: 18),
      ),
    );
  }

  Widget _buildMetadataPreview(ThemeData theme) {
    final metadata = widget.record.metadata;
    if (metadata == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metadata.model != null)
            Text(
              metadata.model!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              if (metadata.seed != null)
                _buildMetadataChip('Seed: ${metadata.seed}'),
              if (metadata.steps != null)
                _buildMetadataChip('${metadata.steps} steps'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child:
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }

  @override
  void dispose() {
    _glossController.dispose();
    super.dispose();
  }
}

class _EffectIntensity {
  final double edgeGlow;
  final double gloss;

  const _EffectIntensity({required this.edgeGlow, required this.gloss});
}

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

class _EdgeGlowPainter extends CustomPainter {
  final Color glowColor;
  final double intensity;

  _EdgeGlowPainter({required this.glowColor, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    for (int i = 0; i < 3; i++) {
      final inset = (i + 1) * 1.5;
      final innerRRect = RRect.fromRectAndRadius(
        rect.deflate(inset),
        Radius.circular(math.max(0, 12 - inset)),
      );

      final paint = Paint()
        ..color = glowColor.withValues(alpha: 0.12 * intensity * (3 - i) / 3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (3 - i) * 2.0);

      canvas.drawRRect(innerRRect, paint);
    }

    final borderPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.25 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    canvas.drawRRect(rrect, borderPaint);
    _drawCornerHighlights(canvas, size);
  }

  void _drawCornerHighlights(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = glowColor.withValues(alpha: 0.3 * intensity)
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
      canvas.drawCircle(corner, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgeGlowPainter oldDelegate) {
    return oldDelegate.glowColor != glowColor ||
        oldDelegate.intensity != intensity;
  }
}

class _GlossOverlay extends StatelessWidget {
  final double progress;
  final double intensity;

  const _GlossOverlay({required this.progress, this.intensity = 1.0});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlossPainter(progress: progress, intensity: intensity),
      ),
    );
  }
}

class _GlossPainter extends CustomPainter {
  final double progress;
  final double intensity;

  _GlossPainter({required this.progress, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final mainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.06 * intensity),
          Colors.white.withValues(alpha: 0.15 * intensity),
          Colors.white.withValues(alpha: 0.06 * intensity),
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

    final pearlPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          const Color(0xFFB8E6F5).withValues(alpha: 0.03 * intensity),
          const Color(0xFFFFF5E1).withValues(alpha: 0.05 * intensity),
          const Color(0xFFE6B8F5).withValues(alpha: 0.03 * intensity),
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
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}
