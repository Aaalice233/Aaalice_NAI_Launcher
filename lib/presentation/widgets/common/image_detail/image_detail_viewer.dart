import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../image_viewport_surface.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/services/ios_photo_library_service.dart';
import '../../../../core/services/native_share_service.dart';
import '../../../../core/shortcuts/shortcuts.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/image_share_sanitizer.dart';
import '../../../../core/utils/window_focus_tracker.dart';
import '../../../../core/windowing/workspace_side_panel_contract.dart';
import '../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../providers/share_image_settings_provider.dart';
import '../../../providers/copy_drag_watermark_provider.dart';
import '../../../screens/mosaic/mosaic_editor_launcher.dart';
import '../../../screens/watermark/watermark_editor_launcher.dart';
import '../../../utils/clipboard_image.dart';
import '../../shortcuts/shortcuts.dart';
import '../app_toast.dart';
import '../horizontal_resize_handle.dart';
import '../resizable_pane.dart';
import 'components/detail_image_page.dart';
import 'components/detail_metadata_panel.dart';
import 'components/prompt_copy_dialog.dart';
import 'components/detail_thumbnail_bar.dart';
import 'components/detail_top_bar.dart';
import 'image_detail_data.dart';

/// 图像详情查看器回调函数
class ImageDetailCallbacks {
  /// 收藏切换回调
  final void Function(ImageDetailData image)? onFavoriteToggle;

  /// 复用元数据回调
  final Future<void> Function(ImageDetailData image)? onReuseMetadata;

  /// 保存回调
  final Future<void> Function(ImageDetailData image)? onSave;

  /// 复制图像回调
  final Future<void> Function(ImageDetailData image)? onCopyImage;

  /// 发送到图生图回调
  final Future<void> Function(ImageDetailData image)? onSendToImg2Img;

  /// 发送到反推模块回调
  final Future<void> Function(ImageDetailData image)? onSendToReversePrompt;

  const ImageDetailCallbacks({
    this.onFavoriteToggle,
    this.onReuseMetadata,
    this.onSave,
    this.onCopyImage,
    this.onSendToImg2Img,
    this.onSendToReversePrompt,
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
class ImageDetailViewer extends ConsumerStatefulWidget {
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
    final isWindows = PlatformCapabilities.current.isWindows;
    final transitionDuration = isWindows
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final reverseTransitionDuration = isWindows
        ? Duration.zero
        : const Duration(milliseconds: 250);

    return Navigator.of(context).push(
      PageRouteBuilder(
        // Windows + 外部截图工具 + 焦点切换下，透明路由和快照过渡更容易触发
        // Flutter 引擎原生崩溃；Windows 走纯黑不透明且无动画路径。
        opaque: isWindows,
        barrierColor: ImageViewportSurface.background,
        allowSnapshotting: !isWindows,
        transitionDuration: transitionDuration,
        reverseTransitionDuration: reverseTransitionDuration,
        pageBuilder: (context, animation, secondaryAnimation) {
          final viewer = ImageDetailViewer(
            images: images,
            initialIndex: initialIndex,
            showMetadataPanel: showMetadataPanel,
            showThumbnails: showThumbnails,
            callbacks: callbacks,
            heroTagPrefix: heroTagPrefix,
          );
          if (isWindows) {
            return viewer;
          }
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: viewer,
          );
        },
      ),
    );
  }

  /// 复制/拖拽时该带哪个图像变换。
  ///
  /// 【偏离上游】上游 `_copyImageToClipboard` 无条件把
  /// `copyDragWatermarkProvider` 的 transform 交给 sanitizer
  /// （v4.2.1 新增的「复制/拖拽时加水印」，默认关闭）。
  /// 「去除元数据」和「加水印」是两个正交开关：用户点的
  /// 「复制（去除元数据）」只承诺产出没有元数据的副本，不应该顺带把水印烙进去。
  /// 抽成具名函数是为了让这条规则可被测试钉住——下次跟上游时，
  /// 一旦有人把两个开关合并回去，测试会直接红。
  @visibleForTesting
  static ShareImageTransform? copyTransformFor({
    required bool? stripMetadataOverride,
    required ShareImageTransform? watermark,
  }) => stripMetadataOverride == true ? null : watermark;

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
  ConsumerState<ImageDetailViewer> createState() => _ImageDetailViewerState();
}

class _ImageDetailViewerState extends ConsumerState<ImageDetailViewer> {
  static const Duration _windowsEscFocusCooldown = Duration(milliseconds: 1200);
  static const Duration _windowsEscBounceCooldown = Duration(seconds: 4);
  static const Duration _closeRequestThrottle = Duration(milliseconds: 700);
  static const double _initialMetadataPanelWidth = 420;
  static const double _minimumMetadataPanelWidth = 320;
  static const double _minimumImagePaneWidth = 480;

  late PageController _pageController;
  late ScrollController _thumbnailController;
  late int _currentIndex;
  // 始终显示控制栏（不自动收起）
  final bool _showControls = true;
  final _focusNode = FocusNode();
  final Map<String, TransformationController> _transformationControllers = {};
  bool _isClosing = false;
  DateTime? _lastCloseRequestedAt;
  late final ResizablePaneController _metadataPanelWidthController;

  /// 元数据文件解析兜底（identifier → 进行中的解析 / 结果）。
  ///
  /// 【偏离上游】上游详情页只读 [ImageDetailData.metadata]，即本地图库数据库
  /// 里的快照。刚生成尚未被后台扫描入库、或 **iOS 覆盖安装后应用容器 UUID 变化
  /// 导致快照里的绝对路径失效** 时，快照是 null，顶栏的「复用参数」按钮会
  /// 直接消失。上游只把点击后的行为改成了文件级解析
  /// （`local_gallery_action_coordinator` 的 `resolveLocalGalleryMetadata`），
  /// 没有修按钮显隐——这是 iOS 特有问题，上游不会修。
  /// 这里从图片自身异步解析补齐，并把结果回灌给 [DetailTopBar.metadataOverride]。
  final Map<String, Future<NaiImageMetadata?>> _metadataFutures = {};
  final Map<String, NaiImageMetadata?> _resolvedMetadata = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailController = ScrollController();
    _metadataPanelWidthController = ResizablePaneController(
      initialWidth: _initialMetadataPanelWidth,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToThumbnail(_currentIndex, animate: false);
      _focusNode.requestFocus();
      _prefetchCurrentMetadata();
    });
  }

  /// 当前可用元数据：快照有数据就用快照，否则用文件解析的兜底结果。
  NaiImageMetadata? _metadataOf(ImageDetailData data) {
    final snapshot = data.metadata;
    if (snapshot != null && snapshot.hasData) return snapshot;
    return _resolvedMetadata[data.identifier] ?? snapshot;
  }

  /// 从图片自身异步解析元数据（每张图只解析一次，结果缓存）。
  Future<NaiImageMetadata?> _resolveMetadata(ImageDetailData data) {
    return _metadataFutures.putIfAbsent(data.identifier, () {
      return data
          .getMetadataAsync()
          .then((result) {
            if (mounted) {
              setState(() => _resolvedMetadata[data.identifier] = result);
            }
            return result;
          })
          .catchError((Object error) {
            AppLogger.w(
              'Metadata fallback parse failed for ${data.identifier}: $error',
              'ImageDetailViewer',
            );
            return Future<NaiImageMetadata?>.value(null);
          });
    });
  }

  /// 快照缺失时提前触发解析，让顶栏按钮显隐尽快收敛。
  void _prefetchCurrentMetadata() {
    if (_currentIndex < 0 || _currentIndex >= widget.images.length) return;
    final data = widget.images[_currentIndex];
    final snapshot = data.metadata;
    if ((snapshot == null || !snapshot.hasData) &&
        !_metadataFutures.containsKey(data.identifier)) {
      _resolveMetadata(data);
    }
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    if (!_thumbnailController.hasClients) return;

    const thumbnailWidth = 80.0;
    const thumbnailMargin = 8.0;
    const totalWidth = thumbnailWidth + thumbnailMargin;

    final viewportWidth = _thumbnailController.position.viewportDimension;
    final targetOffset =
        (index * totalWidth) - (viewportWidth / 2) + (totalWidth / 2);
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

  void _jumpToPage(int index) {
    if (index < 0 || index >= widget.images.length) return;
    _pageController.jumpToPage(index);
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _scrollToThumbnail(index);
    _prefetchCurrentMetadata();
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
        _handleKeyboardCloseRequest();
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

  void _handleKeyboardCloseRequest() {
    if (_shouldSuppressEscCloseOnWindows()) {
      final elapsedFocus = WindowFocusTracker.elapsedSinceFocus();
      final elapsedBlur = WindowFocusTracker.elapsedSinceBlur();
      AppLogger.w(
        'Suppressed ESC close after focus bounce '
            '(focus=${elapsedFocus?.inMilliseconds ?? -1}ms, '
            'blur=${elapsedBlur?.inMilliseconds ?? -1}ms)',
        'ImageDetailViewer',
      );
      return;
    }
    _requestClose('keyboard-escape');
  }

  bool _shouldSuppressEscCloseOnWindows() {
    if (!PlatformCapabilities.current.isWindows) return false;
    if (WindowFocusTracker.isWithinCooldown(_windowsEscFocusCooldown)) {
      return true;
    }
    return WindowFocusTracker.hadRecentFocusBounce(
      maxSinceFocus: _windowsEscBounceCooldown,
    );
  }

  void _requestClose(String reason) {
    if (!mounted || _isClosing) return;
    final now = DateTime.now();
    final lastCloseAt = _lastCloseRequestedAt;
    if (lastCloseAt != null &&
        now.difference(lastCloseAt) <= _closeRequestThrottle) {
      AppLogger.d(
        'Ignored duplicated close request: $reason',
        'ImageDetailViewer',
      );
      return;
    }
    _lastCloseRequestedAt = now;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      AppLogger.d(
        'Ignored close request on non-current route: $reason',
        'ImageDetailViewer',
      );
      return;
    }

    _isClosing = true;
    AppLogger.d('Viewer close requested: $reason', 'ImageDetailViewer');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).maybePop().whenComplete(() {
        if (mounted) {
          _isClosing = false;
        }
      });
    });
  }

  ImageDetailData get _currentImage => widget.images[_currentIndex];

  /// 获取当前图片的 TransformationController
  TransformationController get _currentTransformController {
    final identifier = _currentImage.identifier;
    return _transformationControllers.putIfAbsent(
      identifier,
      TransformationController.new,
    );
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
      ..translateByDouble(
        centerX - centerX * newScale,
        centerY - centerY * newScale,
        0,
        1,
      )
      ..scaleByDouble(newScale, newScale, newScale, 1);

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
      ..translateByDouble(
        centerX - centerX * newScale,
        centerY - centerY * newScale,
        0,
        1,
      )
      ..scaleByDouble(newScale, newScale, newScale, 1);

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
    _requestClose('toggle-fullscreen');
  }

  /// 切换收藏
  void _toggleFavorite() {
    if (widget.callbacks?.onFavoriteToggle != null) {
      widget.callbacks!.onFavoriteToggle!(_currentImage);
      // 触发重建以更新收藏按钮状态
      setState(() {});
    }
  }

  /// 复制 Prompt
  Future<void> _copyPrompt() async {
    // 与顶栏显隐口径一致：快照缺失时用兜底解析结果，否则 iOS 覆盖安装后
    // 按钮显示了却提示「没有提示词」。
    final metadata = _metadataOf(_currentImage);
    if (metadata == null || metadata.fullPrompt.isEmpty) {
      if (context.mounted) {
        AppToast.warning(context, context.l10n.toast_imageHasNoPrompt);
      }
      return;
    }

    final prompt = await PromptCopyDialog.show(context, metadata: metadata);
    if (prompt == null || !mounted) return;

    await Clipboard.setData(ClipboardData(text: prompt));
    if (mounted) {
      AppToast.success(context, context.l10n.toast_imagePromptCopied);
    }
  }

  Future<void> _showMetadataPanel() {
    return AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.detail_imageDetails,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (panelContext, _) => LayoutBuilder(
        builder: (context, constraints) => DetailMetadataPanel(
          currentImage: _currentImage,
          expandedWidth: constraints.maxWidth,
          collapsible: false,
        ),
      ),
    );
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
      AppToast.info(context, context.l10n.toast_useDeleteButton);
    }
  }

  @override
  Widget build(BuildContext context) {
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
      ShortcutIds.closeViewer: _handleKeyboardCloseRequest,
      // 收藏切换
      ShortcutIds.toggleFavorite: _toggleFavorite,
      // 复制 Prompt
      ShortcutIds.copyPrompt: _copyPrompt,
      // 复用参数
      ShortcutIds.reuseGalleryParams: _reuseGalleryParams,
      // 删除图片
      ShortcutIds.deleteImage: _deleteImage,
    };

    return PageShortcuts(
      contextType: ShortcutContext.viewer,
      shortcuts: shortcuts,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: ImageViewportSurface.background,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final showSideMetadata = constraints.maxWidth >= 1100;
              if (!showSideMetadata || !widget.showMetadataPanel) {
                return _buildMainContent(
                  showMetadataAction: widget.showMetadataPanel,
                );
              }

              final maximumPanelWidth =
                  WorkspaceSidePanelContract.constrainedWorkspaceWidth(
                    workspaceWidth: constraints.maxWidth,
                    preferredWidth: WorkspaceSidePanelContract.maximumWidth,
                    occupiedWidth: ResizeHandle.defaultWidth,
                    minimumPrimaryWidth: _minimumImagePaneWidth,
                    minimumWidth: _minimumMetadataPanelWidth,
                  );
              return Row(
                children: [
                  Expanded(child: _buildMainContent(showMetadataAction: false)),
                  ResizeHandle(
                    key: const ValueKey('image-detail-metadata-resize-handle'),
                    onDrag: (delta) =>
                        _metadataPanelWidthController.resizeBy(-delta),
                  ),
                  ResizablePane(
                    controller: _metadataPanelWidthController,
                    minimumWidth: _minimumMetadataPanelWidth,
                    maximumWidth: maximumPanelWidth,
                    child: DetailMetadataPanel(
                      currentImage: _currentImage,
                      initialExpanded: true,
                      collapsible: false,
                      fillAvailableWidth: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent({required bool showMetadataAction}) {
    final showThumbnails = widget.showThumbnails && widget.images.length > 1;

    return Stack(
      children: [
        // 主图预览区域
        // 注意：移除 onTap 切换控制栏，让顶部工具栏始终显示
        PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final data = widget.images[index];
            final heroTag =
                widget.heroTagPrefix != null && index == _currentIndex
                ? '${widget.heroTagPrefix}_${data.identifier}'
                : null;
            final transformationController = _transformationControllers
                .putIfAbsent(data.identifier, TransformationController.new);
            return DetailImagePage(
              key: ValueKey(data.identifier),
              data: data,
              heroTag: heroTag,
              transformationController: transformationController,
            );
          },
        ),

        // 顶部控制栏
        AnimatedPositioned(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          top: _showControls ? 0 : -100,
          left: 0,
          right: 0,
          child: DetailTopBar(
            currentIndex: _currentIndex,
            totalImages: widget.images.length,
            currentImage: _currentImage,
            // 数据库快照缺失时用文件解析的兜底结果驱动按钮显隐（iOS 覆盖安装）
            metadataOverride: _metadataOf(_currentImage),
            onClose: () => _requestClose('top-bar-close'),
            onShowMetadata: showMetadataAction ? _showMetadataPanel : null,
            onReuseMetadata: widget.callbacks?.onReuseMetadata != null
                ? () => _handleReuseMetadata(context)
                : null,
            onFavoriteToggle: widget.callbacks?.onFavoriteToggle != null
                ? () => widget.callbacks!.onFavoriteToggle!(_currentImage)
                : null,
            onSave: widget.callbacks?.onSave != null
                ? () => widget.callbacks!.onSave!(_currentImage)
                : null,
            // 上游的复制：跟随 shareImageSettingsProvider（默认带元数据）
            onCopyImage: _currentImage.showCopyButton
                ? () => _copyImageToClipboard(context)
                : null,
            // 【偏离上游】常驻的「复制（去除元数据）」：硬传 override，
            // 不读 shareImageSettingsProvider，也不带水印 transform。
            onCopyImageClean: _currentImage.showCopyButton
                ? () => _copyImageToClipboard(
                    context,
                    stripMetadataOverride: true,
                  )
                : null,
            // 【偏离上游】显式的「保存到相册」，只在 iOS 出现，
            // 绝不接 image_generation_provider 的 publishToSystemGallery 自动回调。
            onSaveToAlbum: IosPhotoLibraryService.isSupported
                ? () => _saveToPhotoAlbum(context)
                : null,
            onShare: PlatformCapabilities.current.supportsNativeShare
                ? () => _shareImage(context)
                : null,
            onWatermark: () => _openWatermarkEditor(context),
            onMosaic: () => _openMosaicEditor(context),
            onSendToImg2Img: widget.callbacks?.onSendToImg2Img != null
                ? () => widget.callbacks!.onSendToImg2Img!(_currentImage)
                : null,
            onSendToReversePrompt:
                widget.callbacks?.onSendToReversePrompt != null
                ? () => widget.callbacks!.onSendToReversePrompt!(_currentImage)
                : null,
          ),
        ),

        // 底部缩略图栏
        if (showThumbnails)
          AnimatedPositioned(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            bottom: _showControls ? 0 : -100,
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
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 100,
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: DetailThumbnailBar(
        images: widget.images,
        currentIndex: _currentIndex,
        scrollController: _thumbnailController,
        onTap: _jumpToPage,
      ),
    );
  }

  /// 保存当前图像到系统相册（显式动作，iOS）
  ///
  /// 【偏离上游】上游没有这条路径：Android 侧是保存/出图即无条件发布到系统相册
  /// （`publishToSystemGallery` 等约 10 个调用点由
  /// `PlatformCapabilities.supportsSystemGalleryExport` 统一放行，无开关可关）。
  /// 用户点名要求保存只写应用自管的本地图库，进相册必须由用户主动点，
  /// 所以这里走独立的 [IosPhotoLibraryService]，由
  /// `supportsExplicitPhotoLibraryExport` 门控，**不接任何自动保存回调**。
  Future<void> _saveToPhotoAlbum(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final imageBytes = await _currentImage.getImageBytes();
      final result = await IosPhotoLibraryService.saveImageBytes(
        bytes: imageBytes,
        fileName: _currentImage.fileInfo?.fileName,
      );
      if (!context.mounted) return;
      switch (result.outcome) {
        case PhotoLibrarySaveOutcome.saved:
          AppToast.success(context, l10n.image_savedToAlbum);
        case PhotoLibrarySaveOutcome.permissionDenied:
          AppToast.warning(context, l10n.image_albumPermissionDenied);
        case PhotoLibrarySaveOutcome.unsupported:
        case PhotoLibrarySaveOutcome.failed:
          AppToast.error(
            context,
            l10n.image_saveToAlbumFailed('${result.error ?? result.outcome}'),
          );
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, l10n.image_saveToAlbumFailed('$error'));
      }
    }
  }

  /// 复制图像到剪贴板
  ///
  /// [stripMetadataOverride] 为 null 时跟随上游的全局「分享保护」设置；
  /// 传 true 是用户点名的「复制（去除元数据）」常驻动作，绕过全局开关。
  Future<void> _copyImageToClipboard(
    BuildContext context, {
    bool? stripMetadataOverride,
  }) async {
    final l10n = context.l10n;
    final transform = ImageDetailViewer.copyTransformFor(
      stripMetadataOverride: stripMetadataOverride,
      watermark: ref.read(copyDragWatermarkProvider),
    );
    // 【偏离上游】上游只有 effectiveStripMetadataForCopyAndDrag 这一个来源，
    // 而它 = assetProtectionMode && stripMetadataForCopyAndDrag，
    // assetProtectionMode 默认 false，所以上游默认复制是**带**元数据的。
    // override 为 true 时直接绕过全局开关。
    final stripMetadata =
        stripMetadataOverride ??
        ref
            .read(shareImageSettingsProvider)
            .effectiveStripMetadataForCopyAndDrag;
    try {
      final imageBytes = await _currentImage.getImageBytes();
      final fileName = _currentImage.fileInfo?.fileName ?? 'shared.png';
      final shareImage =
          await ImageShareSanitizer.prepareForCopyOrDragInBackground(
            imageBytes,
            fileName: fileName,
            stripMetadata: stripMetadata,
            transform: transform,
          );

      // 跨平台复制到剪贴板（原 Windows 端走 PowerShell + System.Drawing，
      // macOS/Linux 不可用）。统一规范化为 PNG，避免 jpg/webp 原始字节被当成
      // PNG 导致粘贴失败。
      await writeImageBytesToClipboardAsPng(shareImage.bytes);

      if (context.mounted) {
        AppToast.success(context, l10n.image_copiedToClipboard);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, l10n.image_copyFailed(e.toString()));
      }
    }
  }

  Future<void> _openWatermarkEditor(BuildContext context) async {
    final fileInfo = _currentImage.fileInfo;
    if (fileInfo != null) {
      await WatermarkEditorLauncher.openForLocalPath(
        context: context,
        path: fileInfo.path,
      );
      return;
    }
    final bytes = await _currentImage.getImageBytes();
    if (!context.mounted) return;
    await WatermarkEditorLauncher.open(
      context: context,
      sourceBytes: bytes,
      sourceFileName: 'image.png',
    );
  }

  Future<void> _openMosaicEditor(BuildContext context) async {
    final fileInfo = _currentImage.fileInfo;
    if (fileInfo != null) {
      await MosaicEditorLauncher.openForLocalPath(
        context: context,
        path: fileInfo.path,
      );
      return;
    }
    final bytes = await _currentImage.getImageBytes();
    if (!context.mounted) return;
    await MosaicEditorLauncher.open(
      context: context,
      sourceBytes: bytes,
      sourceFileName: 'image.png',
    );
  }

  Future<void> _shareImage(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final imageBytes = await _currentImage.getImageBytes();
      final fileName = _currentImage.fileInfo?.fileName ?? 'shared.png';
      final stripMetadata = ref
          .read(shareImageSettingsProvider)
          .effectiveStripMetadataForCopyAndDrag;
      final shareImage = await ImageShareSanitizer.prepareForCopyOrDrag(
        imageBytes,
        fileName: fileName,
        stripMetadata: stripMetadata,
      );
      if (!context.mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await NativeShareService.shareImage(
        bytes: shareImage.bytes,
        fileName: shareImage.fileName,
        sharePositionOrigin: origin,
      );
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, l10n.image_shareFailed(error.toString()));
      }
    }
  }

  /// 处理复用元数据
  Future<void> _handleReuseMetadata(BuildContext context) async {
    final metadata = _metadataOf(_currentImage);
    if (metadata == null || !metadata.hasData) {
      AppToast.warning(context, context.l10n.toast_imageHasNoMetadata);
      return;
    }

    await widget.callbacks?.onReuseMetadata?.call(_currentImage);
    if (!context.mounted) return;

    // 关闭图像详情页
    if (context.mounted) {
      _requestClose('reuse-metadata');
    }
  }

  @override
  void dispose() {
    _metadataPanelWidthController.dispose();
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    _transformationControllers.clear();
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

  const _NavigationButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
