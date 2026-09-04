import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/hover_image_preview.dart';
import '../../../widgets/common/thumbnail_display.dart';
import '../../../widgets/common/translated_tag_text.dart';

typedef SidebarDragHandleBuilder = Widget Function(Widget child);

enum _SidebarEntryAction { copy, edit, delete }

/// 固定词侧边栏条目卡片。
class SidebarEntryTile extends StatefulWidget {
  const SidebarEntryTile({
    super.key,
    required this.entry,
    required this.categoryColor,
    required this.isListMode,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.categoryName,
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
  final String? categoryName;
  final Widget? linkAnchor;
  final TagLibraryEntry? libraryEntry;
  final SidebarDragHandleBuilder? dragHandleBuilder;

  @override
  State<SidebarEntryTile> createState() => _SidebarEntryTileState();
}

class _SidebarEntryTileState extends State<SidebarEntryTile> {
  bool _isHovering = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final enabled = entry.enabled;
    final foreground = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    final background = enabled
        ? widget.categoryColor.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerHigh;
    final hasThumbnailBackground = _hasThumbnailBackground;
    final contentPadding = EdgeInsets.symmetric(
      horizontal: widget.isListMode ? 10 : 8,
      vertical: widget.isListMode ? 8 : 10,
    );
    final contentForeground = hasThumbnailBackground
        ? Colors.white
        : foreground;

    final tile = MouseRegion(
      onEnter: (_) {
        if (context.interactionPolicy.precisePointerAvailable) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _isHovering
                ? Color.alphaBlend(
                    theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    background,
                  )
                : background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              if (hasThumbnailBackground)
                Positioned.fill(
                  child: _buildThumbnailBackground(widget.libraryEntry!),
                ),
              if (hasThumbnailBackground)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.26),
                          Colors.black.withValues(alpha: 0.58),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: contentPadding,
                child: widget.isListMode
                    ? _buildListContent(theme, contentForeground)
                    : _buildGridContent(theme, contentForeground),
              ),
            ],
          ),
        ),
      ),
    );

    final libraryEntry = widget.libraryEntry;
    if (libraryEntry == null || !libraryEntry.hasThumbnail) return tile;

    return HoverImagePreview.file(
      imagePath: libraryEntry.thumbnail!,
      previewMaxSize: 320,
      hoverDelay: const Duration(milliseconds: 300),
      imageOffsetX: libraryEntry.thumbnailOffsetX,
      imageOffsetY: libraryEntry.thumbnailOffsetY,
      imageScale: libraryEntry.thumbnailScale,
      child: tile,
    );
  }

  bool get _hasThumbnailBackground =>
      !widget.isListMode && (widget.libraryEntry?.hasThumbnail ?? false);

  Widget _buildThumbnailBackground(TagLibraryEntry libraryEntry) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 220.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 130.0;
        return ThumbnailDisplay(
          imagePath: libraryEntry.thumbnail!,
          offsetX: libraryEntry.thumbnailOffsetX,
          offsetY: libraryEntry.thumbnailOffsetY,
          scale: libraryEntry.thumbnailScale,
          width: width,
          height: height,
        );
      },
    );
  }

  Widget _buildListContent(ThemeData theme, Color foreground) {
    return Row(
      children: [
        _buildStatusDot(),
        const SizedBox(width: 8),
        if (widget.linkAnchor != null) ...[
          widget.linkAnchor!,
          const SizedBox(width: 6),
        ],
        Expanded(child: _buildDragRegion(_buildText(theme, foreground))),
        SizedBox(
          width: 72,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              child:
                  _isHovering ||
                      _isFocused ||
                      _usesPersistentActionMenu(context)
                  ? _buildActionAffordance(theme)
                  : _buildWeightBadge(theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridContent(ThemeData theme, Color foreground) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatusDot(),
            const Spacer(),
            if (widget.linkAnchor != null) widget.linkAnchor!,
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildDragRegion(
            _buildText(
              theme,
              foreground,
              maxLines: widget.categoryName == null ? 2 : 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: _isHovering || _isFocused || _usesPersistentActionMenu(context)
              ? _buildActionAffordance(theme)
              : _buildWeightBadge(theme),
        ),
      ],
    );
  }

  Widget _buildDragRegion(Widget child) {
    final builder = widget.dragHandleBuilder;
    if (builder == null) return child;
    return MouseRegion(cursor: SystemMouseCursors.grab, child: builder(child));
  }

  Widget _buildText(ThemeData theme, Color foreground, {int maxLines = 1}) {
    final entry = widget.entry;
    final hasThumbnailBackground = _hasThumbnailBackground;
    final secondaryColor = hasThumbnailBackground
        ? Colors.white.withValues(alpha: 0.82)
        : theme.colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: entry.enabled ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        TranslatedPromptText(
          entry.content,
          selectable: false,
          maxLines: maxLines,
          reserveTranslationSpace: widget.isListMode,
          style: theme.textTheme.bodySmall?.copyWith(color: secondaryColor),
        ),
        if (widget.categoryName != null && !widget.isListMode) ...[
          const SizedBox(height: 6),
          Text(
            widget.categoryName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: hasThumbnailBackground
                  ? Colors.white.withValues(alpha: 0.88)
                  : widget.categoryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusDot() {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: widget.entry.enabled
            ? widget.categoryColor
            : Theme.of(context).colorScheme.outline,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildWeightBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        widget.entry.weight.toStringAsFixed(2),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _usesPersistentActionMenu(BuildContext context) =>
      context.interactionPolicy.shouldExposeTouchAlternatives ||
      MediaQuery.textScalerOf(context).scale(14) >= 20;

  Widget _buildActionAffordance(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inlineActionsExtent =
            _ActionButton.extent * _SidebarEntryAction.values.length;
        final useMenu =
            _usesPersistentActionMenu(context) ||
            constraints.maxWidth < inlineActionsExtent;
        return Align(
          alignment: Alignment.centerRight,
          child: useMenu ? _buildActionMenu(theme) : _buildInlineActions(theme),
        );
      },
    );
  }

  Widget _buildInlineActions(ThemeData theme) {
    return Row(
      key: const ValueKey('actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.copy_rounded,
          tooltip: context.l10n.common_copy,
          onPressed: _copyContent,
        ),
        _ActionButton(
          icon: Icons.edit_rounded,
          tooltip: context.l10n.common_edit,
          onPressed: widget.onEdit,
        ),
        _ActionButton(
          icon: Icons.delete_outline_rounded,
          tooltip: context.l10n.common_delete,
          color: theme.colorScheme.error,
          onPressed: widget.onDelete,
        ),
      ],
    );
  }

  Widget _buildActionMenu(ThemeData theme) {
    return SizedBox.square(
      dimension: context.interactionPolicy.minimumControlExtent,
      child: PopupMenuButton<_SidebarEntryAction>(
        key: const ValueKey('sidebar-entry-actions-menu'),
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        icon: const Icon(Icons.more_horiz_rounded, size: 20),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  static const extent = 21.0;

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: SizedBox.square(
        dimension: extent,
        child: InkResponse(
          radius: 16,
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 15,
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
