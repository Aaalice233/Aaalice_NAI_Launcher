import '../../../selection/card_selection_scope.dart';
import '../../../widgets/common/image_card_frame.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../widgets/common/image_viewport_surface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../../data/services/precise_ref_library_storage_service.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/app_branch_visibility.dart';
import '../../../widgets/common/card_action_buttons.dart';
import '../../../widgets/common/image_card_actions.dart';
import '../../../widgets/common/image_card_action_region.dart';
import '../../../widgets/common/image_hover_preview_controller.dart';
import '../../../widgets/common/library_card_badges.dart';
import 'precise_ref_hover_preview.dart';

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
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelection,
    this.onEnterSelectionMode,
  });

  final PreciseRefLibraryEntry entry;
  final ImageCardCallback? onSendToPreciseRef;
  final ImageCardCallback? onSendToImg2Img;
  final ImageCardCallback? onEdit;
  final ImageCardCallback? onDelete;
  final ImageCardCallback? onToggleFavorite;
  final ImageCardCallback? onClassify;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onEnterSelectionMode;

  @override
  ConsumerState<PreciseRefCard> createState() => _PreciseRefCardState();
}

class _PreciseRefCardState extends ConsumerState<PreciseRefCard> {
  Uint8List? _thumbnail;
  bool _thumbnailRequested = false;
  bool _hovering = false;
  bool _isBranchVisible = true;
  Future<Uint8List?>? _hoverImageFuture;
  final ImageHoverPreviewController _hoverController =
      ImageHoverPreviewController();
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
    if (widget.isSelectionMode) _hoverController.dismiss();
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
    if (widget.isSelectionMode) return;
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
  Widget build(BuildContext context) => ImageCardActionRegion(
    resourceId: widget.entry.id,
    actions: _buildActions(),
    onMenuOpened: () => _hoverController.dismiss(),
    builder: _buildCard,
  );

  Widget _buildCard(BuildContext context, List<ImageCardAction> actions) {
    _loadThumbnailIfNeeded();
    final theme = Theme.of(context);
    final isTouch = context.interactionPolicy.usesTouchActionMenu;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: _onHoverEnter,
        onExit: _onHoverExit,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (CardSelectionScope.handleTap(context, widget.entry.id)) return;
            (widget.isSelectionMode
                    ? widget.onToggleSelection
                    : widget.onSendToPreciseRef)
                ?.call();
          },
          onLongPress: widget.isSelectionMode
              ? widget.onToggleSelection
              : widget.onEnterSelectionMode,
          child: ImageCardFrame(
            hovered: _hovering && !isTouch,
            selected: widget.isSelected,
            restingShadow: true,
            hoverScaleEnabled: !isTouch,
            hoverLift: 2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildThumbnail(theme),
                _buildInfoOverlay(theme),
                if (isTouch || !_hovering) _buildTypeBadge(),
                if (widget.isSelectionMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Checkbox(
                      value: widget.isSelected,
                      onChanged: (_) => widget.onToggleSelection?.call(),
                    ),
                  )
                else if (!isTouch && !_hovering && widget.entry.isFavorite)
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
                if (!widget.isSelectionMode)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: LayoutBuilder(
                      builder: (context, constraints) => CardActionButtons(
                        menuKey: Key(
                          'precise-ref-card-more-${widget.entry.id}',
                        ),
                        touchShortcuts: const {ImageCardActionId.favorite},
                        touchDirection: Axis.horizontal,
                        visible: isTouch || _hovering,
                        direction: Axis.vertical,
                        buttons: actions,
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

  Widget _buildThumbnail(ThemeData theme) {
    if (_thumbnail != null) {
      return Image.memory(
        _thumbnail!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return const ColoredBox(
      color: ImageViewportSurface.background,
      child: Icon(
        Icons.image_outlined,
        size: 36,
        color: ImageViewportSurface.mutedForeground,
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

  List<ImageCardAction> _buildActions() {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final entry = widget.entry;
    final onAddToAgent = ImageCardActionScope.maybeOf(context)?.onAddToAgent;
    return [
      if (onAddToAgent != null)
        ImageCardAction(
          id: ImageCardActionId.addToAgent,
          key: Key('precise-ref-card-agent-${entry.id}'),
          icon: Icons.auto_awesome_outlined,
          label: l10n.agentChat_addResource,
          invoke: onAddToAgent,
        ),
      ImageCardAction(
        id: ImageCardActionId.favorite,
        key: Key('precise-ref-card-favorite-${entry.id}'),
        icon: entry.isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        iconColor: entry.isFavorite ? theme.colorScheme.error : null,
        label: entry.isFavorite ? l10n.common_unfavorite : l10n.common_favorite,
        invoke: widget.onToggleFavorite ?? () {},
        enabled: widget.onToggleFavorite != null,
      ),
      ImageCardAction(
        id: ImageCardActionId.preciseReference,
        key: Key('precise-ref-card-send-${entry.id}'),
        icon: Icons.center_focus_strong,
        label: l10n.preciseRefLib_sendToPreciseRef,
        invoke: widget.onSendToPreciseRef ?? () {},
        enabled: widget.onSendToPreciseRef != null,
      ),
      ImageCardAction(
        id: ImageCardActionId.imageToImage,
        key: Key('precise-ref-card-img2img-${entry.id}'),
        icon: Icons.image_outlined,
        label: l10n.preciseRefLib_sendToImg2Img,
        invoke: widget.onSendToImg2Img ?? () {},
        enabled: widget.onSendToImg2Img != null,
      ),
      ImageCardAction(
        id: ImageCardActionId.edit,
        key: Key('precise-ref-card-edit-${entry.id}'),
        icon: Icons.edit_outlined,
        label: l10n.preciseRefLib_editEntry,
        invoke: widget.onEdit ?? () {},
        enabled: widget.onEdit != null,
      ),
      ImageCardAction(
        isDanger: true,
        id: ImageCardActionId.delete,
        key: Key('precise-ref-card-delete-${entry.id}'),
        icon: Icons.delete_outline,
        iconColor: theme.colorScheme.error,
        label: l10n.preciseRefLib_deleteEntry,
        invoke: widget.onDelete ?? () {},
        enabled: widget.onDelete != null,
      ),

      if (widget.onClassify != null)
        ImageCardAction(
          id: ImageCardActionId.classify,
          icon: Icons.category_outlined,
          label: l10n.preciseRef_referenceType,
          invoke: widget.onClassify!,
        ),
      if (widget.onEnterSelectionMode != null)
        ImageCardAction(
          id: ImageCardActionId.select,
          icon: Icons.check_circle_outline,
          label: l10n.common_multiSelect,
          invoke: widget.onEnterSelectionMode!,
          showOnHover: false,
        ),
    ];
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
