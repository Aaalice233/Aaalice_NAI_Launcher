import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/gallery/local_image_record.dart';
import 'metadata_panel.dart';

/// 全屏图片预览器
///
/// 经典图库模式：
/// - 左右滑动/箭头切换图片
/// - 支持缩放平移和双击缩放
/// - 底部缩略图条快速跳转
/// - 键盘导航支持
/// - 桌面端右侧元数据面板
/// - Hero 动画过渡效果
class FullscreenImageViewer extends StatefulWidget {
  final List<LocalImageRecord> images;
  final int initialIndex;
  final void Function(LocalImageRecord record)? onReuseMetadata;
  final String? heroTagPrefix;

  const FullscreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    this.onReuseMetadata,
    this.heroTagPrefix,
  });

  /// 打开全屏预览
  static Future<void> show(
    BuildContext context, {
    required List<LocalImageRecord> images,
    required int initialIndex,
    void Function(LocalImageRecord record)? onReuseMetadata,
    String? heroTagPrefix,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: FullscreenImageViewer(
              images: images,
              initialIndex: initialIndex,
              onReuseMetadata: onReuseMetadata,
              heroTagPrefix: heroTagPrefix,
            ),
          );
        },
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late ScrollController _thumbnailController;
  late int _currentIndex;
  bool _showControls = true;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailController = ScrollController();

    // 延迟滚动到当前缩略图
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToThumbnail(_currentIndex, animate: false);
      _focusNode.requestFocus();
    });
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    const thumbnailWidth = 80.0;
    const thumbnailMargin = 8.0;
    const totalWidth = thumbnailWidth + thumbnailMargin;

    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        (index * totalWidth) - (screenWidth / 2) + (totalWidth / 2);
    final maxOffset = _thumbnailController.position.maxScrollExtent;

    final offset = targetOffset.clamp(0.0, maxOffset);

    if (animate) {
      _thumbnailController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _thumbnailController.jumpTo(offset);
    }
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.images.length) return;

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _scrollToThumbnail(index);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _goToPage(_currentIndex - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _goToPage(_currentIndex + 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _goToPage(0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _goToPage(widget.images.length - 1);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentRecord = widget.images[_currentIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: isDesktop
            ? Row(
                children: [
                  // 主内容区域
                  Expanded(
                    child: _buildMainContent(theme, currentRecord),
                  ),
                  // 右侧元数据面板
                  MetadataPanel(
                    currentImage: currentRecord,
                    initialExpanded: true,
                  ),
                ],
              )
            : _buildMainContent(theme, currentRecord),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme, LocalImageRecord currentRecord) {
    return Stack(
      children: [
        // 主图预览区域
        GestureDetector(
          onTap: _toggleControls,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final record = widget.images[index];
              // 仅为当前显示的图片添加 Hero 标签
              final heroTag =
                  widget.heroTagPrefix != null && index == _currentIndex
                      ? '${widget.heroTagPrefix}_${record.path}'
                      : null;
              return _ImagePage(
                record: record,
                heroTag: heroTag,
              );
            },
          ),
        ),

        // 顶部控制栏
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          top: _showControls ? 0 : -100,
          left: 0,
          right: 0,
          child: _buildTopBar(theme, currentRecord),
        ),

        // 底部缩略图栏
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          bottom: _showControls ? 0 : -140,
          left: 0,
          right: 0,
          child: _buildBottomBar(theme),
        ),

        // 左右导航按钮
        if (_showControls) ...[
          // 左箭头
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavigationButton(
                  icon: Icons.chevron_left,
                  onPressed: () => _goToPage(_currentIndex - 1),
                ),
              ),
            ),
          // 右箭头
          if (_currentIndex < widget.images.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavigationButton(
                  icon: Icons.chevron_right,
                  onPressed: () => _goToPage(_currentIndex + 1),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme, LocalImageRecord record) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '关闭',
          ),

          const SizedBox(width: 16),

          // 图片信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (record.metadata?.model != null)
                  Text(
                    record.metadata!.model!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // 操作按钮
          if (record.metadata != null && widget.onReuseMetadata != null)
            IconButton(
              icon: const Icon(Icons.replay, color: Colors.white),
              onPressed: () {
                widget.onReuseMetadata?.call(record);
                Navigator.of(context).pop();
              },
              tooltip: '复用参数',
            ),

          IconButton(
            icon: Icon(
              record.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: record.isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: () {
              // TODO: 实现收藏切换
            },
            tooltip: record.isFavorite ? '取消收藏' : '收藏',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      height: 140,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 元数据信息
          if (widget.images[_currentIndex].metadata != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildMetadataInfo(widget.images[_currentIndex]),
            ),

          // 缩略图条
          SizedBox(
            height: 80,
            child: ListView.builder(
              controller: _thumbnailController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                final isSelected = index == _currentIndex;
                return GestureDetector(
                  onTap: () => _goToPage(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: isSelected ? 80 : 72,
                    height: isSelected ? 80 : 72,
                    margin: EdgeInsets.only(
                      right: 8,
                      top: isSelected ? 0 : 4,
                      bottom: isSelected ? 0 : 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 2.5,
                            )
                          : Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isSelected ? 1.0 : 0.5,
                        child: Image.file(
                          File(widget.images[index].path),
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataInfo(LocalImageRecord record) {
    final metadata = record.metadata;
    if (metadata == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (metadata.seed != null) _buildInfoChip('Seed: ${metadata.seed}'),
          if (metadata.steps != null) _buildInfoChip('${metadata.steps} steps'),
          if (metadata.scale != null) _buildInfoChip('CFG: ${metadata.scale}'),
          if (metadata.sampler != null) _buildInfoChip(metadata.displaySampler),
          if (metadata.width != null && metadata.height != null)
            _buildInfoChip('${metadata.width}×${metadata.height}'),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

/// 单张图片页面（支持缩放和双击缩放）
class _ImagePage extends StatefulWidget {
  final LocalImageRecord record;
  final String? heroTag;

  const _ImagePage({
    required this.record,
    this.heroTag,
  });

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  // 缩放级别
  static const double _minScale = 0.5;
  static const double _maxScale = 4.0;
  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.addListener(() {
      if (_animation != null) {
        _transformController.value = _animation!.value;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;

    final currentScale = _transformController.value.getMaxScaleOnAxis();

    Matrix4 endMatrix;
    if (currentScale > 1.0) {
      // 缩小到原始大小
      endMatrix = Matrix4.identity();
    } else {
      // 放大到目标位置
      final x = -position.dx * (_doubleTapScale - 1);
      final y = -position.dy * (_doubleTapScale - 1);
      endMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(_doubleTapScale);
    }

    _animation = Matrix4Tween(
      begin: _transformController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.file(
      File(widget.record.path),
      fit: BoxFit.contain,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '无法加载图片',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );

    // 如果有 Hero 标签，包装 Hero 动画
    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: _minScale,
        maxScale: _maxScale,
        child: Center(child: imageWidget),
      ),
    );
  }
}

/// 导航按钮
class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _NavigationButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.3),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
