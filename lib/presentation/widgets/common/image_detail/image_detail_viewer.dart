import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/shortcuts/shortcuts.dart';
import '../../../../data/models/metadata/metadata_import_options.dart';
import '../../shortcuts/shortcuts.dart';
import '../app_toast.dart';
import '../../metadata/metadata_import_dialog.dart';
import 'components/detail_image_page.dart';
import 'components/detail_metadata_panel.dart';
import 'components/detail_thumbnail_bar.dart';
import 'components/detail_top_bar.dart';
import 'components/viewer_shortcut_hints.dart';
import 'image_detail_data.dart';

/// 图像详情查看器回调函数
class ImageDetailCallbacks {
  /// 收藏切换回调
  final void Function(ImageDetailData image)? onFavoriteToggle;

  /// 复用元数据回调
  /// 接收图像数据和用户选择的导入选项
  final void Function(
    ImageDetailData image,
    MetadataImportOptions options,
  )? onReuseMetadata;

  /// 保存回调
  final Future<void> Function(ImageDetailData image)? onSave;

  /// 复制图像回调
  final Future<void> Function(ImageDetailData image)? onCopyImage;

  const ImageDetailCallbacks({
    this.onFavoriteToggle,
    this.onReuseMetadata,
    this.onSave,
    this.onCopyImage,
  });
}

/// 通用图像详情查看器
///
/// 支持两种使用模式:
/// 1. 单图模式: 显示单张图片 + 元数据
/// 2. 多图模式: 支持翻页、缩略图导航
///
/// 功能特性:
/// - 左右滑动/箭头切换图片
/// - 支持缩放平移和双击缩放
/// - 底部缩略图条快速跳转
/// - 键盘导航支持
/// - 桌面端右侧元数据面板
class ImageDetailViewer extends StatefulWidget {
  /// 图像数据列表
  final List<ImageDetailData> images;

  /// 初始显示索引
  final int initialIndex;

  /// 是否显示元数据面板（桌面端）
  final bool showMetadataPanel;

  /// 是否显示缩略图条
  final bool showThumbnails;

  /// 回调函数
  final ImageDetailCallbacks? callbacks;

  /// Hero 标签前缀
  final String? heroTagPrefix;

  const ImageDetailViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.showMetadataPanel = true,
    this.showThumbnails = true,
    this.callbacks,
    this.heroTagPrefix,
  });

  /// 打开图像详情查看器
  static Future<void> show(
    BuildContext context, {
    required List<ImageDetailData> images,
    int initialIndex = 0,
    bool showMetadataPanel = true,
    bool showThumbnails = true,
    ImageDetailCallbacks? callbacks,
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
            child: ImageDetailViewer(
              images: images,
              initialIndex: initialIndex,
              showMetadataPanel: showMetadataPanel,
              showThumbnails: showThumbnails,
              callbacks: callbacks,
              heroTagPrefix: heroTagPrefix,
            ),
          );
        },
      ),
    );
  }

  /// 打开单图模式（无缩略图条）
  static Future<void> showSingle(
    BuildContext context, {
    required ImageDetailData image,
    bool showMetadataPanel = true,
    ImageDetailCallbacks? callbacks,
    String? heroTag,
  }) {
    return show(
      context,
      images: [image],
      initialIndex: 0,
      showMetadataPanel: showMetadataPanel,
      showThumbnails: false,
      callbacks: callbacks,
      heroTagPrefix: heroTag,
    );
  }

  @override
  State<ImageDetailViewer> createState() => _ImageDetailViewerState();
}

class _ImageDetailViewerState extends State<ImageDetailViewer> {
  late PageController _pageController;
  late ScrollController _thumbnailController;
  late int _currentIndex;
  bool _showControls = true;
  bool _showShortcutHints = false;
  final _focusNode = FocusNode();
  final Map<int, TransformationController> _transformationControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToThumbnail(_currentIndex, animate: false);
      _focusNode.requestFocus();
    });
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    if (!_thumbnailController.hasClients) return;

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

  void _toggleShortcutHints() {
    setState(() => _showShortcutHints = !_showShortcutHints);
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

  ImageDetailData get _currentImage => widget.images[_currentIndex];

  /// 获取当前图片的 TransformationController
  TransformationController get _currentTransformController {
    if (!_transformationControllers.containsKey(_currentIndex)) {
      _transformationControllers[_currentIndex] = TransformationController();
    }
    return _transformationControllers[_currentIndex]!;
  }

  /// 放大
  void _zoomIn() {
    final controller = _currentTransformController;
    final currentScale = controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.2).clamp(0.5, 4.0);
    
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;
    
    final matrix = Matrix4.identity()
      ..translate(centerX - centerX * newScale, centerY - centerY * newScale)
      ..scale(newScale);
    
    controller.value = matrix;
  }

  /// 缩小
  void _zoomOut() {
    final controller = _currentTransformController;
    final currentScale = controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.2).clamp(0.5, 4.0);
    
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;
    
    final matrix = Matrix4.identity()
      ..translate(centerX - centerX * newScale, centerY - centerY * newScale)
      ..scale(newScale);
    
    controller.value = matrix;
  }

  /// 重置缩放
  void _resetZoom() {
    _currentTransformController.value = Matrix4.identity();
  }

  /// 切换全屏
  void _toggleFullscreen() {
    // 使用窗口管理器切换全屏
    // 由于查看器是弹窗形式，关闭查看器即可
    Navigator.of(context).pop();
  }

  /// 切换收藏
  void _toggleFavorite() {
    if (widget.callbacks?.onFavoriteToggle != null) {
      widget.callbacks!.onFavoriteToggle!(_currentImage);
    }
  }

  /// 复制 Prompt
  void _copyPrompt() {
    final metadata = _currentImage.metadata;
    final prompt = metadata?.prompt;
    if (prompt != null && prompt.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: prompt));
      if (context.mounted) {
        AppToast.success(context, '已复制 Prompt');
      }
    } else {
      if (context.mounted) {
        AppToast.warning(context, '此图片没有 Prompt');
      }
    }
  }

  /// 复用参数
  void _reuseGalleryParams() {
    if (widget.callbacks?.onReuseMetadata != null) {
      _handleReuseMetadata(context);
    }
  }

  /// 删除图片
  void _deleteImage() {
    // 查看器本身不直接处理删除，通过回调通知父组件
    // 这里显示一个提示，实际删除由调用方处理
    if (context.mounted) {
      AppToast.info(context, '请使用界面删除按钮');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    // 定义快捷键映射
    final shortcuts = <String, VoidCallback>{
      // 上一张
      ShortcutIds.previousImage: () => _goToPage(_currentIndex - 1),
      // 下一张
      ShortcutIds.nextImage: () => _goToPage(_currentIndex + 1),
      // 放大
      ShortcutIds.zoomIn: _zoomIn,
      // 缩小
      ShortcutIds.zoomOut: _zoomOut,
      // 重置缩放
      ShortcutIds.resetZoom: _resetZoom,
      // 全屏切换
      ShortcutIds.toggleFullscreen: _toggleFullscreen,
      // 关闭查看器
      ShortcutIds.closeViewer: () => Navigator.of(context).pop(),
      // 收藏切换
      ShortcutIds.toggleFavorite: _toggleFavorite,
      // 复制 Prompt
      ShortcutIds.copyPrompt: _copyPrompt,
      // 复用参数
      ShortcutIds.reuseGalleryParams: _reuseGalleryParams,
      // 删除图片
      ShortcutIds.deleteImage: _deleteImage,
      // 显示快捷键帮助
      ShortcutIds.showShortcutHelp: _toggleShortcutHints,
    };

    return PageShortcuts(
      contextType: ShortcutContext.viewer,
      shortcuts: shortcuts,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: isDesktop && widget.showMetadataPanel
              ? Row(
                  children: [
                    Expanded(
                      child: _buildMainContent(),
                    ),
                    DetailMetadataPanel(
                      currentImage: _currentImage,
                      initialExpanded: true,
                    ),
                  ],
                )
              : _buildMainContent(),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final showThumbnails = widget.showThumbnails && widget.images.length > 1;

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
              final data = widget.images[index];
              final heroTag =
                  widget.heroTagPrefix != null && index == _currentIndex
                      ? '${widget.heroTagPrefix}_${data.identifier}'
                      : null;
              // 确保每个页面都有 TransformationController
              if (!_transformationControllers.containsKey(index)) {
                _transformationControllers[index] = TransformationController();
              }
              return DetailImagePage(
                data: data,
                heroTag: heroTag,
                transformationController: _transformationControllers[index],
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
          child: DetailTopBar(
            currentIndex: _currentIndex,
            totalImages: widget.images.length,
            currentImage: _currentImage,
            onClose: () => Navigator.of(context).pop(),
            onReuseMetadata: widget.callbacks?.onReuseMetadata != null
                ? () => _handleReuseMetadata(context)
                : null,
            onFavoriteToggle: widget.callbacks?.onFavoriteToggle != null
                ? () => widget.callbacks!.onFavoriteToggle!(_currentImage)
                : null,
            onSave: widget.callbacks?.onSave != null
                ? () => widget.callbacks!.onSave!(_currentImage)
                : null,
            onCopyImage: () => _copyImageToClipboard(context),
          ),
        ),

        // 底部缩略图栏
        if (showThumbnails)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showControls ? 0 : -140,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),

        // 左右导航按钮
        if (_showControls && widget.images.length > 1) ...[
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

        // 快捷键提示覆盖层
        Positioned(
          right: 16,
          bottom: widget.showThumbnails && widget.images.length > 1 ? 160 : 80,
          child: ViewerShortcutHints(
            visible: _showShortcutHints,
          ),
        ),

        // 快捷键提示切换按钮
        Positioned(
          right: 16,
          bottom: widget.showThumbnails && widget.images.length > 1 ? 120 : 40,
          child: ViewerShortcutHintsButton(
            isVisible: _showShortcutHints,
            onToggle: _toggleShortcutHints,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final metadata = _currentImage.metadata;

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
          if (metadata != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildMetadataInfo(metadata),
            ),

          // 缩略图条
          DetailThumbnailBar(
            images: widget.images,
            currentIndex: _currentIndex,
            scrollController: _thumbnailController,
            onTap: _goToPage,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataInfo(dynamic metadata) {
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

  /// 复制图像到剪贴板
  Future<void> _copyImageToClipboard(BuildContext context) async {
    File? tempFile;
    try {
      // 获取图像字节
      final imageBytes = await _currentImage.getImageBytes();

      // 创建临时文件
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        '${tempDir.path}/NAI_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(imageBytes);

      // 验证文件是否成功创建
      if (!await tempFile.exists()) {
        throw Exception('临时文件创建失败');
      }

      // 使用 PowerShell 复制图像到剪贴板
      // 使用 [System.Windows.Forms.Clipboard]::SetImage() 正确复制图像数据
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; \$image = [System.Drawing.Image]::FromFile("${tempFile.path}"); [System.Windows.Forms.Clipboard]::SetImage(\$image); \$image.Dispose();',
      ]);

      // 检查 PowerShell 命令执行结果
      if (result.exitCode != 0) {
        final errorOutput = result.stderr.toString();
        throw Exception('PowerShell 命令失败 (exitCode: ${result.exitCode}): $errorOutput');
      }

      // 延迟删除临时文件，确保 PowerShell 完成读取
      await Future.delayed(const Duration(milliseconds: 500));

      if (context.mounted) {
        AppToast.success(context, '已复制到剪贴板');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '复制失败: $e');
      }
    } finally {
      // 清理临时文件
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // 忽略删除错误
        }
      }
    }
  }

  /// 处理复用元数据
  Future<void> _handleReuseMetadata(BuildContext context) async {
    final metadata = _currentImage.metadata;
    if (metadata == null || !metadata.hasData) {
      AppToast.warning(context, '此图片没有元数据');
      return;
    }

    // 显示参数选择对话框
    final options = await MetadataImportDialog.show(
      context,
      metadata: metadata,
    );

    if (options == null || !context.mounted) return; // 用户取消

    // 调用回调并传递选项
    widget.callbacks?.onReuseMetadata?.call(_currentImage, options);

    // 关闭图像详情页
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailController.dispose();
    _focusNode.dispose();
    super.dispose();
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
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
