import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../../data/services/precise_ref_library_storage_service.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/app_branch_visibility.dart';
import '../../../widgets/common/card_action_buttons.dart';
import '../../../widgets/common/card_hover_preview_controller.dart';
import '../../../widgets/common/image_card_actions.dart';
import '../../../widgets/common/image_card_hover_motion.dart';
import '../../../widgets/common/library_card_badges.dart';
import 'precise_ref_hover_preview.dart';

enum _PreciseRefCardAction {
  addToAgent,
  sendToPreciseRef,
  sendToImg2Img,
  edit,
  classify,
  delete,
}

/// 精准参考库条目卡片
///
/// 缩略图按需从存储服务加载；悬停显示动作按钮。
/// 单击卡片等同于「发送到精准参考」。
class PreciseRefCard extends ConsumerStatefulWidget {
  const PreciseRefCard({
    super.key,
    required this.entry,
    this.onSendToPreciseRef,
    this.onSendToImg2Img,
    this.onEdit,
    this.onDelete,
    this.onToggleFavorite,
    this.onClassify,
  });

  final PreciseRefLibraryEntry entry;
  final VoidCallback? onSendToPreciseRef;
  final VoidCallback? onSendToImg2Img;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onClassify;

  @override
  ConsumerState<PreciseRefCard> createState() => _PreciseRefCardState();
}

class _PreciseRefCardState extends ConsumerState<PreciseRefCard> {
  Uint8List? _thumbnail;
  bool _thumbnailRequested = false;
  bool _hovering = false;
  bool _isBranchVisible = true;
  Future<Uint8List?>? _hoverImageFuture;
  final CardHoverPreviewController _hoverController =
      CardHoverPreviewController();
  final LayerLink _layerLink = LayerLink();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasVisible = _isBranchVisible;
    _isBranchVisible = AppBranchVisibility.of(context);
    if (_isBranchVisible && !wasVisible && _thumbnail == null) {
      _thumbnailRequested = false;
    }
  }

  @override
  void didUpdateWidget(covariant PreciseRefCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _hoverController.dismissFor(oldWidget.entry.id);
      _thumbnail = null;
      _thumbnailRequested = false;
      _hoverImageFuture = null;
      _hovering = false;
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _loadThumbnailIfNeeded() {
    if (_thumbnailRequested) return;
    _thumbnailRequested = true;
    final id = widget.entry.id;
    final storage = ref.read(preciseRefLibraryStorageServiceProvider);
    // 内存缓存同步命中时直接赋值，让卡片重建后的首帧就有图
    final cached = storage.peekDisplayThumbnail(id);
    if (cached != null && cached.isNotEmpty) {
      _thumbnail = cached;
      return;
    }
    storage
        .getDisplayThumbnail(
          id,
          isCancelled: () =>
              !mounted || widget.entry.id != id || !_isBranchVisible,
        )
        .then((bytes) {
          if (!mounted || widget.entry.id != id) return;
          if (_isBranchVisible) {
            setState(() => _thumbnail = bytes);
          } else {
            // IndexedStack 会保留隐藏分支；只缓存结果，不把隐藏卡片标脏。
            _thumbnail = bytes;
          }
        });
  }

  String _typeDisplayName(BuildContext context) {
    final l10n = context.l10n;
    return widget.entry.type.getDisplayName(
      character: l10n.preciseRef_typeCharacter,
      style: l10n.preciseRef_typeStyle,
      characterAndStyle: l10n.preciseRef_typeCharacterAndStyle,
    );
  }

  void _onHoverEnter(PointerEvent event) {
    setState(() => _hovering = true);
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final previewSize = computePreciseRefHoverPreviewBounds(
      MediaQuery.sizeOf(context),
    );
    if (previewSize.isEmpty) return;

    _hoverImageFuture ??= ref
        .read(preciseRefLibraryStorageServiceProvider)
        .readImageBytes(widget.entry.id);
    final targetRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    _hoverController.schedule(
      context: context,
      stableKey: widget.entry.id,
      layerLink: _layerLink,
      targetRect: targetRect,
      previewSize: previewSize,
      builder: (_) => PreciseRefHoverPreview(
        entry: widget.entry,
        imageFuture: _hoverImageFuture!,
        fallbackImage: _thumbnail,
        maxWidth: previewSize.width,
        maxHeight: previewSize.height,
      ),
    );
  }

  void _onHoverExit(PointerEvent event) {
    setState(() => _hovering = false);
    _hoverController.dismissFor(widget.entry.id);
  }

  @override
  Widget build(BuildContext context) {
    _loadThumbnailIfNeeded();
    final theme = Theme.of(context);
    final isTouch = context.interactionPolicy.shouldExposeTouchAlternatives;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: _onHoverEnter,
        onExit: _onHoverExit,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onSendToPreciseRef,
          child: ImageCardHoverMotion(
            hovered: _hovering,
            enabled: !isTouch,
            child: AnimatedContainer(
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translateByDouble(0, _hovering && !isTouch ? -2 : 0, 0, 1),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _hovering ? 0.18 : 0.08,
                    ),
                    blurRadius: _hovering ? 16 : 6,
                    offset: Offset(0, _hovering ? 7 : 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(theme),
                    _buildInfoOverlay(theme),
                    if (isTouch || !_hovering) _buildTypeBadge(),
                    if (!isTouch && !_hovering && widget.entry.isFavorite)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: LibraryCardFavoriteBadge(
                          key: Key(
                            'precise-ref-card-favorite-badge-${widget.entry.id}',
                          ),
                          semanticLabel: context.l10n.common_favorite,
                        ),
                      ),
                    if (isTouch) ...[
                      Positioned(
                        top: 6,
                        right: 54,
                        child: _buildFavoriteButton(theme),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _buildTouchActions(theme),
                      ),
                    ] else if (_hovering)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _buildDesktopActions(theme),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    if (_thumbnail != null) {
      return Image.memory(
        _thumbnail!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        size: 36,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final entry = widget.entry;
    return Positioned(
      top: 8,
      left: 8,
      child: LibraryCardCategoryBadge(
        icon: entry.type.icon,
        label: _typeDisplayName(context),
      ),
    );
  }

  Widget _buildInfoOverlay(ThemeData theme) {
    final entry = widget.entry;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 30, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'S ${_formatParam(entry.strength)} · F ${_formatParam(entry.fidelity)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(ThemeData theme) {
    final entry = widget.entry;
    return IconButton(
      key: Key('precise-ref-card-favorite-${entry.id}'),
      tooltip: entry.isFavorite
          ? context.l10n.common_unfavorite
          : context.l10n.common_favorite,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      style: ImageOverlayControlStyle.iconButton(
        extent: 48,
        foregroundColor: entry.isFavorite ? theme.colorScheme.error : null,
      ),
      iconSize: 18,
      icon: Icon(
        entry.isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
      ),
      onPressed: widget.onToggleFavorite,
    );
  }

  Widget _buildDesktopActions(ThemeData theme) {
    final l10n = context.l10n;
    final entry = widget.entry;
    final onAddToAgent = ImageCardActionScope.maybeOf(context)?.onAddToAgent;
    return CardActionButtons(
      visible: true,
      direction: Axis.vertical,
      buttons: [
        if (onAddToAgent != null)
          CardActionButtonConfig(
            key: Key('precise-ref-card-agent-${entry.id}'),
            icon: Icons.auto_awesome_outlined,
            tooltip: l10n.agentChat_addResource,
            onPressed: onAddToAgent,
          ),
        CardActionButtonConfig(
          key: Key('precise-ref-card-favorite-${entry.id}'),
          icon: entry.isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          iconColor: entry.isFavorite ? theme.colorScheme.error : null,
          tooltip: entry.isFavorite
              ? l10n.common_unfavorite
              : l10n.common_favorite,
          onPressed: widget.onToggleFavorite ?? () {},
          enabled: widget.onToggleFavorite != null,
        ),
        CardActionButtonConfig(
          key: Key('precise-ref-card-send-${entry.id}'),
          icon: Icons.center_focus_strong,
          tooltip: l10n.preciseRefLib_sendToPreciseRef,
          onPressed: widget.onSendToPreciseRef ?? () {},
          enabled: widget.onSendToPreciseRef != null,
        ),
        CardActionButtonConfig(
          key: Key('precise-ref-card-img2img-${entry.id}'),
          icon: Icons.image_outlined,
          tooltip: l10n.preciseRefLib_sendToImg2Img,
          onPressed: widget.onSendToImg2Img ?? () {},
          enabled: widget.onSendToImg2Img != null,
        ),
        CardActionButtonConfig(
          key: Key('precise-ref-card-edit-${entry.id}'),
          icon: Icons.edit_outlined,
          tooltip: l10n.preciseRefLib_editEntry,
          onPressed: widget.onEdit ?? () {},
          enabled: widget.onEdit != null,
        ),
        CardActionButtonConfig(
          key: Key('precise-ref-card-delete-${entry.id}'),
          icon: Icons.delete_outline,
          iconColor: theme.colorScheme.error,
          tooltip: l10n.preciseRefLib_deleteEntry,
          onPressed: widget.onDelete ?? () {},
          enabled: widget.onDelete != null,
        ),
      ],
    );
  }

  Widget _buildTouchActions(ThemeData theme) {
    final l10n = context.l10n;
    final onAddToAgent = ImageCardActionScope.maybeOf(context)?.onAddToAgent;
    return PopupMenuButton<_PreciseRefCardAction>(
      key: Key('precise-ref-card-more-${widget.entry.id}'),
      tooltip: l10n.preciseRefLib_moreActions,
      constraints: const BoxConstraints(minWidth: 220),
      onSelected: (action) {
        switch (action) {
          case _PreciseRefCardAction.addToAgent:
            onAddToAgent?.call();
          case _PreciseRefCardAction.sendToPreciseRef:
            widget.onSendToPreciseRef?.call();
          case _PreciseRefCardAction.sendToImg2Img:
            widget.onSendToImg2Img?.call();
          case _PreciseRefCardAction.edit:
            widget.onEdit?.call();
          case _PreciseRefCardAction.classify:
            widget.onClassify?.call();
          case _PreciseRefCardAction.delete:
            widget.onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        if (onAddToAgent != null)
          PopupMenuItem(
            value: _PreciseRefCardAction.addToAgent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(l10n.agentChat_addResource),
            ),
          ),
        PopupMenuItem(
          value: _PreciseRefCardAction.sendToPreciseRef,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.center_focus_strong),
            title: Text(l10n.preciseRefLib_sendToPreciseRef),
          ),
        ),
        PopupMenuItem(
          value: _PreciseRefCardAction.sendToImg2Img,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined),
            title: Text(l10n.preciseRefLib_sendToImg2Img),
          ),
        ),
        PopupMenuItem(
          value: _PreciseRefCardAction.edit,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.preciseRefLib_editEntry),
          ),
        ),
        PopupMenuItem(
          value: _PreciseRefCardAction.classify,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.category_outlined),
            title: Text(l10n.preciseRef_referenceType),
          ),
        ),
        PopupMenuItem(
          value: _PreciseRefCardAction.delete,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(l10n.preciseRefLib_deleteEntry),
          ),
        ),
      ],
    );
  }

  static String _formatParam(double value) {
    final text = value.toStringAsFixed(2);
    if (text.endsWith('0')) {
      final shorter = value.toStringAsFixed(1);
      return shorter;
    }
    return text;
  }
}
