import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/cache/thumbnail_cache_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/services/thumbnail_service.dart';
import '../../themes/theme_extension.dart';
import '../common/app_toast.dart';
import '../common/floating_action_buttons.dart';

enum _ImageLoadState { idle, loading, loaded, error }

/// Steam风格本地图片卡片，包含边缘发光、光泽扫过、悬停动画效果
class LocalImageCard3D extends StatefulWidget {
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
  final VoidCallback? onSendToHome;
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
    this.onSendToHome,
    this.isVisible = false,
    this.priority = 5,
    this.dragWrapper,
  });

  @override
  State<LocalImageCard3D> createState() => _LocalImageCard3DState();
}

class _LocalImageCard3DState extends State<LocalImageCard3D>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isHovered = false;
  late AnimationController _glossController;
  late Animation<double> _glossAnimation;
  String? _thumbnailPath;
  String? _displayPath;
  ThumbnailCacheService? _thumbnailService;
  _ImageLoadState _loadState = _ImageLoadState.idle;
  bool _isLoadingThumbnail = false;

  @override
  bool get wantKeepAlive => true;

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
        AppLogger.e('[CardLoad] Original file NOT FOUND: $path', 'LocalImageCard3D');
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

      // 先显示原图，后台生成缩略图
      // AppLogger.i('[CardLoad] Using original image: $fileName', 'LocalImageCard3D');
      if (mounted) {
        setState(() {
          _displayPath = path;
          _loadState = _ImageLoadState.loaded;
        });
      }

      final thumbnailService = ThumbnailService.instance;
      await thumbnailService.initialize();
      thumbnailService.updateVisibility(
        path,
        isVisible: widget.isVisible,
        priority: widget.priority,
      );

      // 后台生成缩略图（但不切换到缩略图，避免闪烁）
      unawaited(
        thumbnailService
            .getThumbnail(path, size: ThumbnailSize.small, priority: widget.priority)
            .then((generatedPath) {
          if (generatedPath != null && mounted) {
            // AppLogger.i('[CardLoad] Thumbnail generated: $fileName', 'LocalImageCard3D');
            // 只缓存缩略图路径，不切换到缩略图显示，避免图片闪烁
            _thumbnailPath = generatedPath;
          }
        }),
      );
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
    File? tempFile;
    try {
      final sourceFile = File(widget.record.path);
      if (!await sourceFile.exists()) {
        if (mounted) AppToast.error(context, '文件不存在');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/NAI_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(await sourceFile.readAsBytes());

      const psCommand = r'''
Add-Type -AssemblyName System.Windows.Forms;
Add-Type -AssemblyName System.Drawing;
$image = [System.Drawing.Image]::FromFile("''';
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        '$psCommand${tempFile.path}"); [System.Windows.Forms.Clipboard]::SetImage(\$image); \$image.Dispose();',
      ]);

      if (result.exitCode != 0) throw Exception('PowerShell 命令失败');

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) AppToast.success(context, '已复制到剪贴板');
    } catch (e) {
      if (mounted) AppToast.error(context, '复制失败: $e');
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  (_EffectIntensity, Color) _getEffectConfig(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();

    final intensity = switch ((extension?.enableNeonGlow, extension?.isLightTheme)) {
      (true, _) => (edgeGlow: 1.3, gloss: 1.0),
      (_, true) => (edgeGlow: 0.6, gloss: 1.0),
      _ => (edgeGlow: 1.0, gloss: 0.8),
    };

    final glowColor = extension?.glowColor ?? theme.colorScheme.primary;
    return (_EffectIntensity(edgeGlow: intensity.edgeGlow, gloss: intensity.gloss), glowColor);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = theme.colorScheme;
    final (intensity, glowColor) = _getEffectConfig(context);

    Widget cardContent = GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      onSecondaryTapDown: widget.onSecondaryTapDown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
        transformAlignment: Alignment.center,
        child: Container(
          width: widget.width,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
                ? Border.all(color: colorScheme.primary, width: 3)
                : _isHovered
                    ? Border.all(color: colorScheme.primary.withOpacity(0.3), width: 2)
                    : null,
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? Colors.black.withOpacity(0.35)
                    : Colors.black.withOpacity(0.12),
                blurRadius: _isHovered ? 28 : 10,
                offset: Offset(0, _isHovered ? 14 : 4),
                spreadRadius: _isHovered ? 2 : 0,
              ),
              if (_isHovered)
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
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
                          color: colorScheme.primary.withOpacity(0.15),
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

    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      cursor: SystemMouseCursors.click,
      child: cardContent,
    );
  }

  Widget _buildImageLayer() => switch (_loadState) {
        _ImageLoadState.error => _buildErrorPlaceholder(),
        _ImageLoadState.loading when _displayPath == null => _buildLoadingPlaceholder(),
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
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '加载中...',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.red[900]?.withOpacity(0.3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: Colors.red[400], size: 40),
            const SizedBox(height: 8),
            Text('加载失败', style: TextStyle(color: Colors.red[300], fontSize: 12)),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _loadThumbnail,
              icon: Icon(Icons.refresh, color: Colors.red[300], size: 16),
              label: Text('重试', style: TextStyle(color: Colors.red[300], fontSize: 11)),
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

    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return Container(
          color: Colors.grey[850],
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        AppLogger.w('Image load failed, attempting fallback: $imagePath', 'LocalImageCard3D');
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
    return FloatingActionButtons(
      isVisible: _isHovered,
      buttons: [
        FloatingActionButtonData(
          icon: widget.record.isFavorite ? Icons.favorite : Icons.favorite_border,
          onTap: widget.onFavoriteToggle,
          iconColor: widget.record.isFavorite ? Colors.red : Colors.white,
          visible: widget.onFavoriteToggle != null,
        ),
        FloatingActionButtonData(icon: Icons.copy, onTap: _copyImageToClipboard),
        FloatingActionButtonData(
          icon: Icons.send,
          onTap: () => _showSendToHomeMenu(context),
          visible: widget.onSendToHome != null,
        ),
      ],
    );
  }

  void _showSendToHomeMenu(BuildContext context) {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;

    final offset = button.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    const menuWidth = 160.0;
    double left = offset.dx - menuWidth - 8;
    double top = offset.dy;

    if (left < 8) left = offset.dx + button.size.width + 8;
    if (top + 150 > screenSize.height) top = screenSize.height - 150;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      builder: (dialogContext) => _SendToHomeMenu(
        position: Offset(left, top),
        onSendToTxt2Img: widget.onSendToHome != null
            ? () {
                Navigator.of(dialogContext).pop();
                widget.onSendToHome!();
              }
            : null,
        onSendToImg2Img: () {
          Navigator.of(dialogContext).pop();
          AppToast.info(dialogContext, '图生图功能制作中');
        },
        onUpscale: () {
          Navigator.of(dialogContext).pop();
          AppToast.info(dialogContext, '放大功能制作中');
        },
      ),
    );
  }

  Widget _buildSelectionIndicator(ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
            Colors.black.withOpacity(0.85),
            Colors.black.withOpacity(0.4),
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
              if (metadata.seed != null) _buildMetadataChip('Seed: ${metadata.seed}'),
              if (metadata.steps != null) _buildMetadataChip('${metadata.steps} steps'),
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
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
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
        ..color = glowColor.withOpacity(0.12 * intensity * (3 - i) / 3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, (3 - i) * 2.0);

      canvas.drawRRect(innerRRect, paint);
    }

    final borderPaint = Paint()
      ..color = glowColor.withOpacity(0.25 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    canvas.drawRRect(rrect, borderPaint);
    _drawCornerHighlights(canvas, size);
  }

  void _drawCornerHighlights(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = glowColor.withOpacity(0.3 * intensity)
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
    return oldDelegate.glowColor != glowColor || oldDelegate.intensity != intensity;
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
          Colors.white.withOpacity(0.06 * intensity),
          Colors.white.withOpacity(0.15 * intensity),
          Colors.white.withOpacity(0.06 * intensity),
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
          const Color(0xFFB8E6F5).withOpacity(0.03 * intensity),
          const Color(0xFFFFF5E1).withOpacity(0.05 * intensity),
          const Color(0xFFE6B8F5).withOpacity(0.03 * intensity),
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
    return oldDelegate.progress != progress || oldDelegate.intensity != intensity;
  }
}

class _SendToHomeMenu extends StatelessWidget {
  final Offset position;
  final VoidCallback? onSendToTxt2Img;
  final VoidCallback? onSendToImg2Img;
  final VoidCallback? onUpscale;

  const _SendToHomeMenu({
    required this.position,
    this.onSendToTxt2Img,
    this.onSendToImg2Img,
    this.onUpscale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.text_fields,
                    label: '文生图',
                    subtitle: '套用参数',
                    onTap: onSendToTxt2Img,
                  ),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  _buildMenuItem(
                    context,
                    icon: Icons.image,
                    label: '图生图',
                    subtitle: '制作中',
                    enabled: false,
                    onTap: onSendToImg2Img,
                  ),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  _buildMenuItem(
                    context,
                    icon: Icons.zoom_in,
                    label: '放大',
                    subtitle: '制作中',
                    enabled: false,
                    onTap: onUpscale,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final color = enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.38);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.38),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500)),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled ? theme.colorScheme.onSurfaceVariant : color,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
