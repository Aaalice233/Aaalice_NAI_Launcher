import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../themes/theme_extension.dart';
import '../../../widgets/common/animated_favorite_button.dart';

/// Steam 风格 Vibe 卡片
///
/// 实现高级视觉效果：
/// - 边缘发光效果
/// - 光泽扫过动画
/// - 悬停时轻微放大和阴影增强
class VibeCard3D extends StatefulWidget {
  final VibeLibraryEntry entry;
  final double width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final bool isSelected;
  final bool showFavoriteIndicator;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSendToGeneration;
  final VoidCallback? onExport;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VibeCard3D({
    super.key,
    required this.entry,
    required this.width,
    this.height,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.isSelected = false,
    this.showFavoriteIndicator = true,
    this.onFavoriteToggle,
    this.onSendToGeneration,
    this.onExport,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<VibeCard3D> createState() => _VibeCard3DState();
}

class _VibeCard3DState extends State<VibeCard3D>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  /// 是否悬停
  bool _isHovered = false;

  /// 光泽动画控制器
  late AnimationController _glossController;

  /// 光泽动画
  late Animation<double> _glossAnimation;

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
  }

  void _onHoverEnter(PointerEvent event) {
    setState(() => _isHovered = true);
    _glossController.forward(from: 0.0);
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
  }

  /// 获取主题适配的效果强度
  _EffectIntensity _getEffectIntensity(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();

    // 根据主题类型调整效果强度
    if (extension?.enableNeonGlow == true) {
      // 霓虹风格：更强的效果
      return const _EffectIntensity(
        holographic: 1.5,
        edgeGlow: 1.3,
        gloss: 1.0,
      );
    } else if (extension?.isLightTheme == true) {
      // 浅色主题：较弱的效果
      return const _EffectIntensity(
        holographic: 0.7,
        edgeGlow: 0.6,
        gloss: 1.0,
      );
    } else {
      // 暗色主题：标准效果
      return const _EffectIntensity(
        holographic: 1.0,
        edgeGlow: 1.0,
        gloss: 0.8,
      );
    }
  }

  /// 获取边缘发光颜色
  Color _getEdgeGlowColor(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();

    // 优先使用主题定义的发光颜色
    if (extension?.glowColor != null) {
      return extension!.glowColor!;
    }

    // 否则使用主题主色
    return theme.colorScheme.primary;
  }

  /// 获取缩略图数据
  Uint8List? get _thumbnailData {
    if (widget.entry.thumbnail != null && widget.entry.thumbnail!.isNotEmpty) {
      return widget.entry.thumbnail;
    }
    if (widget.entry.vibeThumbnail != null &&
        widget.entry.vibeThumbnail!.isNotEmpty) {
      return widget.entry.vibeThumbnail;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = theme.colorScheme;
    final intensity = _getEffectIntensity(context);
    final glowColor = _getEdgeGlowColor(context);

    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
                  ? Border.all(
                      color: colorScheme.primary,
                      width: 3,
                    )
                  : _isHovered
                      ? Border.all(
                          color: colorScheme.primary.withOpacity(0.3),
                          width: 2,
                        )
                      : null,
              boxShadow: [
                // 主阴影
                BoxShadow(
                  color: _isHovered
                      ? Colors.black.withOpacity(0.35)
                      : Colors.black.withOpacity(0.12),
                  blurRadius: _isHovered ? 28 : 10,
                  offset: Offset(
                    0,
                    _isHovered ? 14 : 4,
                  ),
                  spreadRadius: _isHovered ? 2 : 0,
                ),
                // 次阴影（增加深度感）
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
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 图片层 - 使用 RepaintBoundary 隔离
                  RepaintBoundary(
                    child: _buildImage(),
                  ),

                  // 2. 边缘发光效果（仅悬停时，带淡入动画）
                  if (_isHovered)
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return _EdgeGlowOverlay(
                            glowColor: glowColor,
                            intensity: value * intensity.edgeGlow,
                          );
                        },
                      ),
                    ),

                  // 3. 光泽扫过效果（仅悬停时）
                  if (_isHovered)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _glossAnimation,
                          builder: (context, child) {
                            return _GlossOverlay(
                              progress: _glossAnimation.value,
                              intensity: intensity.gloss,
                            );
                          },
                        ),
                      ),
                    ),

                  // 4. 底部渐变遮罩和信息
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 名称
                          Text(
                            widget.entry.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Strength 进度条
                          _buildProgressBar(
                            context,
                            label: context.l10n.vibe_strength,
                            value: widget.entry.strength,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 4),
                          // Info Extracted 进度条
                          _buildProgressBar(
                            context,
                            label: context.l10n.vibe_infoExtracted,
                            value: widget.entry.infoExtracted,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. 收藏按钮（悬停时显示可点击按钮）
                  if (widget.showFavoriteIndicator)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildFavoriteButton(),
                    ),

                  // 6. Bundle 合集标识（优先级更高，显示在左侧）
                  if (widget.entry.isBundle)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.folder_copy,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '合集 · ${widget.entry.bundledVibeCount}个',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  // 7. 预编码标识（仅在非 Bundle 时显示在左侧，否则显示在右侧）
                  else if (widget.entry.isPreEncoded)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 10,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              '预编码',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 8. Bundle 的预编码标识（显示在右侧）
                  if (widget.entry.isBundle && widget.entry.isPreEncoded)
                    Positioned(
                      top: 8,
                      right: 48, // 为收藏按钮留出空间
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 10,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              '预编码',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 9. 选中状态指示器
                  if (widget.isSelected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildSelectionIndicator(colorScheme),
                    ),

                  // 10. 选中覆盖层（使用 IgnorePointer 让点击穿透）
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

                  // 11. 悬停时显示操作按钮
                  if (_isHovered && !widget.isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildActionButtons(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.width * pixelRatio).toInt();

    return Container(
      color: Colors.black.withOpacity(0.05),
      child: _thumbnailData != null
          ? Image.memory(
              _thumbnailData!,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child:
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                );
              },
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                // Show placeholder while loading
                return Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            )
          : Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  widget.entry.isBundle ? Icons.style : Icons.auto_fix_high,
                  size: 32,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
    );
  }

  Widget _buildFavoriteButton() {
    final isFavorite = widget.entry.isFavorite;
    final showButton = _isHovered || isFavorite;

    if (!showButton) return const SizedBox.shrink();

    return CardFavoriteButton(
      isFavorite: isFavorite,
      onToggle: widget.onFavoriteToggle,
      size: 18,
    );
  }

  Widget _buildSelectionIndicator(ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.check,
          color: colorScheme.onPrimary,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onSendToGeneration != null)
          _ActionButton(
            icon: Icons.send,
            tooltip: context.l10n.vibe_reuseButton,
            onTap: widget.onSendToGeneration,
          ),
        if (widget.onExport != null)
          _ActionButton(
            icon: Icons.download,
            tooltip: context.l10n.common_export,
            onTap: widget.onExport,
          ),
        if (widget.onEdit != null)
          _ActionButton(
            icon: Icons.edit,
            tooltip: context.l10n.common_edit,
            onTap: widget.onEdit,
          ),
        if (widget.onDelete != null)
          _ActionButton(
            icon: Icons.delete,
            tooltip: context.l10n.common_delete,
            onTap: widget.onDelete,
            isDanger: true,
          ),
      ],
    );
  }

  Widget _buildProgressBar(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _glossController.dispose();
    super.dispose();
  }
}

/// 效果强度配置
class _EffectIntensity {
  final double holographic;
  final double edgeGlow;
  final double gloss;

  const _EffectIntensity({
    required this.holographic,
    required this.edgeGlow,
    required this.gloss,
  });
}

/// 边缘发光效果覆盖层
class _EdgeGlowOverlay extends StatelessWidget {
  final Color glowColor;
  final double intensity;

  const _EdgeGlowOverlay({
    required this.glowColor,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EdgeGlowPainter(
          glowColor: glowColor,
          intensity: intensity,
        ),
      ),
    );
  }
}

/// 边缘发光绘制器
class _EdgeGlowPainter extends CustomPainter {
  final Color glowColor;
  final double intensity;

  _EdgeGlowPainter({
    required this.glowColor,
    required this.intensity,
  });

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
        ..color = glowColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurAmount);

      canvas.drawRRect(innerRRect, paint);
    }

    // 外部高光边框
    final borderPaint = Paint()
      ..color = glowColor.withOpacity(0.25 * intensity)
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
      ..color = color.withOpacity(0.3 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    const radius = 3.0;
    const offset = 16.0;

    // 四个角落的高光点
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
  final double intensity;

  const _GlossOverlay({
    required this.progress,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlossPainter(
          progress: progress,
          intensity: intensity,
        ),
      ),
    );
  }
}

/// 改进的光泽效果绘制器
///
/// 包含主光泽层和珠光层
class _GlossPainter extends CustomPainter {
  final double progress;
  final double intensity;

  _GlossPainter({
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 主光泽层 - 白色高光
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

    // 珠光层 - 微妙的彩色光泽
    final pearlPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          const Color(0xFFB8E6F5).withOpacity(0.03 * intensity), // 浅青色
          const Color(0xFFFFF5E1).withOpacity(0.05 * intensity), // 浅金色
          const Color(0xFFE6B8F5).withOpacity(0.03 * intensity), // 浅紫色
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

/// 操作按钮组件
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isDanger;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isDanger = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = widget.isDanger
        ? (_isHovered ? colorScheme.error : colorScheme.error.withOpacity(0.9))
        : (_isHovered ? Colors.white : Colors.white.withOpacity(0.9));
    final iconColor = widget.isDanger
        ? colorScheme.onError
        : (_isHovered ? Colors.black : Colors.black.withOpacity(0.65));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: 32,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withOpacity(_isHovered ? 0.28 : 0.2),
                        blurRadius: _isHovered ? 8 : 4,
                        offset: Offset(0, _isHovered ? 3 : 2),
                      ),
                    ],
                  ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    scale: _isHovered ? 1.08 : 1.0,
                    child: Icon(
                      widget.icon,
                      size: 16,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 38,
              top: 3,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  opacity: _isHovered ? 1.0 : 0.0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    alignment: Alignment.centerRight,
                    scale: _isHovered ? 1.0 : 0.96,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.tooltip,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
