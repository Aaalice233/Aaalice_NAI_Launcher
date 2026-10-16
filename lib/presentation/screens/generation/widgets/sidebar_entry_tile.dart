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

enum _SidebarEntryAction {
  copy(Icons.copy_rounded),
  edit(Icons.edit_rounded),
  delete(Icons.delete_outline_rounded);

  const _SidebarEntryAction(this.icon);

  final IconData icon;

  String label(BuildContext context) => switch (this) {
    _SidebarEntryAction.copy => context.l10n.common_copy,
    _SidebarEntryAction.edit => context.l10n.common_edit,
    _SidebarEntryAction.delete => context.l10n.common_delete,
  };

  Color emphasisColor(ColorScheme colorScheme) =>
      this == _SidebarEntryAction.delete
      ? colorScheme.error
      : colorScheme.primary;
}

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

  static const _listPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 5);
  static const _cardPadding = EdgeInsets.fromLTRB(9, 8, 7, 7);
  static const _statusIconSize = 18.0;
  static const _statusGap = 7.0;
  static const _linkAnchorGap = 4.0;
  static const _inlineActionsGap = 6.0;
  static const _minimumInlineLabelGlyphs = 4;
  static const _maximumWeightWidthFraction = 0.4;

  /// Side length callers must give [linkAnchor]; row layouts reserve it.
  static double linkAnchorExtentOf(BuildContext context) =>
      context.interactionPolicy.precisePointerAvailable ? 24 : 44;

  /// Narrowest card whose footer fits the link anchor beside every action.
  static double minimumCardWidthOf(BuildContext context) =>
      _cardPadding.horizontal +
      linkAnchorExtentOf(context) +
      _inlineActionsExtentOf(context);

  static double _inlineActionsExtentOf(BuildContext context) =>
      _SidebarEntryAction.values.length * TileActionButton.extentOf(context);

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
      const SizedBox(width: SidebarEntryTile._statusGap),
      if (widget.linkAnchor != null) ...[
        widget.linkAnchor!,
        const SizedBox(width: SidebarEntryTile._linkAnchorGap),
      ],
    ];
    final label = _buildDragRegion(
      _buildText(theme, maxLines: 1, includeWeight: true),
    );

    return Padding(
      padding: SidebarEntryTile._listPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!_stacksListActions(theme, constraints.maxWidth)) {
            return Row(
              children: [
                ...leading,
                Expanded(child: label),
                const SizedBox(width: SidebarEntryTile._inlineActionsGap),
                _buildActions(theme),
              ],
            );
          }
          return Column(
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
                child: _buildActions(
                  theme,
                  availableWidth: constraints.maxWidth,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 列表原型项按同一判断定行高，所以这里只能看宽度、字号和交互策略，不能看条目内容。
  bool _stacksListActions(ThemeData theme, double rowWidth) {
    final textScaler = MediaQuery.textScalerOf(context);
    if (textScaler.scale(14) >= 20) return true;
    final anchorExtent = widget.linkAnchor == null
        ? 0.0
        : SidebarEntryTile.linkAnchorExtentOf(context) +
              SidebarEntryTile._linkAnchorGap;
    final labelWidth =
        rowWidth -
        SidebarEntryTile._statusIconSize -
        SidebarEntryTile._statusGap -
        anchorExtent -
        SidebarEntryTile._inlineActionsGap -
        SidebarEntryTile._inlineActionsExtentOf(context);
    final glyphWidth = textScaler.scale(
      theme.textTheme.labelLarge?.fontSize ?? 14,
    );
    return labelWidth < glyphWidth * SidebarEntryTile._minimumInlineLabelGlyphs;
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
            padding: SidebarEntryTile._cardPadding,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final anchorExtent = widget.linkAnchor == null
                        ? 0.0
                        : SidebarEntryTile.linkAnchorExtentOf(context);
                    return Row(
                      children: [
                        if (widget.linkAnchor != null) widget.linkAnchor!,
                        const Spacer(),
                        _buildActions(
                          theme,
                          availableWidth: constraints.maxWidth - anchorExtent,
                        ),
                      ],
                    );
                  },
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
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              if (!widget.isListMode) ...[
                _buildStatusIcon(theme),
                const SizedBox(width: SidebarEntryTile._statusGap),
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
              // 权重只设宽度上限而不与名称等分弹性，名称才能拿到其余全部宽度。
              if (includeWeight) ...[
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        constraints.maxWidth *
                        SidebarEntryTile._maximumWeightWidthFraction,
                  ),
                  child: _buildWeight(theme),
                ),
              ],
            ],
          ),
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
      size: SidebarEntryTile._statusIconSize,
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

  // 行内放不下全部操作时收进更多菜单，单个触发器沿用同一命中区尺寸。
  Widget _buildActions(
    ThemeData theme, {
    double availableWidth = double.infinity,
  }) {
    final collapsed =
        availableWidth < SidebarEntryTile._inlineActionsExtentOf(context);
    return AnimatedOpacity(
      key: const ValueKey('sidebar-entry-actions'),
      opacity: _actionsHighlighted ? 1 : 0.4,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      child: collapsed
          ? _buildActionMenu(theme)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in _SidebarEntryAction.values)
                  TileActionButton(
                    icon: action.icon,
                    tooltip: action.label(context),
                    color: theme.colorScheme.onSurfaceVariant,
                    hoverColor: action.emphasisColor(theme.colorScheme),
                    onPressed: () => _perform(action),
                  ),
              ],
            ),
    );
  }

  Widget _buildActionMenu(ThemeData theme) {
    return PopupMenuButton<_SidebarEntryAction>(
      key: const ValueKey('sidebar-entry-more-actions'),
      tooltip: context.l10n.common_moreActions,
      onSelected: _perform,
      itemBuilder: (context) => [
        for (final action in _SidebarEntryAction.values)
          PopupMenuItem(
            value: action,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                action.icon,
                color: action == _SidebarEntryAction.delete
                    ? theme.colorScheme.error
                    : null,
              ),
              title: Text(action.label(context)),
            ),
          ),
      ],
      child: SizedBox.square(
        dimension: TileActionButton.extentOf(context),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 15,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _perform(_SidebarEntryAction action) {
    switch (action) {
      case _SidebarEntryAction.copy:
        unawaited(_copyContent());
      case _SidebarEntryAction.edit:
        widget.onEdit();
      case _SidebarEntryAction.delete:
        widget.onDelete();
    }
  }

  Future<void> _copyContent() async {
    await Clipboard.setData(ClipboardData(text: widget.entry.content));
    if (!mounted) return;
    AppToast.info(context, context.l10n.common_copied);
  }
}
