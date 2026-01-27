import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/gallery/local_image_record.dart';

/// 3D透视图片卡片
///
/// 实现轻量透视效果：
/// - 鼠标跟随的微妙倾斜（±5°）
/// - 光泽扫过动画
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

  /// 最大倾斜角度（弧度），约12°（增大可调节范围）
  static const double _maxTiltAngle = 0.21;

  /// 中心死区比例（鼠标在中心 20% 区域时不倾斜）
  static const double _deadZone = 0.15;

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
    setState(() {
      _isHovered = false;
      _hoverPosition = Offset.zero;
    });
  }

  void _onHoverUpdate(PointerEvent event) {
    setState(() => _hoverPosition = event.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = theme.colorScheme;

    // 计算3D透视角度
    double rotateX = 0;
    double rotateY = 0;

    if (_isHovered && widget.width > 0 && cardHeight > 0) {
      // 将鼠标位置转换为-1到1的范围
      final normalizedX = (_hoverPosition.dx / widget.width - 0.5) * 2;
      final normalizedY = (_hoverPosition.dy / cardHeight - 0.5) * 2;

      // 计算距离中心的距离
      final distance = (normalizedX.abs() + normalizedY.abs()) / 2;

      // 死区检测：中心区域不触发倾斜
      if (distance > _deadZone) {
        // 平滑过渡：从死区边缘到最大值
        final factor =
            ((distance - _deadZone) / (1.0 - _deadZone)).clamp(0.0, 1.0);

        // 应用倾斜（Y轴旋转对应X方向移动，X轴旋转对应Y方向移动）
        rotateY = normalizedX * _maxTiltAngle * factor;
        rotateX = -normalizedY * _maxTiltAngle * factor;
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
                BoxShadow(
                  color: _isHovered
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.12),
                  blurRadius: _isHovered ? 24 : 10,
                  offset: Offset(0, _isHovered ? 12 : 4),
                  spreadRadius: _isHovered ? 2 : 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片
                  _buildImage(),

                  // 光泽扫过效果
                  if (_isHovered)
                    AnimatedBuilder(
                      animation: _glossAnimation,
                      builder: (context, child) {
                        return _GlossOverlay(progress: _glossAnimation.value);
                      },
                    ),

                  // 收藏指示器
                  if (widget.showFavoriteIndicator && widget.record.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                    ),

                  // 选中状态指示器
                  if (widget.isSelected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: TweenAnimationBuilder<double>(
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
                      ),
                    ),

                  // 选中覆盖层
                  if (widget.isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                  // 悬停时显示元数据预览
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
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
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
          Row(
            children: [
              if (metadata.seed != null)
                _buildMetadataChip('Seed: ${metadata.seed}'),
              if (metadata.steps != null) ...[
                const SizedBox(width: 4),
                _buildMetadataChip('${metadata.steps} steps'),
              ],
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
    _glossController.dispose();
    super.dispose();
  }
}

/// 光泽扫过效果覆盖层
class _GlossOverlay extends StatelessWidget {
  final double progress;

  const _GlossOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GlossPainter(progress: progress),
        ),
      ),
    );
  }
}

/// 光泽效果绘制器
class _GlossPainter extends CustomPainter {
  final double progress;

  _GlossPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.25),
          Colors.white.withOpacity(0.15),
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

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GlossPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
