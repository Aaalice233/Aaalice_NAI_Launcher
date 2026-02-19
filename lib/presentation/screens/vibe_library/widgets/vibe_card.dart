import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../widgets/common/animated_favorite_button.dart';

/// 统一 Vibe 卡片组件
///
/// 支持 Bundle 和非 Bundle 类型：
/// - 非 Bundle: 简洁悬停效果
/// - Bundle: 扑克牌层叠展开效果
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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverEnter(PointerEvent event) {
    setState(() => _isHovered = true);
    if (widget.entry.isBundle) {
      _animationController.forward();
    }
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
    if (widget.entry.isBundle) {
      _animationController.reverse();
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
          duration: const Duration(milliseconds: 200),
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

                  // Bundle 扑克牌层叠展开层
                  if (widget.entry.isBundle)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildCardStack(),
                    ),

                  // 信息层
                  _buildInfoOverlay(),

                  // 收藏按钮
                  if (widget.showFavoriteIndicator)
                    _buildFavoriteButton(),

                  // Bundle 数量标识
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

  /// 扑克牌层叠展开效果
  Widget _buildCardStack() {
    final previews = widget.entry.bundledVibePreviews?.toList() ?? [];
    if (previews.isEmpty) return const SizedBox.shrink();

    // 最多显示 5 张
    final count = math.min(previews.length, 5);

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final progress = _animationController.value;
          return _buildFanLayout(previews.take(count).toList(), progress);
        },
      ),
    );
  }

  /// 扇形展开布局
  Widget _buildFanLayout(List<Uint8List> previews, double progress) {
    final count = previews.length;
    if (count == 0) return const SizedBox.shrink();

    // 单张居中显示
    if (count == 1) {
      return Center(
        child: _buildSingleCard(previews[0], progress, 0),
      );
    }

    // 多张扇形展开
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(count, (index) {
          return _buildFanCard(previews[index], index, count, progress);
        }),
      ),
    );
  }

  /// 单张卡片
  Widget _buildSingleCard(Uint8List preview, double progress, int index) {
    final cardWidth = widget.width * 0.65;
    final cardHeight = (widget.height ?? widget.width) * 0.75;

    // 从收起状态到展开状态的动画
    final scale = 0.8 + (0.2 * progress);
    final translateY = 20.0 * (1 - progress);
    final rotate = (index % 2 == 0 ? -1 : 1) * 0.05 * progress;

    return Transform(
      transform: Matrix4.identity()
        ..translate(0.0, translateY)
        ..rotateZ(rotate)
        ..scale(scale),
      alignment: Alignment.center,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4 * progress),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.8 * progress),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            preview,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }

  /// 扇形展开的卡片
  Widget _buildFanCard(Uint8List preview, int index, int total, double progress) {
    final cardWidth = widget.width * 0.55;
    final cardHeight = (widget.height ?? widget.width) * 0.7;

    // 计算扇形角度
    final maxAngle = 0.5; // 最大展开角度（弧度）
    final angleStep = total > 1 ? maxAngle / (total - 1) : 0.0;
    final startAngle = -maxAngle / 2;
    final targetAngle = startAngle + (index * angleStep);

    // 计算扇形半径（从中心点展开）
    final fanRadius = widget.width * 0.15;

    // 当前动画值
    final angle = targetAngle * progress;
    final offsetX = math.sin(angle) * fanRadius * progress;
    final offsetY = -math.cos(angle).abs() * fanRadius * 0.3 * progress;

    // 层叠偏移（收起状态时的偏移）
    final stackOffsetX = (index - total / 2) * 8.0 * (1 - progress);
    final stackOffsetY = (index - total / 2).abs() * 2.0 * (1 - progress);

    final currentX = stackOffsetX + offsetX;
    final currentY = stackOffsetY + offsetY;

    return Transform.translate(
      offset: Offset(currentX, currentY),
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.center,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3 + (0.2 * progress)),
                blurRadius: 8 + (6 * progress),
                offset: Offset(0, 4 + (4 * progress)),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.6 + (0.3 * progress)),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              preview,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[800],
                child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
              ),
            ),
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
              modifierHint: 'Shift+点击 替换', // TODO: 添加国际化支持
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

/// 操作按钮组件
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;

  /// 修饰键提示文本，如 "Shift+点击 替换"
  final String? modifierHint;
  final VoidCallback? onTap;
  final bool isDanger;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.modifierHint,
    this.onTap,
    this.isDanger = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;
  bool _showTooltip = false;
  Timer? _tooltipTimer;

  void _onEnter() {
    setState(() {
      _isHovered = true;
      _showTooltip = true;
    });
    _tooltipTimer?.cancel();
  }

  void _onExit() {
    setState(() => _isHovered = false);
    _tooltipTimer?.cancel();
    _tooltipTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showTooltip = false);
    });
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }

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
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 按钮主体
            AnimatedContainer(
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
            // 自定义 Tooltip
            if (_showTooltip)
              Positioned(
                right: 40,
                top: 4,
                child: AnimatedOpacity(
                  opacity: _showTooltip ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.tooltip,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.modifierHint != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.modifierHint!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
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
