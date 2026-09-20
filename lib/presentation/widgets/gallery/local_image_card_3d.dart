import '../../selection/card_selection_scope.dart';
import '../common/image_card_frame.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/local_gallery_thumbnail_provider.dart';
import '../../../core/mosaic/mosaic_derivative_registry.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/watermark/watermark_derivative_registry.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/mosaic_settings_provider.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../providers/copy_drag_watermark_provider.dart';
import '../../providers/watermark_settings_provider.dart';
import '../../utils/clipboard_image.dart';
import '../common/app_toast.dart';
import '../common/card_action_buttons.dart';
import '../common/image_card_action.dart';
import '../common/image_card_action_region.dart';
import 'local_image_context_menu.dart';
import 'local_image_hover_preview.dart';

/// 本地图片卡片，提供稳定的选择、快捷操作和键盘交互。
class LocalImageCard3D extends ConsumerStatefulWidget {
  final LocalImageRecord record;
  final double width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(TapUpDetails)? onSecondaryTapUp;
  final bool isSelected;
  final bool showFavoriteIndicator;
  final VoidCallback? onFavoriteToggle;
  final Future<void> Function(LocalImageContextAction action)? onSendAction;
  final bool enableAddToAgent;
  final bool isKritaConnected;
  final bool isVisible;
  final int priority;

  /// 可选的拖拽包装器，用于将卡片内容包装在 DragItemWidget 中
  /// 解决 GestureDetector 与拖拽手势冲突的问题
  final Widget Function(Widget child)? dragWrapper;

  const LocalImageCard3D({
    super.key,
    required this.record,
    required this.width,
    this.height,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.isSelected = false,
    this.showFavoriteIndicator = true,
    this.onFavoriteToggle,
    this.onSendAction,
    this.enableAddToAgent = true,
    this.isKritaConnected = false,
    this.isVisible = false,
    this.priority = 5,
    this.dragWrapper,
  });

  @override
  ConsumerState<LocalImageCard3D> createState() => _LocalImageCard3DState();
}

class _LocalImageCard3DState extends ConsumerState<LocalImageCard3D> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isCopyingImage = false;
  bool _suppressCardTap = false;
  bool _hasDecodedFrame = false;
  LocalGalleryThumbnailProvider? _imageProvider;

  @override
  void didUpdateWidget(LocalImageCard3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.path != widget.record.path ||
        oldWidget.record.size != widget.record.size ||
        oldWidget.record.modifiedAt != widget.record.modifiedAt ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _cancelPendingImage();
      _imageProvider = null;
      _hasDecodedFrame = false;
    }
  }

  @override
  void dispose() {
    _cancelPendingImage();
    super.dispose();
  }

  void _cancelPendingImage() {
    final provider = _imageProvider;
    if (provider != null && !_hasDecodedFrame) {
      unawaited(
        LocalGalleryThumbnailMemoryCache.instance.cancelPending(provider),
      );
    }
  }

  LocalGalleryThumbnailProvider _providerForCurrentLayout() {
    final target = LocalGalleryThumbnailTarget.fromLogicalSize(
      logicalWidth: widget.width,
      logicalHeight: widget.height ?? widget.width,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final source = LocalGallerySourceIdentity.fromRecord(
      path: widget.record.path,
      size: widget.record.size,
      modifiedAt: widget.record.modifiedAt,
    );
    final current = _imageProvider;
    if (current != null &&
        current.source == source &&
        current.target == target &&
        current.fit == LocalGalleryThumbnailFit.cover) {
      return current;
    }

    if (current != null && !_hasDecodedFrame) {
      unawaited(
        LocalGalleryThumbnailMemoryCache.instance.cancelPending(current),
      );
    }
    final provider = LocalGalleryThumbnailProvider(
      source: source,
      target: target,
    );
    LocalGalleryThumbnailMemoryCache.instance.register(provider);
    _imageProvider = provider;
    _hasDecodedFrame = false;
    return provider;
  }

  void _retryImage() {
    final provider = _imageProvider;
    if (provider != null) {
      _cancelPendingImage();
      PaintingBinding.instance.imageCache.evict(provider.cacheKey);
    }
    setState(() {
      _imageProvider = null;
      _hasDecodedFrame = false;
    });
  }

  void _onHoverEnter(PointerEvent event) {
    setState(() => _isHovered = true);
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _isHovered = false);
  }

  Future<void> _copyImageToClipboard() async {
    if (_isCopyingImage) return;
    setState(() => _isCopyingImage = true);
    final transform = ref.read(copyDragWatermarkProvider);
    final stripMetadata = ref
        .read(shareImageSettingsProvider)
        .effectiveStripMetadataForCopyAndDrag;

    try {
      final sourceFile = File(widget.record.path);
      if (!await sourceFile.exists()) {
        if (mounted) AppToast.error(context, context.l10n.gallery_fileMissing);
        return;
      }

      final sourceParts = sourceFile.path.split(RegExp(r'[/\\]'));
      final sourceName = sourceParts.isNotEmpty
          ? sourceParts.last
          : 'shared.png';
      final originalBytes = await sourceFile.readAsBytes();
      final shareImage =
          await ImageShareSanitizer.prepareForCopyOrDragInBackground(
            originalBytes,
            fileName: sourceName,
            stripMetadata: stripMetadata,
            transform: transform,
          );

      // 跨平台复制到剪贴板（原 Windows 端走 PowerShell + System.Drawing，
      // macOS/Linux 不可用）。统一规范化为 PNG，避免 jpg/webp 原始字节被当成
      // PNG 导致粘贴失败。
      await writeImageBytesToClipboardAsPng(shareImage.bytes);

      if (mounted) {
        AppToast.success(context, context.l10n.gallery_copiedToClipboard);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.gallery_copyFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _isCopyingImage = false);
    }
  }

  void _handleCardTap() {
    if (!_suppressCardTap &&
        CardSelectionScope.handleTap(context, widget.record.path)) {
      return;
    }
    if (_suppressCardTap || _isCopyingImage) {
      _suppressCardTap = false;
      return;
    }
    widget.onTap?.call();
  }

  void _handleCardTapCancel() {
    _suppressCardTap = false;
  }

  @override
  Widget build(BuildContext context) => ImageCardActionRegion(
    resourceId: widget.record.path,
    actions: _buildActions(),
    builder: _buildCard,
  );

  Widget _buildCard(BuildContext context, List<ImageCardAction> actions) {
    final theme = Theme.of(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = theme.colorScheme;
    final interactionPolicy = context.interactionPolicy;
    final isTouch = interactionPolicy.usesTouchActionMenu;
    final selectionMode =
        CardSelectionScope.maybeOf(context)?.selection.isActive ?? false;
    final aspectRatio = widget.width / cardHeight;
    final buttonDirection = aspectRatio > 1.3 ? Axis.horizontal : Axis.vertical;
    final interactive = widget.onTap != null;
    final fileName = widget.record.path.split(RegExp(r'[/\\]')).last;

    Widget cardContent = GestureDetector(
      onTap: widget.onTap == null ? null : _handleCardTap,
      onTapCancel: _handleCardTapCancel,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      onSecondaryTapUp: widget.onSendAction == null
          ? widget.onSecondaryTapUp
          : null,
      child: ImageCardFrame(
        hovered: _isHovered && interactive,
        focused: _isFocused,
        selected: widget.isSelected,
        width: widget.width,
        height: cardHeight,
        clipRadius: 10,
        hoverScaleEnabled: interactive,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImageLayer(),
            if (!selectionMode)
              Positioned(
                key: const ValueKey('local-image-card-actions'),
                top: 4,
                right: 4,
                left: buttonDirection == Axis.horizontal && !isTouch ? 4 : null,
                child: _buildActionButtons(
                  actions,
                  buttonDirection,
                  cardHeight,
                ),
              ),
            if (widget.isSelected)
              Positioned(
                top: 8,
                left: 8,
                child: _buildSelectionIndicator(colorScheme),
              ),
            if (widget.isSelected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    cardContent = Semantics(
      label: fileName,
      button: interactive,
      enabled: interactive,
      selected: widget.isSelected,
      child: FocusableActionDetector(
        enabled: interactive,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        onFocusChange: (focused) {
          if (_isFocused != focused) setState(() => _isFocused = focused);
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _handleCardTap();
              return null;
            },
          ),
        },
        child: cardContent,
      ),
    );

    // 如果提供了 dragWrapper，使用它包装卡片内容
    // 这样 DragItemWidget 可以正确接收拖拽手势
    if (widget.dragWrapper != null) {
      cardContent = widget.dragWrapper!(cardContent);
    }

    // 【偏离上游：上游没有这个门控】
    // 上游无条件挂 MouseRegion + LocalImageHoverPreview：卡片缩放抬升
    // （ImageCardFrame.hovered）和 280ms 延时悬浮预览卡都只由 _isHovered 驱动，
    // 而 _isHovered 只由 MouseRegion 的 enter/exit 设置，没有任何指针类型判断。
    // 上游之所以在 Android 上没炸，是 card_action_buttons.dart 在
    // usesTouchActionMenu 时提前返回常驻 more 菜单、根本不读 visible —— 那只盖住了
    // 按钮显隐这一条，缩放与悬浮预览卡两条至今无门控。
    // Flutter 的 MouseTracker 只接受 mouse 与 **stylus** 两种设备
    // （rendering/mouse_tracker.dart 的 kind 过滤），所以 iPad + Apple Pencil 悬停
    // 会真的触发 enter：手写笔悬停时弹出一张 360pt 宽的预览卡盖住刚要点的图，
    // 是 iOS 上特有的坏体验。
    // 这里按 interactionPolicy.precisePointerAvailable 门控：只有本会话确实观察到
    // 鼠标/触控板才启用 hover 呈现。stylus 在 InteractionPolicy.withPointerDevice
    // 里归入 touch 且不置该位，因此手写笔悬停不会打开这条路径。
    // 该位单调递增（只会 false→true，永不回落），所以不存在「先为真后转假」
    // 把 _isHovered 卡在 true 的残留状态。
    final pointerHoverEnabled = interactionPolicy.precisePointerAvailable;
    return LocalImageHoverPreview(
      record: widget.record,
      enabled: !selectionMode && pointerHoverEnabled,
      child: MouseRegion(
        key: const ValueKey('local-image-card-hover-region'),
        onEnter: pointerHoverEnabled ? _onHoverEnter : null,
        onExit: pointerHoverEnabled ? _onHoverExit : null,
        cursor: interactive && pointerHoverEnabled
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: cardContent,
      ),
    );
  }

  Widget _buildImageLayer() => _buildOptimizedImage();

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: Colors.grey[850],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[600],
                value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.common_loading,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.red[900]?.withValues(alpha: 0.3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: Colors.red[400], size: 40),
            const SizedBox(height: 8),
            Text(
              context.l10n.onlineGallery_loadFailed,
              style: TextStyle(color: Colors.red[300], fontSize: 12),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _retryImage,
              icon: Icon(Icons.refresh, color: Colors.red[300], size: 16),
              label: Text(
                context.l10n.common_retry,
                style: TextStyle(color: Colors.red[300], fontSize: 11),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size(
                  0,
                  context.interactionPolicy.minimumControlExtent,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizedImage() {
    final provider = _providerForCurrentLayout();
    return Image(
      key: ValueKey(provider.cacheKey),
      image: provider,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          LocalGalleryThumbnailMemoryCache.instance.releasePendingOwner(
            provider,
          );
          if (identical(_imageProvider, provider)) {
            _hasDecodedFrame = true;
          }
          return child;
        }
        if (identical(_imageProvider, provider)) {
          _hasDecodedFrame = false;
        }
        return _buildLoadingPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        LocalGalleryThumbnailMemoryCache.instance.releasePendingOwner(provider);
        AppLogger.e(
          'Local gallery thumbnail decode failed: ${widget.record.path}',
          error,
          stackTrace,
          'LocalImageCard3D',
        );
        return _buildErrorPlaceholder();
      },
    );
  }

  List<ImageCardAction> _buildActions() {
    final l10n = context.l10n;
    final watermarkEnabled = ref.watch(
      watermarkSettingsProvider.select((s) => s.configuration.enabled),
    );
    final mosaicEnabled = ref.watch(
      mosaicSettingsProvider.select((s) => s.configuration.enabled),
    );
    final storage = ref.read(localStorageServiceProvider);
    final metadata = widget.record.metadata;
    return [
      if (widget.onDoubleTap != null || widget.onTap != null)
        ImageCardAction(
          id: ImageCardActionId.viewDetail,
          icon: Icons.open_in_full,
          label: l10n.image_viewDetail,
          invoke: widget.onDoubleTap ?? widget.onTap!,
          showOnHover: false,
        ),
      if (widget.onFavoriteToggle != null)
        ImageCardAction(
          id: ImageCardActionId.favorite,
          icon: widget.record.isFavorite
              ? Icons.favorite
              : Icons.favorite_border,
          label: widget.record.isFavorite
              ? l10n.common_unfavorite
              : l10n.common_favorite,
          iconColor: widget.record.isFavorite ? Colors.red : Colors.white,
          invoke: widget.onFavoriteToggle!,
        ),
      ImageCardAction(
        id: ImageCardActionId.copy,
        icon: Icons.copy,
        label: l10n.shortcut_action_copy_image,
        isLoading: _isCopyingImage,
        invoke: _copyImageToClipboard,
      ),
      if (widget.onSendAction != null)
        ...LocalImageContextMenu.buildActions(
          context,
          onAction: widget.onSendAction!,
          hasImportableMetadata: metadata?.hasData == true,
          hasPrompt: true,
          hasSeed: metadata?.seed != null,
          isKritaConnected: widget.isKritaConnected,
          watermarkEnabled: watermarkEnabled,
          isWatermarkDerivative: WatermarkDerivativeRegistry(
            storage,
          ).isDerivative(widget.record.path),
          mosaicEnabled: mosaicEnabled,
          isMosaicDerivative: MosaicDerivativeRegistry(
            storage,
          ).isDerivative(widget.record.path),
        ).where(
          (a) =>
              widget.enableAddToAgent || a.id != ImageCardActionId.addToAgent,
        ),
      if (widget.onLongPress != null)
        ImageCardAction(
          id: ImageCardActionId.select,
          icon: Icons.check_circle_outline,
          label: l10n.common_multiSelect,
          invoke: widget.onLongPress!,
          showOnHover: false,
        ),
    ];
  }

  Widget _buildActionButtons(
    List<ImageCardAction> actions,
    Axis direction,
    double cardHeight,
  ) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (_) => _suppressCardTap = true,
    onPointerUp: (_) {
      scheduleMicrotask(() => _suppressCardTap = false);
    },
    onPointerCancel: (_) => _suppressCardTap = false,
    child: CardActionButtons(
      availableSize: Size(widget.width - 8, cardHeight - 8),
      visible: _isHovered || _isFocused,
      direction: direction,
      buttons: actions,
      groupMenus: {
        ImageCardActionGroup.use: (
          icon: Icons.send,
          label: context.l10n.localGallery_moreImageActions,
        ),
      },
    ),
  );

  Widget _buildSelectionIndicator(ColorScheme colorScheme) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.check, color: colorScheme.onPrimary, size: 18),
    );
  }
}
