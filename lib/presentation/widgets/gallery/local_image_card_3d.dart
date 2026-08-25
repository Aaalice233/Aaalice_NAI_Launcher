import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/local_gallery_thumbnail_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../providers/share_image_settings_provider.dart';
import '../../utils/clipboard_image.dart';
import '../common/app_toast.dart';
import '../common/card_action_buttons.dart';
import 'local_image_context_menu.dart';
import 'local_image_hover_preview.dart';

/// Steam风格本地图片卡片，包含边缘发光、光泽扫过、悬停动画效果
class LocalImageCard3D extends ConsumerStatefulWidget {
  final LocalImageRecord record;
  final double width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(TapDownDetails)? onSecondaryTapDown;
  final bool isSelected;
  final bool showFavoriteIndicator;
  final VoidCallback? onFavoriteToggle;
  final Future<void> Function(LocalImageContextAction action)? onSendAction;
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
    this.onSecondaryTapDown,
    this.isSelected = false,
    this.showFavoriteIndicator = true,
    this.onFavoriteToggle,
    this.onSendAction,
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

    try {
      final sourceFile = File(widget.record.path);
      if (!await sourceFile.exists()) {
        if (mounted) AppToast.error(context, context.l10n.gallery_fileMissing);
        return;
      }

      final stripMetadata = ref
          .read(shareImageSettingsProvider)
          .effectiveStripMetadataForCopyAndDrag;
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardHeight = widget.height ?? widget.width;
    final colorScheme = theme.colorScheme;
    final aspectRatio = widget.width / cardHeight;
    final buttonDirection = aspectRatio > 1.3 ? Axis.horizontal : Axis.vertical;

    Widget cardContent = GestureDetector(
      onTap: widget.onTap == null ? null : _handleCardTap,
      onTapCancel: _handleCardTapCancel,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      onSecondaryTapDown: widget.onSecondaryTapDown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: widget.width,
        height: cardHeight,
        transform: Matrix4.identity()
          ..translateByDouble(0, _isHovered ? -4 : 0, 0, 1)
          ..scaleByDouble(
            _isHovered ? 1.02 : 1.0,
            _isHovered ? 1.02 : 1.0,
            _isHovered ? 1.02 : 1.0,
            1,
          ),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: widget.isSelected
              ? Border.all(color: colorScheme.primary, width: 3)
              : _isHovered
              ? Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImageLayer(),
              Positioned(
                top: 4,
                right: buttonDirection == Axis.vertical ? 4 : null,
                left: buttonDirection == Axis.horizontal ? 4 : null,
                child: _buildActionButtons(buttonDirection),
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
      ),
    );

    // 如果提供了 dragWrapper，使用它包装卡片内容
    // 这样 DragItemWidget 可以正确接收拖拽手势
    if (widget.dragWrapper != null) {
      cardContent = widget.dragWrapper!(cardContent);
    }

    return LocalImageHoverPreview(
      record: widget.record,
      child: MouseRegion(
        onEnter: _onHoverEnter,
        onExit: _onHoverExit,
        cursor: SystemMouseCursors.click,
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
                minimumSize: Size.zero,
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

  Widget _buildActionButtons(Axis direction) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _suppressCardTap = true,
      onPointerUp: (_) {
        scheduleMicrotask(() => _suppressCardTap = false);
      },
      onPointerCancel: (_) => _suppressCardTap = false,
      child: CardActionButtons(
        visible: _isHovered,
        direction: direction,
        buttons: [
          if (widget.onFavoriteToggle != null)
            CardActionButtonConfig(
              icon: widget.record.isFavorite
                  ? Icons.favorite
                  : Icons.favorite_border,
              tooltip: widget.record.isFavorite
                  ? context.l10n.common_unfavorite
                  : context.l10n.common_favorite,
              iconColor: widget.record.isFavorite ? Colors.red : Colors.white,
              onPressed: widget.onFavoriteToggle!,
            ),
          CardActionButtonConfig(
            icon: Icons.copy,
            tooltip: context.l10n.shortcut_action_copy_image,
            isLoading: _isCopyingImage,
            onPressed: _copyImageToClipboard,
          ),
          if (widget.onSendAction != null) ...[
            CardActionButtonConfig(
              icon: Icons.text_snippet_outlined,
              tooltip: context.l10n.localGallery_copyPrompt,
              onPressed: () => unawaited(
                widget.onSendAction!(LocalImageContextAction.copyPrompt),
              ),
            ),
            CardActionButtonConfig(
              icon: Icons.delete_outline,
              tooltip: context.l10n.common_delete,
              onPressed: () => unawaited(
                widget.onSendAction!(LocalImageContextAction.delete),
              ),
            ),
            CardActionButtonConfig(
              icon: Icons.send,
              tooltip: context.l10n.detail_sendToImg2Img,
              onPressed: () => unawaited(_showSendMenu(context)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSendMenu(BuildContext context) async {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;

    final offset = button.localToGlobal(Offset.zero);
    const menuWidth = 320.0;
    double left = offset.dx - menuWidth - 8;
    final top = offset.dy;

    if (left < 8) left = offset.dx + button.size.width + 8;

    final action = await LocalImageContextMenu.showSendActions(
      context,
      position: Offset(left, top),
      isKritaConnected: widget.isKritaConnected,
    );
    if (action == null || !mounted) return;

    await widget.onSendAction?.call(action);
  }

  Widget _buildSelectionIndicator(ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.check, color: colorScheme.onPrimary, size: 18),
      ),
    );
  }
}
