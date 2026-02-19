import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../widgets/common/animated_favorite_button.dart';

/// 统一 Vibe 卡片组件
///
/// 支持 Bundle 和非 Bundle 类型：
/// - 非 Bundle: 简洁悬停效果（放大、阴影、发光边框）
/// - Bundle: 斜向百叶窗展开效果，展示子 vibe 预览
class VibeCard extends StatefulWidget {
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

  const VibeCard({
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
  State<VibeCard> createState() => _VibeCardState();
}

class _VibeCardState extends State<VibeCard>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isHovered = false;
  late AnimationController _blindsController;
  late Animation<double> _blindsAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _blindsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _blindsAnimation = CurvedAnimation(
      parent: _blindsController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _blindsController.dispose();
    super.dispose();
  }

  void _onHoverEnter(PointerEvent event) {
    setState(() => _isHovered = true);
    if (widget.entry.isBundle) {
      _blindsController.forward();
    }
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
    if (widget.entry.isBundle) {
      _blindsController.reverse();
    }
  }

  Uint8List? get _thumbnailData {
    final thumbnail = widget.entry.thumbnail;
    if (thumbnail != null && thumbnail.isNotEmpty) return thumbnail;

    final vibeThumbnail = widget.entry.vibeThumbnail;
    if (vibeThumbnail != null && vibeThumbnail.isNotEmpty) return vibeThumbnail;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = Theme.of(context).colorScheme;

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
          transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
          transformAlignment: Alignment.center,
          child: Container(
            width: widget.width,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: _buildBorder(colorScheme),
              boxShadow: _buildShadows(),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 主内容层
                  _buildMainContent(),

                  // Bundle 百叶窗效果层
                  if (widget.entry.isBundle)
                    _buildDiagonalBlindsEffect(),

                  // 信息层
                  _buildInfoOverlay(),

                  // 收藏按钮
                  if (widget.showFavoriteIndicator)
                    _buildFavoriteButton(),

                  // Bundle 标识
                  if (widget.entry.isBundle)
                    _buildBundleBadge(),

                  // 选中状态
                  if (widget.isSelected)
                    _buildSelectionOverlay(colorScheme),

                  // 操作按钮
                  if (_isHovered && !widget.isSelected)
                    _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Border? _buildBorder(ColorScheme colorScheme) {
    if (widget.isSelected) {
      return Border.all(color: colorScheme.primary, width: 3);
    }
    if (_isHovered) {
      return Border.all(
        color: colorScheme.primary.withOpacity(0.3),
        width: 2,
      );
    }
    return null;
  }

  List<BoxShadow> _buildShadows() {
    if (_isHovered) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 28,
          offset: const Offset(0, 14),
          spreadRadius: 2,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 40,
          offset: const Offset(0, 20),
          spreadRadius: -4,
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.12),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  Widget _buildMainContent() {
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
                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
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

  Widget _buildDiagonalBlindsEffect() {
    final previews = widget.entry.bundledVibePreviews?.take(5).toList() ?? [];
    if (previews.isEmpty) return const SizedBox.shrink();

    final count = previews.length.clamp(2, 5);

    return AnimatedBuilder(
      animation: _blindsAnimation,
      builder: (context, child) {
        final progress = _blindsAnimation.value;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 子 vibe 预览层（仅动画过程中显示）
            if (progress > 0)
              ...List.generate(count, (index) {
                return _buildStripContent(index, count, previews[index], progress);
              }),

            // 百叶窗叶片层
            if (progress > 0)
              CustomPaint(
                size: Size.infinite,
                painter: _BlindsOverlayPainter(
                  progress: progress,
                  count: count,
                  themeColor: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStripContent(int index, int total, Uint8List preview, double progress) {
    final stripHeight = (widget.height ?? widget.width) / total;
    final y = index * stripHeight;
    final diagonalOffset = widget.width * 0.3 * progress;

    return Positioned(
      left: -diagonalOffset,
      top: y,
      right: diagonalOffset,
      height: stripHeight,
      child: ClipPath(
        clipper: _DiagonalStripClipper(index: index, total: total),
        child: Image.memory(
          preview,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[800],
            child: const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    return Positioned(
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
            _buildProgressBar(
              label: context.l10n.vibe_strength,
              value: widget.entry.strength,
              color: Colors.blue,
            ),
            const SizedBox(height: 4),
            _buildProgressBar(
              label: context.l10n.vibe_infoExtracted,
              value: widget.entry.infoExtracted,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({
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

  Widget _buildFavoriteButton() {
    final isFavorite = widget.entry.isFavorite;
    final showButton = _isHovered || isFavorite;

    if (!showButton) return const SizedBox.shrink();

    return Positioned(
      top: 8,
      right: 8,
      child: CardFavoriteButton(
        isFavorite: isFavorite,
        onToggle: widget.onFavoriteToggle,
        size: 18,
      ),
    );
  }

  Widget _buildBundleBadge() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            const Icon(Icons.folder_copy, size: 10, color: Colors.white),
            const SizedBox(width: 2),
            Text(
              '${widget.entry.bundledVibeCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionOverlay(ColorScheme colorScheme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.check,
                color: colorScheme.onPrimary,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      top: 8,
      right: 8,
      child: Column(
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
      ),
    );
  }
}

/// 对角线条形裁剪器
class _DiagonalStripClipper extends CustomClipper<Path> {
  final int index;
  final int total;

  _DiagonalStripClipper({required this.index, required this.total});

  @override
  Path getClip(Size size) {
    final diagonalOffset = size.width * 0.3;

    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - diagonalOffset, size.height)
      ..lineTo(-diagonalOffset, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => false;
}

/// 百叶窗覆盖层绘制器
class _BlindsOverlayPainter extends CustomPainter {
  final double progress;
  final int count;
  final Color themeColor;

  _BlindsOverlayPainter({
    required this.progress,
    required this.count,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stripHeight = size.height / count;
    const diagonalOffsetBase = 0.3;

    for (int i = 0; i < count; i++) {
      final y = i * stripHeight;
      // 默认状态(progress=0): 完整遮盖, 展开状态(progress=1): 完全移开
      final diagonalOffset = size.width * diagonalOffsetBase * (1 - progress);

      final path = Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y)
        ..lineTo(size.width - diagonalOffset, y + stripHeight)
        ..lineTo(-diagonalOffset, y + stripHeight)
        ..close();

      // 叶片覆盖层：默认不透明遮盖，随进度淡出
      final paint = Paint()
        ..color = Colors.black.withOpacity(0.5 * (1 - progress))
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      // 叶片边缘发光（仅展开时显示）
      if (progress > 0.1) {
        final borderPaint = Paint()
          ..color = themeColor.withOpacity(0.6 * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        canvas.drawPath(path, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlindsOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.count != count ||
        oldDelegate.themeColor != themeColor;
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

    final Color backgroundColor;
    final Color iconColor;

    if (widget.isDanger) {
      backgroundColor = _isHovered
          ? colorScheme.error
          : colorScheme.error.withOpacity(0.9);
      iconColor = colorScheme.onError;
    } else {
      backgroundColor = _isHovered
          ? Colors.white
          : Colors.white.withOpacity(0.9);
      iconColor = _isHovered
          ? Colors.black
          : Colors.black.withOpacity(0.65);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
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
                color: Colors.black.withOpacity(_isHovered ? 0.28 : 0.2),
                blurRadius: _isHovered ? 8 : 4,
                offset: Offset(0, _isHovered ? 3 : 2),
              ),
            ],
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            scale: _isHovered ? 1.08 : 1.0,
            child: Icon(widget.icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
