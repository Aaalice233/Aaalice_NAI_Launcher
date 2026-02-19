import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/localization_extension.dart';
import '../../data/models/gallery/local_image_record.dart';

/// 幻灯片屏幕
///
/// 全屏显示图片，支持键盘导航和自动播放
class SlideshowScreen extends ConsumerStatefulWidget {
  /// 图片列表
  final List<LocalImageRecord> images;

  /// 初始显示的图片索引
  final int initialIndex;

  const SlideshowScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends ConsumerState<SlideshowScreen> {
  late int _currentIndex;
  late FocusNode _focusNode;
  Timer? _autoPlayTimer;
  bool _isPlaying = false;
  static const Duration _autoPlayInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _focusNode = FocusNode();

    // 请求焦点以接收键盘事件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _stopAutoPlay();
    super.dispose();
  }

  /// 开始自动播放
  void _startAutoPlay() {
    if (_autoPlayTimer != null) return;

    setState(() {
      _isPlaying = true;
    });

    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (timer) {
      if (mounted) {
        _nextImage();
      } else {
        timer.cancel();
      }
    });
  }

  /// 停止自动播放
  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;

    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  /// 切换自动播放状态
  void _toggleAutoPlay() {
    if (_isPlaying) {
      _stopAutoPlay();
    } else {
      _startAutoPlay();
    }
  }

  /// 上一张图片
  void _previousImage() {
    if (widget.images.isEmpty) return;

    setState(() {
      _currentIndex = (_currentIndex - 1) % widget.images.length;
    });
  }

  /// 下一张图片
  void _nextImage() {
    if (widget.images.isEmpty) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.images.length;
      // 用户手动切换时停止自动播放
      if (_isPlaying) {
        _stopAutoPlay();
      }
    });
  }

  /// 处理键盘事件
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _previousImage();
        break;
      case LogicalKeyboardKey.arrowRight:
        _nextImage();
        break;
      case LogicalKeyboardKey.space:
        _toggleAutoPlay();
        break;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 无图片时显示提示
    if (widget.images.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.slideshow_noImages,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentImage = widget.images[_currentIndex];

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 主图片显示区域
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  File(currentImage.path),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: theme.colorScheme.surface,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            l10n.localGallery_progressiveLoadError,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 顶部信息栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    // 图片计数
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1} ${l10n.slideshow_of} ${widget.images.length}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // 退出按钮
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                      ),
                      tooltip: l10n.slideshow_exit,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),

            // 底部控制栏
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // 上一张按钮
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: theme.colorScheme.onSurface,
                      ),
                      tooltip: l10n.slideshow_previous,
                      onPressed: _previousImage,
                    ),
                    const Spacer(),
                    // 播放/暂停按钮
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: theme.colorScheme.onSurface,
                      ),
                      tooltip: _isPlaying
                          ? l10n.slideshow_pause
                          : l10n.slideshow_play,
                      onPressed: _toggleAutoPlay,
                    ),
                    const Spacer(),
                    // 下一张按钮
                    IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: theme.colorScheme.onSurface,
                      ),
                      tooltip: l10n.slideshow_next,
                      onPressed: _nextImage,
                    ),
                  ],
                ),
              ),
            ),

            // 键盘提示（仅在桌面端显示）
            if (Theme.of(context).platform == TargetPlatform.windows ||
                Theme.of(context).platform == TargetPlatform.macOS ||
                Theme.of(context).platform == TargetPlatform.linux)
              Positioned(
                bottom: 80,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.slideshow_keyboardHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
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
