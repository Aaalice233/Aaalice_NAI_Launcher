import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../../themes/prompt_semantic_colors.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/thumbnail_display.dart';
import '../../../widgets/common/tile_action_button.dart';
import '../../../widgets/tag_library/tag_library_entry_hover_preview.dart';

typedef SidebarDragHandleBuilder = Widget Function(Widget child);

/// A fixed-tag row or preview card.
///
/// List and grid presentations share the same action, status, and text
/// building blocks so their capabilities cannot drift apart.
class SidebarEntryTile extends StatefulWidget {
  const SidebarEntryTile({
    super.key,
    required this.entry,
    required this.categoryColor,
    required this.isListMode,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.linkAnchor,
    this.libraryEntry,
    this.dragHandleBuilder,
  });

  final FixedTagEntry entry;
  final Color categoryColor;
  final bool isListMode;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget? linkAnchor;
  final TagLibraryEntry? libraryEntry;
  final SidebarDragHandleBuilder? dragHandleBuilder;

  @override
  State<SidebarEntryTile> createState() => _SidebarEntryTileState();
}

class _SidebarEntryTileState extends State<SidebarEntryTile> {
  bool _isHovering = false;
  bool _isFocused = false;

  bool get _hasThumbnail =>
      !widget.isListMode && (widget.libraryEntry?.hasThumbnail ?? false);

  // 操作按钮常驻，未聚焦时压暗，让行高和文本宽度不随指针移动跳变。
  bool get _actionsHighlighted =>
      _isHovering ||
      _isFocused ||
      !context.interactionPolicy.precisePointerAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = Semantics(
      selected: widget.entry.enabled,
      child: MouseRegion(
        onEnter: (_) {
          if (context.interactionPolicy.precisePointerAvailable) {
            setState(() => _isHovering = true);
          }
        },
        onExit: (_) => setState(() => _isHovering = false),
        child: Material(
          color: _backgroundColor(theme),
          borderRadius: BorderRadius.circular(widget.isListMode ? 6 : 10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.isListMode ? 6 : 10),
            onFocusChange: (focused) => setState(() => _isFocused = focused),
            onTap: widget.onToggle,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              color: _isHovering
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.045)
                  : Colors.transparent,
              child: widget.isListMode
                  ? _buildListContent(theme)
                  : _buildCardContent(theme),
            ),
          ),
        ),
      ),
    );

    final libraryEntry = widget.libraryEntry;
    if (libraryEntry == null ||
        !context.interactionPolicy.precisePointerAvailable) {
      return tile;
    }
    return TagLibraryEntryHoverPreview(entry: libraryEntry, child: tile);
  }

  Color _backgroundColor(ThemeData theme) {
    final resting = controlSurfaceColor(theme.colorScheme);
    return widget.entry.enabled
        ? Color.alphaBlend(_statusColor(theme).withValues(alpha: 0.22), resting)
        : resting;
  }

  Color _statusColor(ThemeData theme) =>
      widget.entry.promptType == FixedTagPromptType.positive
      ? theme.promptSemanticColors.positiveFixedTag
      : theme.promptSemanticColors.negativeFixedTag;

  Widget _buildListContent(ThemeData theme) {
    final leading = [
      _buildStatusIcon(theme),
      const SizedBox(width: 7),
      if (widget.linkAnchor != null) ...[
        widget.linkAnchor!,
        const SizedBox(width: 4),
      ],
    ];
    final label = _buildDragRegion(
      _buildText(theme, maxLines: 1, includeWeight: true),
    );
    // 大字号下行内操作会把名称和权重挤没，整体换到第二行而不是收进菜单。
    final stacksActions = MediaQuery.textScalerOf(context).scale(14) >= 20;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: stacksActions
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ...leading,
                    Expanded(child: label),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildActions(theme),
                ),
              ],
            )
          : Row(
              children: [
                ...leading,
                Expanded(child: label),
                const SizedBox(width: 6),
                _buildActions(theme),
              ],
            ),
    );
  }

  Widget _buildCardContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasThumbnail)
          Expanded(flex: 3, child: _buildThumbnail(widget.libraryEntry!)),
        Expanded(
          flex: _hasThumbnail ? 5 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 7, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDragRegion(
                    _buildText(
                      theme,
                      maxLines: _hasThumbnail ? 1 : 2,
                      includeWeight: true,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (widget.linkAnchor != null) widget.linkAnchor!,
                    const Spacer(),
                    _buildActions(theme),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(TagLibraryEntry libraryEntry) {
    return LayoutBuilder(
      builder: (context, constraints) => ThumbnailDisplay(
        imagePath: libraryEntry.thumbnail!,
        offsetX: libraryEntry.thumbnailOffsetX,
        offsetY: libraryEntry.thumbnailOffsetY,
        scale: libraryEntry.thumbnailScale,
        width: constraints.maxWidth,
        height: constraints.maxHeight,
      ),
    );
  }

  Widget _buildDragRegion(Widget child) {
    final builder = widget.dragHandleBuilder;
    if (builder == null) return child;
    return MouseRegion(cursor: SystemMouseCursors.grab, child: builder(child));
  }

  Widget _buildText(
    ThemeData theme, {
    required int maxLines,
    bool includeWeight = false,
  }) {
    final foreground = widget.entry.enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!widget.isListMode) ...[
              _buildStatusIcon(theme),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                widget.entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: widget.entry.enabled
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
            // 权重宽度随字号增长，留成 Flexible 兜底，任何窄行都不会溢出。
            if (includeWeight) ...[
              const SizedBox(width: 6),
              Flexible(child: _buildWeight(theme)),
            ],
          ],
        ),
        if (widget.isListMode) const SizedBox(height: 1),
        Text(
          widget.entry.content,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    return Icon(
      widget.entry.enabled ? Icons.check_circle : Icons.radio_button_unchecked,
      size: 18,
      color: widget.entry.enabled
          ? widget.categoryColor
          : theme.colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildWeight(ThemeData theme) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Text(
        widget.entry.weight.toStringAsFixed(2),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    final resting = theme.colorScheme.onSurfaceVariant;
    return AnimatedOpacity(
      key: const ValueKey('sidebar-entry-actions'),
      opacity: _actionsHighlighted ? 1 : 0.4,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TileActionButton(
            icon: Icons.copy_rounded,
            tooltip: context.l10n.common_copy,
            color: resting,
            hoverColor: theme.colorScheme.primary,
            onPressed: () => unawaited(_copyContent()),
          ),
          TileActionButton(
            icon: Icons.edit_rounded,
            tooltip: context.l10n.common_edit,
            color: resting,
            hoverColor: theme.colorScheme.primary,
            onPressed: widget.onEdit,
          ),
          TileActionButton(
            icon: Icons.delete_outline_rounded,
            tooltip: context.l10n.common_delete,
            color: resting,
            hoverColor: theme.colorScheme.error,
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _copyContent() async {
    await Clipboard.setData(ClipboardData(text: widget.entry.content));
    if (!mounted) return;
    AppToast.info(context, context.l10n.common_copied);
  }
}
