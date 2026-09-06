import 'dart:async';

import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
import '../../../core/utils/localization_extension.dart';
import '../../themes/theme_extension.dart';
import 'animated_favorite_button.dart';
import 'card_action_buttons.dart';
import 'decoded_memory_image.dart';
import 'image_card_actions.dart';
import 'image_card_controller.dart';
import 'image_card_effects.dart';
import 'image_card_hover_motion.dart';
import 'image_card_models.dart';
import 'image_card_stream_preview.dart';

class ImageCardSurface extends StatelessWidget {
  const ImageCardSurface({
    super.key,
    required this.data,
    required this.capabilities,
    required this.controller,
    required this.actions,
    required this.onShowContextMenu,
    required this.onWarmShareCache,
  });

  final ImageCardViewData data;
  final ImageCardCapabilities capabilities;
  final ImageCardController controller;
  final List<ImageCardAction> actions;
  final Future<void> Function(Offset position) onShowContextMenu;
  final VoidCallback onWarmShareCache;

  @override
  Widget build(BuildContext context) {
    if (data.imageBytes == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildSurface(context),
    );
  }

  Widget _buildSurface(BuildContext context) {
    final theme = Theme.of(context);
    final motion = theme.appTheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final hoverActions = actions.where((action) => action.showOnHover).toList();
    final showIndexBadge =
        data.dragPreparationReady &&
        controller.showPreparedIndexBadge &&
        data.showIndex &&
        data.index != null &&
        !controller.isHovering;

    return MouseRegion(
      onEnter: (_) => controller.hoverEnter(warmShareCache: onWarmShareCache),
      onExit: (_) => controller.hoverExit(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: capabilities.onDoubleTap == null
            ? controller.handleLegacyTap
            : null,
        onTapUp: capabilities.onDoubleTap != null
            ? controller.handleLinkedTapUp
            : null,
        onLongPressStart:
            capabilities.onLongPress != null || capabilities.enableContextMenu
            ? (details) {
                controller.clearPendingDoubleTap();
                if (capabilities.onLongPress != null) {
                  capabilities.onLongPress!.call();
                } else {
                  unawaited(onShowContextMenu(details.globalPosition));
                }
              }
            : null,
        // 必须抬起后弹菜单：按住时 push 会合成 touch 取消事件，令 DraggableWidget 整批重建闪烁
        onSecondaryTapUp: capabilities.enableContextMenu
            ? (details) => unawaited(onShowContextMenu(details.globalPosition))
            : null,
        child: ImageCardHoverMotion(
          hovered: controller.isHovering,
          enabled: capabilities.enableHoverScale,
          child: AnimatedContainer(
            duration: reducedMotion || !capabilities.hoverEffectsEnabled
                ? Duration.zero
                : motion.fastDuration,
            curve: motion.standardCurve,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: data.isSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : data.isPreviewActive
                  ? Border.all(color: theme.colorScheme.tertiary, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: data.isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.16)
                      : Colors.black.withValues(
                          alpha: controller.isHovering ? 0.16 : 0.08,
                        ),
                  blurRadius: controller.isHovering ? 14 : 6,
                  offset: Offset(0, controller.isHovering ? 6 : 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (data.imageContent != null && data.underlay != null)
                    data.underlay!,
                  RepaintBoundary(
                    child: data.imageContent ?? _completedImage(theme),
                  ),
                  _DragPreparationOverlay(data: data, controller: controller),
                  if (controller.isHovering && capabilities.enableGlossEffect)
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: reducedMotion
                            ? Duration.zero
                            : motion.fastDuration,
                        curve: motion.standardCurve,
                        builder: (context, glowIntensity, _) => AnimatedBuilder(
                          animation: controller.glossAnimation,
                          builder: (context, _) => ImageCardEffects(
                            glowColor: theme.colorScheme.primary,
                            glowIntensity: glowIntensity,
                            glossProgress: controller.glossAnimation.value,
                          ),
                        ),
                      ),
                    ),
                  if (controller.isHovering || data.isSelected)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (data.statusBadgeLabel != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _StatusBadge(data: data),
                    ),
                  if (capabilities.enableSelection &&
                      data.statusBadgeLabel == null &&
                      (controller.isHovering || data.isSelected))
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _SelectionCheckbox(
                        selected: data.isSelected,
                        onChanged: capabilities.onSelectionChanged,
                      ),
                    ),
                  if (capabilities.onFavoriteToggle != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CardFavoriteButton(
                        isFavorite: data.isFavorite,
                        onToggle: capabilities.onFavoriteToggle,
                        size: 17,
                        borderRadius: 999,
                      ),
                    ),
                  if (controller.isHovering && hoverActions.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: ImageCardHoverActionBar(actions: hoverActions),
                    ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Offstage(
                      key: const ValueKey(
                        'selectable-image-index-badge-offstage',
                      ),
                      offstage: !showIndexBadge,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data.index == null ? '' : '${data.index! + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (data.isSelected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (context.interactionPolicy.shouldExposeTouchAlternatives &&
                      (!controller.isHovering ||
                          context.interactionPolicy.prefersTouchPresentation) &&
                      capabilities.enableContextMenu &&
                      actions.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: IconButton(
                        onPressed: () =>
                            unawaited(onShowContextMenu(Offset.zero)),
                        tooltip: context.l10n.common_moreActions,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        style: ImageOverlayControlStyle.iconButton(
                          context,
                          extent: 48,
                        ),
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _completedImage(ThemeData theme) {
    return DecodedMemoryImage(
      key: const ValueKey('selectable-image-content'),
      bytes: data.imageBytes!,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          _composeCompletedImage(
            theme: theme,
            ready: frame != null || wasSynchronouslyLoaded,
            child: controller.completedImageFrameBuilder(
              context,
              child,
              frame,
              wasSynchronouslyLoaded,
            ),
          ),
      errorBuilder: (context, _, _) => const SizedBox.shrink(),
    );
  }

  /// 首帧之前继续画生成中卡片的最后一帧，不铺底层，避免闪出棋盘格。
  Widget _composeCompletedImage({
    required ThemeData theme,
    required bool ready,
    required Widget child,
  }) {
    // 换源会把 frame 归零，但旧帧仍在 gapless 画，此时藏底层会让透明区闪一下。
    final showsImage = ready || controller.hasPaintedCompletedImage;
    final holdover = controller.effectiveCompletionPreview;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!showsImage) ...[
          if (holdover != null)
            ImageCardStreamPreview(
              previewBytes: holdover.bytes,
              placement: holdover.placement,
            )
          // 只有铺了底层的卡片需要兜底色遮住它，其余卡片首帧前保持原本的空白。
          else if (data.underlay != null)
            ColoredBox(color: theme.colorScheme.surface),
        ],
        if (showsImage && data.underlay != null) data.underlay!,
        child,
      ],
    );
  }
}

class ImageCardHoverActionBar extends StatelessWidget {
  const ImageCardHoverActionBar({super.key, required this.actions});

  final List<ImageCardAction> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const ValueKey('image-card-hover-action-bar-surface'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ImageOverlayControlStyle.toolbarSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ImageOverlayControlStyle.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final action in actions) _HoverAction(action: action),
          ],
        ),
      ),
    );
  }
}

class _HoverAction extends StatelessWidget {
  const _HoverAction({required this.action});
  final ImageCardAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final action = this.action;
    final interaction = context.interactionPolicy;
    return IconButton(
      tooltip: action.label,
      onPressed: action.invoke,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.square(40)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          final emphasized = interaction.isControlHighlighted(states);
          if (action.isPrimary) {
            return colors.primary.withValues(alpha: emphasized ? 1 : 0.9);
          }
          return emphasized
              ? ImageOverlayControlStyle.foreground.withValues(alpha: 0.16)
              : Colors.transparent;
        }),
        foregroundColor: WidgetStatePropertyAll(
          action.isPrimary
              ? colors.onPrimary
              : ImageOverlayControlStyle.foreground,
        ),
      ),
      icon: Icon(action.icon, size: 20),
    );
  }
}

class _DragPreparationOverlay extends StatelessWidget {
  const _DragPreparationOverlay({required this.data, required this.controller});
  final ImageCardViewData data;
  final ImageCardController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          key: const ValueKey('drag-preparation-preview-overlay-opacity'),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ImageCardController.dragPreparationOverlayFadeDuration,
          curve: Theme.of(context).appTheme.standardCurve,
          opacity: data.dragPreparationReady ? 0 : 1,
          onEnd: controller.markPreparedIndexBadgeVisible,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Theme.of(
                        context,
                      ).colorScheme.scrim.withValues(alpha: 0.38),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        key: const ValueKey(
                          'drag-preparation-preview-progress-ring',
                        ),
                        value: ImageCardController.dragPreparationProgressValue,
                        strokeWidth: 2,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onInverseSurface.withValues(alpha: 0.2),
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(ImageCardController.dragPreparationProgressValue * 100).toInt()}%',
                      key: const ValueKey(
                        'drag-preparation-preview-progress-percent',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.data});
  final ImageCardViewData data;

  @override
  Widget build(BuildContext context) {
    final label = data.statusBadgeLabel!;
    return Tooltip(
      message: data.statusBadgeTooltip ?? label,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.inverseSurface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onInverseSurface,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({required this.selected, required this.onChanged});
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: 40,
      child: Checkbox(
        value: selected,
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) onChanged!(value);
              },
        shape: const CircleBorder(),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? theme.colorScheme.primary
                : theme.colorScheme.onInverseSurface.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? theme.colorScheme.primary
              : theme.colorScheme.inverseSurface.withValues(alpha: 0.72),
        ),
        checkColor: theme.colorScheme.onPrimary,
      ),
    );
  }
}
