import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../themes/core/layered_surface_style.dart';
import '../../themes/prompt_semantic_colors.dart';
import '../common/tile_action_button.dart';
import '../common/translated_tag_text.dart';
import '../common/themed_switch.dart';

enum FixedTagEntryAction { edit, delete }

class FixedTagEntryTile extends StatefulWidget {
  const FixedTagEntryTile({
    super.key,
    required this.entry,
    required this.index,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
    this.compact = false,
    this.linkAnchor,
  });

  final FixedTagEntry entry;
  final int index;
  final bool compact;
  final Widget? linkAnchor;
  final VoidCallback onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<FixedTagEntryTile> createState() => _FixedTagEntryTileState();
}

class _FixedTagEntryTileState extends State<FixedTagEntryTile> {
  bool _hovering = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final interactionPolicy = context.interactionPolicy;
    final positionColor = entry.isPrefix
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    final promptTypeColor = entry.promptType == FixedTagPromptType.positive
        ? theme.promptSemanticColors.positiveFixedTag
        : theme.promptSemanticColors.negativeFixedTag;
    final highlighted = _hovering || _focused;
    final restingColor = controlSurfaceColor(theme.colorScheme);
    final baseColor = Color.alphaBlend(
      promptTypeColor.withValues(alpha: entry.enabled ? 0.12 : 0.07),
      restingColor,
    );
    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('fixed-tag-entry-${entry.id}'),
        borderRadius: BorderRadius.circular(10),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        onTap: widget.onToggleEnabled,
        onHover: interactionPolicy.precisePointerAvailable
            ? (value) => setState(() => _hovering = value)
            : null,
        onFocusChange: (value) => setState(() => _focused = value),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(
            horizontal: widget.compact ? 6 : 10,
            vertical: 4,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: highlighted
                ? Color.alphaBlend(
                    promptTypeColor.withValues(alpha: 0.08),
                    baseColor,
                  )
                : baseColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.compact
              ? _buildCompact(context, positionColor)
              : _buildDesktop(context, positionColor),
        ),
      ),
    );
    if (interactionPolicy.touchAvailable) {
      return ReorderableDelayedDragStartListener(
        index: widget.index,
        child: tile,
      );
    }
    return ReorderableDragStartListener(index: widget.index, child: tile);
  }

  Widget _buildDesktop(BuildContext context, Color positionColor) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final positiveAnchor =
        entry.promptType == FixedTagPromptType.positive &&
        widget.linkAnchor != null;
    final negativeAnchor =
        entry.promptType == FixedTagPromptType.negative &&
        widget.linkAnchor != null;
    return Row(
      children: [
        if (negativeAnchor) ...[widget.linkAnchor!, const SizedBox(width: 10)],
        ThemedSwitch(
          value: entry.enabled,
          onChanged: (_) => widget.onToggleEnabled(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 8),
            child: Row(
              children: [
                Expanded(child: _EntryLabels(entry: entry)),
                const SizedBox(width: 8),
                _EntryBadges(entry: entry, positionColor: positionColor),
              ],
            ),
          ),
        ),
        AnimatedOpacity(
          opacity:
              !context.interactionPolicy.precisePointerAvailable || _hovering
              ? 1
              : 0.4,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TileActionButton(
                icon: Icons.edit_outlined,
                onPressed: widget.onEdit,
                tooltip: context.l10n.common_edit,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                hoverColor: theme.colorScheme.primary,
              ),
              TileActionButton(
                icon: Icons.close_rounded,
                onPressed: widget.onDelete,
                tooltip: context.l10n.common_delete,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                hoverColor: theme.colorScheme.error,
              ),
            ],
          ),
        ),
        if (positiveAnchor) ...[const SizedBox(width: 6), widget.linkAnchor!],
      ],
    );
  }

  Widget _buildCompact(BuildContext context, Color positionColor) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    return Row(
      children: [
        ThemedSwitch(
          value: entry.enabled,
          onChanged: (_) => widget.onToggleEnabled(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: entry.enabled ? null : TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 3),
              entry.content.isEmpty
                  ? Text(context.l10n.fixedTags_empty)
                  : TranslatedPromptText(
                      entry.content,
                      originalText: entry.content.replaceAll('\n', ' '),
                      selectable: false,
                      maxLines: 1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Row(
          key: ValueKey('fixed-tag-position-${entry.id}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              entry.isPrefix
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
              size: 12,
              color: positionColor,
            ),
            const SizedBox(width: 2),
            Text(
              entry.isPrefix
                  ? context.l10n.fixedTags_prefix
                  : context.l10n.fixedTags_suffix,
              style: theme.textTheme.labelSmall?.copyWith(
                color: positionColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (entry.weight != 1) ...[
              const SizedBox(width: 5),
              Text(
                '${entry.weight.toStringAsFixed(1)}×',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        if (widget.linkAnchor != null) ...[
          const SizedBox(width: 8),
          widget.linkAnchor!,
        ],
        PopupMenuButton<FixedTagEntryAction>(
          tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
          padding: EdgeInsets.zero,
          onSelected: (action) => action == FixedTagEntryAction.edit
              ? widget.onEdit()
              : widget.onDelete(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: FixedTagEntryAction.edit,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.common_edit),
              ),
            ),
            PopupMenuItem(
              value: FixedTagEntryAction.delete,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
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
      ],
    );
  }
}

class _EntryLabels extends StatelessWidget {
  const _EntryLabels({required this.entry});
  final FixedTagEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.displayName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: entry.enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            decoration: entry.enabled ? null : TextDecoration.lineThrough,
            decorationColor: theme.colorScheme.outline.withValues(alpha: 0.6),
            decorationThickness: 2,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (entry.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TranslatedPromptText(
              entry.content,
              originalText: entry.content.replaceAll('\n', ' '),
              selectable: false,
              style: TextStyle(
                fontSize: 11,
                color: entry.enabled
                    ? theme.colorScheme.outline.withValues(alpha: 0.8)
                    : theme.colorScheme.outline.withValues(alpha: 0.5),
                height: 1.2,
                decoration: entry.enabled ? null : TextDecoration.lineThrough,
                decorationColor: theme.colorScheme.outline.withValues(
                  alpha: 0.4,
                ),
              ),
              maxLines: 1,
            ),
          ),
      ],
    );
  }
}

class _EntryBadges extends StatelessWidget {
  const _EntryBadges({required this.entry, required this.positionColor});
  final FixedTagEntry entry;
  final Color positionColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: positionColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            entry.isPrefix
                ? context.l10n.fixedTags_prefix
                : context.l10n.fixedTags_suffix,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: positionColor,
            ),
          ),
        ),
        if (entry.weight != 1) ...[
          const SizedBox(width: 4),
          Text(
            '${entry.weight.toStringAsFixed(1)}x',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ],
    );
  }
}
