import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../themes/core/layered_surface_style.dart';
import 'fixed_tags_sidebar_layout.dart';
import 'grouped_fixed_tag_collection.dart';

class FixedTagsSidebarPaneCard extends StatelessWidget {
  const FixedTagsSidebarPaneCard({
    super.key,
    this.cardKey,
    required this.accent,
    required this.paneHeight,
    required this.headerBuilder,
    required this.body,
  });

  final Key? cardKey;
  final Color accent;
  final double paneHeight;
  final Widget Function(double headerExtent) headerBuilder;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = sectionSurfaceColor(theme.colorScheme);
    final cardTint = theme.brightness == Brightness.dark ? 0.04 : 0.025;
    final headerTint = theme.brightness == Brightness.dark ? 0.09 : 0.065;
    // 面板头不超过整格高度，否则下面的 Expanded 拿到 0 仍会把 Column 撑破；
    // 下界是操作按钮命中区，压过头等于缩小操作入口。
    final headerExtent = math.max(
      context.interactionPolicy.minimumControlExtent,
      math.min(paneHeaderExtent(context), paneHeight),
    );
    return Material(
      key: cardKey,
      color: Color.alphaBlend(accent.withValues(alpha: cardTint), baseColor),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: Color.alphaBlend(
              accent.withValues(alpha: headerTint),
              baseColor,
            ),
            child: SizedBox(
              height: headerExtent,
              child: headerBuilder(headerExtent),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class FixedTagsSidebarPaneHeader extends StatelessWidget {
  const FixedTagsSidebarPaneHeader({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.maxExtent,
    this.trailingBuilder,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final double maxExtent;
  final Widget Function(bool iconOnly)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final usesLargeText = paneHeaderUsesLargeText(context);
    final padding = paneHeaderPadding(context);
    final titleExtent = paneHeaderTitleExtent(context);
    final actionExtent = context.interactionPolicy.minimumControlExtent;
    // 分到的高度不够时先收内边距再压标题字号，操作按钮命中区不参与压缩。
    final verticalPadding = (maxExtent - math.max(titleExtent, actionExtent))
        .clamp(0.0, padding.vertical)
        .toDouble();
    final paddingScale = padding.vertical == 0
        ? 1.0
        : verticalPadding / padding.vertical;
    final contentExtent = math.max(0.0, maxExtent - verticalPadding);
    final titleScaleFactor = paneHeaderTextScaleFactor(context);
    final titleMaxScaleFactor = contentExtent >= titleExtent
        ? titleScaleFactor
        : titleScaleFactor * contentExtent / titleExtent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trailing = trailingBuilder?.call(
          constraints.maxWidth < 360 || usesLargeText,
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            padding.top * paddingScale,
            padding.right,
            padding.bottom * paddingScale,
          ),
          child: Row(
            children: [
              Expanded(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: titleMaxScaleFactor,
                  child: FixedTagsSectionTitle(
                    icon: icon,
                    label: label,
                    count: count,
                    color: color,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        );
      },
    );
  }
}

class FixedTagsGroupHeaderActions extends StatelessWidget {
  const FixedTagsGroupHeaderActions({
    super.key,
    required this.keyPrefix,
    required this.groupsKey,
    required this.iconOnly,
    required this.showBulkActions,
    required this.enabledOnly,
    required this.accent,
    required this.onToggleEnabledOnly,
  });

  final String keyPrefix;
  final GlobalKey<GroupedFixedTagCollectionState> groupsKey;
  final bool iconOnly;
  final bool showBulkActions;
  final bool enabledOnly;
  final Color accent;
  final VoidCallback onToggleEnabledOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FixedTagsEnabledOnlyAction(
          key: ValueKey('$keyPrefix-enabled-only'),
          selected: enabledOnly,
          color: accent,
          iconOnly: iconOnly,
          label: context.l10n.fixedTags_enabledOnly,
          onPressed: onToggleEnabledOnly,
        ),
        if (showBulkActions) ...[
          const SizedBox(width: 2),
          FixedTagsGroupBulkAction(
            key: ValueKey('$keyPrefix-expand-all'),
            icon: Icons.unfold_more_rounded,
            label: context.l10n.fixedTags_expandAll,
            iconOnly: true,
            onPressed: () => groupsKey.currentState?.setAllCollapsed(false),
          ),
          const SizedBox(width: 2),
          FixedTagsGroupBulkAction(
            key: ValueKey('$keyPrefix-collapse-all'),
            icon: Icons.unfold_less_rounded,
            label: context.l10n.fixedTags_collapseAll,
            iconOnly: true,
            onPressed: () => groupsKey.currentState?.setAllCollapsed(true),
          ),
        ],
      ],
    );
  }
}

class FixedTagsGroupBulkAction extends StatelessWidget {
  const FixedTagsGroupBulkAction({
    super.key,
    required this.icon,
    required this.label,
    required this.iconOnly,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool iconOnly;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        visualDensity: VisualDensity.compact,
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

class FixedTagsEnabledOnlyAction extends StatelessWidget {
  const FixedTagsEnabledOnlyAction({
    super.key,
    required this.selected,
    required this.color,
    required this.iconOnly,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final Color color;
  final bool iconOnly;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = selected
        ? Icons.filter_alt_rounded
        : Icons.filter_alt_outlined;
    final foregroundColor = selected
        ? color
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final action = iconOnly
        ? IconButton(
            tooltip: label,
            onPressed: onPressed,
            isSelected: selected,
            selectedIcon: Icon(
              Icons.filter_alt_rounded,
              size: 18,
              color: color,
            ),
            icon: Icon(icon, size: 18, color: foregroundColor),
            visualDensity: VisualDensity.compact,
          )
        : TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: TextButton.styleFrom(
              foregroundColor: foregroundColor,
              backgroundColor: selected
                  ? color.withValues(alpha: 0.12)
                  : Colors.transparent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          );
    return Semantics(selected: selected, child: action);
  }
}

class FixedTagsSectionTitle extends StatelessWidget {
  const FixedTagsSectionTitle({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            count.toString(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
