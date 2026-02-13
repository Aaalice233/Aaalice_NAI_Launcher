import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../data/models/vibe/vibe_library_entry.dart';

/// Bundle Vibe 卡片组件
///
/// 实现扑克牌展开效果：
/// - 收起状态：层叠的扑克牌效果（3-4张卡片）
/// - 展开状态：扇形展开效果（所有内部 vibes 呈扇形排列）
/// - 右上角显示 vibe 数量徽章
/// - 支持"使用全部"和"导出整体"操作
class BundleVibeCard extends StatefulWidget {
  final VibeLibraryEntry entry;
  final VoidCallback? onExpandToggle;
  final VoidCallback? onUseAll;
  final VoidCallback? onExportBundle;
  final Function(int index)? onUseSingle;
  final Function(int index)? onExportSingle;
  final bool isSelected;

  const BundleVibeCard({
    super.key,
    required this.entry,
    this.onExpandToggle,
    this.onUseAll,
    this.onExportBundle,
    this.onUseSingle,
    this.onExportSingle,
    this.isSelected = false,
  });

  @override
  State<BundleVibeCard> createState() => _BundleVibeCardState();
}

class _BundleVibeCardState extends State<BundleVibeCard>
    with TickerProviderStateMixin {
  /// 是否展开
  bool _isExpanded = false;

  /// 悬浮状态
  bool _isHovering = false;

  /// 点击缩放状态
  bool _isPressed = false;

  /// 展开/收起动画控制器
  late AnimationController _expandController;

  /// 展开动画
  late Animation<double> _expandAnimation;

  /// 悬浮动画控制器
  late AnimationController _hoverController;

  /// 悬浮动画
  late Animation<double> _hoverAnimation;

  /// 选中发光动画控制器
  late AnimationController _glowController;

  /// 选中发光动画
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _expandController = _createAnimationController(
      duration: const Duration(milliseconds: 400),
    );
    _expandAnimation = _createCurvedAnimation(
      _expandController,
      Curves.easeInOutCubic,
    );

    _hoverController = _createAnimationController(
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnimation = _createCurvedAnimation(_hoverController, Curves.easeOut);

    _glowController = _createAnimationController(
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      _createCurvedAnimation(_glowController, Curves.easeInOut),
    );

    if (widget.isSelected) {
      _glowController.repeat(reverse: true);
    }
  }

  AnimationController _createAnimationController({
    required Duration duration,
    AnimationBehavior? behavior,
  }) {
    return AnimationController(
      vsync: this,
      duration: duration,
      animationBehavior: behavior ?? AnimationBehavior.normal,
    );
  }

  CurvedAnimation _createCurvedAnimation(
    AnimationController parent,
    Curve curve,
  ) {
    return CurvedAnimation(parent: parent, curve: curve);
  }

  @override
  void didUpdateWidget(covariant BundleVibeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
        _glowController.reset();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _hoverController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  /// 切换展开/收起状态
  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
    widget.onExpandToggle?.call();
  }

  /// 获取 bundle 内 vibe 数量
  int get _vibeCount => widget.entry.bundledVibeCount;

  /// 获取预览缩略图列表
  List<Uint8List> get _previewThumbnails {
    final previews = widget.entry.bundledVibePreviews ?? [];
    return previews;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _hoverController.reverse();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _expandAnimation,
            _hoverAnimation,
            _glowAnimation,
          ]),
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: _buildBorder(colorScheme),
                boxShadow: _buildShadows(colorScheme),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // 背景
                    _buildBackground(colorScheme),

                    // 内容区域
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 标题和徽章行
                          _buildHeader(colorScheme),

                          const SizedBox(height: 16),

                          // 卡片展示区域
                          _buildCardDisplayArea(),

                          // 展开时的操作按钮
                          if (_isExpanded) ...[
                            const SizedBox(height: 16),
                            _buildExpandedActions(colorScheme),
                          ],
                        ],
                      ),
                    ),

                    // 右上角数量徽章
                    _buildCountBadge(colorScheme),

                    // 展开/收起按钮
                    _buildExpandButton(colorScheme),

                    // 选中发光效果
                    if (widget.isSelected) _buildSelectionGlow(colorScheme),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建边框
  Border? _buildBorder(ColorScheme colorScheme) {
    if (widget.isSelected) {
      return Border.all(
        color: colorScheme.primary,
        width: 3,
      );
    }
    if (_isHovering) {
      return Border.all(
        color: colorScheme.primary.withOpacity(0.4),
        width: 2,
      );
    }
    return Border.all(
      color: colorScheme.outline.withOpacity(0.2),
      width: 1,
    );
  }

  /// 构建阴影
  List<BoxShadow> _buildShadows(ColorScheme colorScheme) {
    final baseShadow = BoxShadow(
      color: Colors.black.withOpacity(_isHovering ? 0.2 : 0.1),
      blurRadius: _isHovering ? 24 : 12,
      offset: Offset(0, _isHovering ? 8 : 4),
      spreadRadius: _isHovering ? 2 : 0,
    );

    if (widget.isSelected) {
      return [
        baseShadow,
        BoxShadow(
          color: colorScheme.primary.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 4),
          spreadRadius: 2,
        ),
      ];
    }

    if (_isHovering) {
      return [
        baseShadow,
        BoxShadow(
          color: colorScheme.primary.withOpacity(0.1),
          blurRadius: 30,
          offset: const Offset(0, 8),
          spreadRadius: 4,
        ),
      ];
    }

    return [baseShadow];
  }

  /// 构建背景
  Widget _buildBackground(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerHighest.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  /// 构建头部（标题和图标）
  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.layers,
            size: 20,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.entry.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$_vibeCount 个 Vibe',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建卡片展示区域
  Widget _buildCardDisplayArea() {
    final clickScale = _isPressed ? 0.98 : 1.0;
    final hoverLift = _isHovering ? -4.0 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isExpanded ? 200 : 140,
      child: Transform.scale(
        scale: clickScale,
        child: Transform.translate(
          offset: Offset(0, hoverLift),
          child: _isExpanded ? _buildExpandedFanView() : _buildCollapsedStackView(),
        ),
      ),
    );
  }

  /// 收起状态：层叠的扑克牌效果
  Widget _buildCollapsedStackView() {
    final previews = _previewThumbnails.take(4).toList();
    final displayCount = math.min(previews.length, 4);

    if (displayCount == 0) {
      return _buildEmptyState();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // 底层卡片
        if (displayCount >= 4)
          _buildStackedCard(
            index: 3,
            offset: const Offset(-20, 0),
            rotation: -0.12,
            opacity: 0.5,
            thumbnail: previews[3],
          ),
        // 第三层卡片
        if (displayCount >= 3)
          _buildStackedCard(
            index: 2,
            offset: const Offset(-12, -2),
            rotation: -0.07,
            opacity: 0.7,
            thumbnail: previews[2],
          ),
        // 第二层卡片
        if (displayCount >= 2)
          _buildStackedCard(
            index: 1,
            offset: const Offset(-4, -4),
            rotation: -0.03,
            opacity: 0.85,
            thumbnail: previews[1],
          ),
        // 顶层卡片
        _buildStackedCard(
          index: 0,
          offset: const Offset(4, -6),
          rotation: 0.02,
          opacity: 1.0,
          thumbnail: previews[0],
          isTop: true,
        ),
      ],
    );
  }

  /// 展开状态：扇形展开效果
  Widget _buildExpandedFanView() {
    final previews = _previewThumbnails;
    final count = previews.length;

    if (count == 0) {
      return _buildEmptyState();
    }

    final maxDisplayCount = math.min(count, 8);
    const angleStep = 0.18; // 每张卡片的角度间隔
    final startAngle = -(maxDisplayCount - 1) * angleStep / 2;

    return Center(
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 扇形卡片
          ...List.generate(maxDisplayCount, (index) {
            final angle = startAngle + index * angleStep;
            return _buildFanCard(
              index: index,
              angle: angle,
              thumbnail: previews[index],
            );
          }),
        ],
      ),
    );
  }

  /// 构建层叠卡片
  Widget _buildStackedCard({
    required int index,
    required Offset offset,
    required double rotation,
    required double opacity,
    required Uint8List thumbnail,
    bool isTop = false,
  }) {
    const cardWidth = 90.0;
    const cardHeight = 120.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      left: MediaQuery.of(context).size.width / 2 - cardWidth / 2 + offset.dx,
      top: 10 + offset.dy,
      child: GestureDetector(
        onTap: isTop ? _toggleExpand : null,
        child: Transform.rotate(
          angle: rotation,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isTop ? 0.3 : 0.15),
                    blurRadius: isTop ? 12 : 6,
                    offset: Offset(0, isTop ? 6 : 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildThumbnailImage(thumbnail),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建扇形卡片
  Widget _buildFanCard({
    required int index,
    required double angle,
    required Uint8List thumbnail,
  }) {
    const cardWidth = 85.0;
    const cardHeight = 115.0;
    const radius = 80.0; // 扇形半径

    // 计算卡片在扇形中的位置
    final x = math.sin(angle) * radius;
    final y = math.cos(angle) * radius * 0.3; // 压缩垂直距离

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      left: MediaQuery.of(context).size.width / 2 - cardWidth / 2 + x - 32,
      bottom: 20 - y,
      child: GestureDetector(
        onTap: () => widget.onUseSingle?.call(index),
        child: MouseRegion(
          onEnter: (_) {},
          onExit: (_) {},
          child: Transform.rotate(
            angle: angle,
            child: _buildHoverableCard(
              width: cardWidth,
              height: cardHeight,
              thumbnail: thumbnail,
              index: index,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建可悬浮的卡片
  Widget _buildHoverableCard({
    required double width,
    required double height,
    required Uint8List thumbnail,
    required int index,
  }) {
    return _HoverableFanCard(
      width: width,
      height: height,
      thumbnail: thumbnail,
      index: index,
      onUseSingle: widget.onUseSingle,
      onExportSingle: widget.onExportSingle,
    );
  }

  /// 构建缩略图图片
  Widget _buildThumbnailImage(Uint8List thumbnail) {
    return Image.memory(
      thumbnail,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
          ),
        );
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers, size: 32, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              '无预览',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建数量徽章
  Widget _buildCountBadge(ColorScheme colorScheme) {
    return Positioned(
      top: 12,
      right: 48, // 为展开按钮留出空间
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$_vibeCount',
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 构建展开/收起按钮
  Widget _buildExpandButton(ColorScheme colorScheme) {
    return Positioned(
      top: 8,
      right: 8,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: _toggleExpand,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovering
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.expand_more,
                size: 20,
                color: _isHovering
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建展开时的操作按钮
  Widget _buildExpandedActions(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 使用全部按钮
        if (widget.onUseAll != null)
          Expanded(
            child: _buildActionButton(
              icon: Icons.play_arrow,
              label: '使用全部',
              onTap: widget.onUseAll!,
              colorScheme: colorScheme,
              isPrimary: true,
            ),
          ),
        if (widget.onUseAll != null && widget.onExportBundle != null)
          const SizedBox(width: 12),
        // 导出整体按钮
        if (widget.onExportBundle != null)
          Expanded(
            child: _buildActionButton(
              icon: Icons.download,
              label: '导出整体',
              onTap: widget.onExportBundle!,
              colorScheme: colorScheme,
              isPrimary: false,
            ),
          ),
      ],
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required bool isPrimary,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isPrimary
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: isPrimary
                ? null
                : Border.all(color: colorScheme.outline.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: (isPrimary ? colorScheme.primary : Colors.black)
                    .withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建选中发光效果
  Widget _buildSelectionGlow(ColorScheme colorScheme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(
                      0.2 + 0.1 * math.sin(_glowAnimation.value * math.pi * 2),
                    ),
                    blurRadius: 20 + 10 * _glowAnimation.value,
                    spreadRadius: 2 + 2 * _glowAnimation.value,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 可悬浮的扇形卡片组件
class _HoverableFanCard extends StatefulWidget {
  final double width;
  final double height;
  final Uint8List thumbnail;
  final int index;
  final Function(int index)? onUseSingle;
  final Function(int index)? onExportSingle;

  const _HoverableFanCard({
    required this.width,
    required this.height,
    required this.thumbnail,
    required this.index,
    this.onUseSingle,
    this.onExportSingle,
  });

  @override
  State<_HoverableFanCard> createState() => _HoverableFanCardState();
}

class _HoverableFanCardState extends State<_HoverableFanCard> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () => widget.onUseSingle?.call(widget.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: widget.width,
          height: widget.height,
          transform: Matrix4.identity()
            ..scale(_isPressed ? 0.95 : (_isHovering ? 1.05 : 1.0))
            ..translate(0.0, _isHovering ? -8.0 : 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  _isHovering ? 0.4 : 0.2,
                ),
                blurRadius: _isHovering ? 16 : 8,
                offset: Offset(0, _isHovering ? 8 : 4),
                spreadRadius: _isHovering ? 2 : 0,
              ),
            ],
            border: _isHovering
                ? Border.all(
                    color: colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                _buildThumbnailImage(widget.thumbnail),
                // 悬浮时显示导出按钮
                if (_isHovering)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => widget.onExportSingle?.call(widget.index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.download,
                          size: 14,
                          color: Colors.white,
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

  Widget _buildThumbnailImage(Uint8List thumbnail) {
    return Image.memory(
      thumbnail,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
          ),
        );
      },
    );
  }
}
