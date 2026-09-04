import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/thumbnail_display.dart';
import '../../../widgets/common/translated_tag_text.dart';
import '../../../widgets/tag_library/tag_library_entry_hover_preview.dart';

typedef SidebarDragHandleBuilder = Widget Function(Widget child);

enum _SidebarEntryAction { copy, edit, delete }

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

  bool get _showActionMenu =>
      _isHovering ||
      _isFocused ||
      context.interactionPolicy.shouldExposeTouchAlternatives ||
      MediaQuery.textScalerOf(context).scale(14) >= 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = MouseRegion(
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
    );

    final libraryEntry = widget.libraryEntry;
    if (libraryEntry == null ||
        !context.interactionPolicy.precisePointerAvailable) {
      return tile;
    }
    return TagLibraryEntryHoverPreview(entry: libraryEntry, child: tile);
  }

  Color _backgroundColor(ThemeData theme) {
    if (widget.isListMode) {
      return widget.entry.enabled
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
          : Colors.transparent;
    }
    return widget.entry.enabled
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.65);
  }

  Widget _buildListContent(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          _buildStatusDot(),
          const SizedBox(width: 7),
          if (widget.linkAnchor != null) ...[
            widget.linkAnchor!,
            const SizedBox(width: 4),
          ],
          Expanded(
            child: _buildDragRegion(
              _buildText(theme, maxLines: 1, includeWeight: true),
            ),
          ),
          const SizedBox(width: 6),
          if (_showActionMenu) ...[_buildActionMenu(theme)],
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
                    _buildActionMenu(theme),
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
            if (includeWeight) ...[
              const SizedBox(width: 6),
              _buildWeight(theme),
            ],
          ],
        ),
        if (widget.isListMode) const SizedBox(height: 1),
        TranslatedPromptText(
          widget.entry.content,
          selectable: false,
          maxLines: maxLines,
          reserveTranslationSpace: widget.isListMode,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.entry.enabled
            ? widget.categoryColor
            : Theme.of(context).colorScheme.outline,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildWeight(ThemeData theme) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Text(
        widget.entry.weight.toStringAsFixed(2),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildActionMenu(ThemeData theme) {
    final interactionPolicy = context.interactionPolicy;
    return SizedBox.square(
      dimension: interactionPolicy.precisePointerAvailable ? 32 : 44,
      child: PopupMenuButton<_SidebarEntryAction>(
        key: const ValueKey('sidebar-entry-actions-menu'),
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        icon: const Icon(Icons.more_horiz_rounded, size: 18),
        padding: EdgeInsets.zero,
        onSelected: (action) {
          switch (action) {
            case _SidebarEntryAction.copy:
              unawaited(_copyContent());
              break;
            case _SidebarEntryAction.edit:
              widget.onEdit();
              break;
            case _SidebarEntryAction.delete:
              widget.onDelete();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _SidebarEntryAction.copy,
            child: ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(context.l10n.common_copy),
            ),
          ),
          PopupMenuItem(
            value: _SidebarEntryAction.edit,
            child: ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(context.l10n.common_edit),
            ),
          ),
          PopupMenuItem(
            value: _SidebarEntryAction.delete,
            child: ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                context.l10n.common_delete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
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
