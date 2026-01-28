import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/gallery/local_image_record.dart';
import '../../themes/theme_extension.dart';

/// Steam风格3D透视图片卡片
///
/// 实现高级视觉效果：
/// - 鼠标跟随的3D倾斜（±12°）
/// - 全息棱镜反射效果（彩虹渐变）
/// - 边缘发光效果
/// - 改进的光泽扫过动画
/// - 悬停时轻微放大和阴影增强
class ImageCard3D extends StatefulWidget {
  final LocalImageRecord record;
  final double width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final bool isSelected;
  final bool showFavoriteIndicator;

  const ImageCard3D({
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
  });

  @override
  State<ImageCard3D> createState() => _ImageCard3DState();
}

class _ImageCard3DState extends State<ImageCard3D>
    with SingleTickerProviderStateMixin {
  /// 是否悬停
  bool _isHovered = false;

  /// 鼠标位置（相对于卡片）
  Offset _hoverPosition = Offset.zero;

  /// 光泽动画控制器
  late AnimationController _glossController;

  /// 光泽动画
  late Animation<double> _glossAnimation;

  /// 鼠标更新节流定时器
  Timer? _hoverThrottleTimer;

  /// 最大倾斜角度（弧度），约12°
  static const double _maxTiltAngle = 0.21;

  /// 中心死区比例（鼠标在中心 15% 区域时不倾斜）
  static const double _deadZone = 0.15;

  /// 节流间隔（约60fps）
  static const Duration _throttleInterval = Duration(milliseconds: 16);

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
    _hoverThrottleTimer?.cancel();
    setState(() {
      _isHovered = false;
      _hoverPosition = Offset.zero;
    });
  }

  void _onHoverUpdate(PointerEvent event) {
    // 节流：每16ms更新一次（约60fps）
    if (_hoverThrottleTimer?.isActive ?? false) return;

    _hoverThrottleTimer = Timer(_throttleInterval, () {
      if (mounted && _isHovered) {
        setState(() => _hoverPosition = event.localPosition);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = theme.colorScheme;
    final intensity = _getEffectIntensity(context);
    final glowColor = _getEdgeGlowColor(context);

    // 计算3D透视角度
    double rotateX = 0;
    double rotateY = 0;
    double normalizedX = 0.5;
    double normalizedY = 0.5;

    if (_isHovered && widget.width > 0 && cardHeight > 0) {
      // 将鼠标位置转换为0到1的范围
      normalizedX = (_hoverPosition.dx / widget.width).clamp(0.0, 1.0);
      normalizedY = (_hoverPosition.dy / cardHeight).clamp(0.0, 1.0);

      // 转换为-1到1的范围用于倾斜计算
      final tiltX = (normalizedX - 0.5) * 2;
      final tiltY = (normalizedY - 0.5) * 2;

      // 计算距离中心的距离
      final distance = (tiltX.abs() + tiltY.abs()) / 2;

      // 死区检测：中心区域不触发倾斜
      if (distance > _deadZone) {
        // 平滑过渡：从死区边缘到最大值
        final factor =
            ((distance - _deadZone) / (1.0 - _deadZone)).clamp(0.0, 1.0);

        // 应用倾斜（Y轴旋转对应X方向移动，X轴旋转对应Y方向移动）
        rotateY = tiltX * _maxTiltAngle * factor;
        rotateX = -tiltY * _maxTiltAngle * factor;
      }
    }

    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      onHover: _onHoverUpdate,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 透视效果
            ..rotateX(rotateX)
            ..rotateY(rotateY)
            ..scale(_isHovered ? 1.03 : 1.0),
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
                    rotateY * 8, // 阴影跟随倾斜方向
                    _isHovered ? 14 + rotateX.abs() * 4 : 4,
                  ),
                  spreadRadius: _isHovered ? 2 : 0,
                ),
                // 次阴影（增加深度感）
                if (_isHovered)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: Offset(rotateY * 12, 20),
                    spreadRadius: -4,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 图片层 - 使用RepaintBoundary隔离
                  RepaintBoundary(
                    child: _buildImage(),
                  ),

                  // 2. 全息棱镜效果（仅悬停时）
                  if (_isHovered)
                    RepaintBoundary(
                      child: _HolographicOverlay(
                        normalizedX: normalizedX,
                        normalizedY: normalizedY,
                        intensity: intensity.holographic,
                      ),
                    ),

                  // 3. 边缘发光效果（仅悬停时，带淡入动画）
                  if (_isHovered)
                    TweenAnimationBuilder<double>(
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

                  // 4. 光泽扫过效果（仅悬停时）
                  if (_isHovered)
                    RepaintBoundary(
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

                  // 5. 收藏指示器
                  if (widget.showFavoriteIndicator && widget.record.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildFavoriteIndicator(),
                    ),

                  // 6. 选中状态指示器
                  if (widget.isSelected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildSelectionIndicator(colorScheme),
                    ),

                  // 7. 选中覆盖层
                  if (widget.isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                  // 8. 悬停时显示元数据预览
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
      ),
    );
  }

  Widget _buildImage() {
    final file = File(widget.record.path);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (widget.width * pixelRatio).toInt();

    return Container(
      color: Colors.black.withOpacity(0.05),
      child: Image.file(
        file,
        fit: BoxFit.contain,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
            ),
          );
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: frame != null
                ? child
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteIndicator() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.favorite,
        color: Colors.red,
        size: 16,
      ),
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
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hoverThrottleTimer?.cancel();
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

/// 全息棱镜效果覆盖层
///
/// 创建彩虹渐变效果，跟随鼠标位置变化
class _HolographicOverlay extends StatelessWidget {
  final double normalizedX;
  final double normalizedY;
  final double intensity;

  const _HolographicOverlay({
    required this.normalizedX,
    required this.normalizedY,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _HolographicPainter(
            normalizedX: normalizedX,
            normalizedY: normalizedY,
            intensity: intensity,
          ),
        ),
      ),
    );
  }
}

/// 全息效果绘制器
class _HolographicPainter extends CustomPainter {
  final double normalizedX;
  final double normalizedY;
  final double intensity;

  _HolographicPainter({
    required this.normalizedX,
    required this.normalizedY,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 径向渐变 - 彩虹光环效果
    final radialPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          normalizedX * 2 - 1,
          normalizedY * 2 - 1,
        ),
        radius: 1.2,
        colors: [
          // 中心亮区
          Colors.white.withOpacity(0.06 * intensity),
          // 彩虹环
          const Color(0xFFFF00FF).withOpacity(0.10 * intensity), // 品红
          const Color(0xFF00FFFF).withOpacity(0.10 * intensity), // 青色
          const Color(0xFFFFFF00).withOpacity(0.10 * intensity), // 黄色
          const Color(0xFFFF00FF).withOpacity(0.10 * intensity), // 品红(循环)
          // 外围透明
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.plus;

    canvas.drawRect(rect, radialPaint);

    // 线性渐变 - 根据鼠标位置旋转
    final angle = normalizedX * math.pi; // 0 到 π
    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        transform: GradientRotation(angle),
        colors: [
          Colors.transparent,
          const Color(0xFF00FFFF).withOpacity(0.05 * intensity), // 青色
          const Color(0xFFFF00FF).withOpacity(0.05 * intensity), // 品红
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.screen;

    canvas.drawRect(rect, linePaint);

    // 扫描线效果 - 微妙的水平条纹
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: List.generate(20, (i) {
          return i.isEven
              ? Colors.white.withOpacity(0.015 * intensity)
              : Colors.transparent;
        }),
      ).createShader(rect)
      ..blendMode = BlendMode.overlay;

    canvas.drawRect(rect, scanPaint);
  }

  @override
  bool shouldRepaint(_HolographicPainter oldDelegate) {
    return oldDelegate.normalizedX != normalizedX ||
        oldDelegate.normalizedY != normalizedY ||
        oldDelegate.intensity != intensity;
  }
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
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _EdgeGlowPainter(
            glowColor: glowColor,
            intensity: intensity,
          ),
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
      Canvas canvas, Size size, Color color, double intensity) {
    final highlightPaint = Paint()
      ..color = color.withOpacity(0.3 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    const radius = 3.0;
    const offset = 16.0;

    // 四个角落的高光点
    final corners = [
      Offset(offset, offset),
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
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GlossPainter(
            progress: progress,
            intensity: intensity,
          ),
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
