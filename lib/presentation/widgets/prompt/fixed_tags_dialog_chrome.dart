import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../common/themed_switch.dart';
import 'fixed_tags_dialog_models.dart';

enum FixedTagHeaderAction { undo, redo, toggleAll, clearAll }

class FixedTagsDialogHeader extends StatelessWidget {
  const FixedTagsDialogHeader({
    super.key,
    required this.data,
    required this.commands,
    required this.isCompact,
    required this.isDark,
    this.presentationManaged = false,
  });

  final FixedTagsDialogViewData data;
  final FixedTagsDialogCommands commands;
  final bool isCompact;
  final bool isDark;
  final bool presentationManaged;

  @override
  Widget build(BuildContext context) {
    final enabledCount = data.state.entries
        .where((entry) => entry.enabled)
        .length;
    final totalCount = data.state.entries.length;
    if (isCompact) {
      return _CompactHeader(
        data: data,
        commands: commands,
        enabledCount: enabledCount,
        totalCount: totalCount,
        presentationManaged: presentationManaged,
      );
    }
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.secondary.withValues(alpha: isDark ? 0.08 : 0.05),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          if (!presentationManaged) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.2),
                    theme.colorScheme.secondary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.push_pin_rounded,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.fixedTags_manage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (totalCount > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: enabledCount > 0
                                ? theme.colorScheme.secondary.withValues(
                                    alpha: 0.15,
                                  )
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.1,
                                  ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${context.l10n.fixedTags_enabledCount(enabledCount.toString(), totalCount.toString())} · ${context.l10n.fixedTags_linkCount(data.state.links.length)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: enabledCount > 0
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (presentationManaged) const Spacer(),
          TextButton.icon(
            onPressed: commands.toggleNegativePanel,
            icon: Icon(
              data.state.negativePanelExpanded
                  ? Icons.keyboard_tab_rounded
                  : Icons.view_sidebar_rounded,
              size: 18,
            ),
            label: Text(
              data.state.negativePanelExpanded
                  ? context.l10n.fixedTags_collapseNegative
                  : context.l10n.fixedTags_expandNegative,
            ),
          ),
          IconButton(
            tooltip: context.l10n.fixedTags_undoTooltip,
            onPressed: data.state.canUndo ? commands.undo : null,
            icon: const Icon(Icons.undo_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: context.l10n.fixedTags_redoTooltip,
            onPressed: data.state.canRedo ? commands.redo : null,
            icon: const Icon(Icons.redo_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          if (totalCount > 0) ...[
            ThemedSwitch(
              value: enabledCount == totalCount,
              onChanged: commands.setAllEnabled,
              scale: 0.85,
            ),
            const SizedBox(width: 8),
          ],
          if (!presentationManaged)
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              constraints: BoxConstraints.tightFor(
                width: context.interactionPolicy.minimumControlExtent,
                height: context.interactionPolicy.minimumControlExtent,
              ),
              onPressed: commands.close,
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.data,
    required this.commands,
    required this.enabledCount,
    required this.totalCount,
    required this.presentationManaged,
  });
  final FixedTagsDialogViewData data;
  final FixedTagsDialogCommands commands;
  final int enabledCount;
  final int totalCount;
  final bool presentationManaged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          if (!presentationManaged) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.push_pin_rounded,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.fixedTags_manage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${context.l10n.fixedTags_enabledCount(enabledCount.toString(), totalCount.toString())} · ${context.l10n.fixedTags_linkCount(data.state.links.length)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
          if (presentationManaged) const Spacer(),
          PopupMenuButton<FixedTagHeaderAction>(
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            onSelected: (action) {
              switch (action) {
                case FixedTagHeaderAction.undo:
                  commands.undo();
                case FixedTagHeaderAction.redo:
                  commands.redo();
                case FixedTagHeaderAction.toggleAll:
                  commands.setAllEnabled(enabledCount != totalCount);
                case FixedTagHeaderAction.clearAll:
                  commands.clearAll();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: FixedTagHeaderAction.undo,
                enabled: data.state.canUndo,
                child: Text(context.l10n.fixedTags_undoTooltip),
              ),
              PopupMenuItem(
                value: FixedTagHeaderAction.redo,
                enabled: data.state.canRedo,
                child: Text(context.l10n.fixedTags_redoTooltip),
              ),
              if (totalCount > 0)
                PopupMenuItem(
                  value: FixedTagHeaderAction.toggleAll,
                  child: Text(
                    enabledCount == totalCount
                        ? context.l10n.fixedTags_disableAll
                        : context.l10n.fixedTags_enableAll,
                  ),
                ),
              if (totalCount > 0)
                PopupMenuItem(
                  value: FixedTagHeaderAction.clearAll,
                  child: Text(
                    context.l10n.fixedTags_clearAll,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
          if (!presentationManaged)
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: commands.close,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

class FixedTagsDialogFooter extends StatelessWidget {
  const FixedTagsDialogFooter({
    super.key,
    required this.data,
    required this.commands,
    required this.isCompact,
  });
  final FixedTagsDialogViewData data;
  final FixedTagsDialogCommands commands;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: isCompact
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: commands.openLibraryPage,
                icon: const Icon(Icons.library_books_outlined, size: 17),
                label: Text(context.l10n.fixedTags_openLibrary),
              ),
            )
          : Row(
              children: [
                OutlinedButton.icon(
                  onPressed: commands.openLibraryPage,
                  icon: const Icon(Icons.library_books_outlined, size: 17),
                  label: Text(context.l10n.fixedTags_openLibrary),
                ),
                const SizedBox(width: 8),
                if (data.state.entries.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: commands.clearAll,
                    icon: Icon(
                      Icons.delete_sweep_outlined,
                      size: 17,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      context.l10n.fixedTags_clearAll,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const Spacer(),
                if (data.state.negativePanelExpanded)
                  Text(
                    context.l10n.fixedTags_footerExpandedHint,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  )
                else ...[
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        commands.editEntry(null, FixedTagPromptType.positive),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: Text(context.l10n.fixedTags_newPositive),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () =>
                        commands.pickFromLibrary(FixedTagPromptType.positive),
                    icon: const Icon(Icons.playlist_add_rounded, size: 17),
                    label: Text(
                      context.l10n.fixedTags_addPositiveFromLibraryShort,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
