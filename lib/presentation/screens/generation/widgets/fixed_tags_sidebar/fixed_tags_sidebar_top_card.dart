import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../themes/core/layered_surface_style.dart';
import 'fixed_tags_sidebar_models.dart';

class FixedTagsSidebarTopCard extends StatelessWidget {
  const FixedTagsSidebarTopCard({
    super.key,
    required this.headerActionsKey,
    required this.searchController,
    required this.searchQuery,
    required this.enabledCount,
    required this.totalCount,
    required this.isListMode,
    required this.onToggleViewMode,
    required this.onAddAction,
    required this.onCollapseSidebar,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final GlobalKey headerActionsKey;
  final TextEditingController searchController;
  final String searchQuery;
  final int enabledCount;
  final int totalCount;
  final bool isListMode;
  final VoidCallback onToggleViewMode;
  final ValueChanged<FixedTagAddAction> onAddAction;
  final VoidCallback onCollapseSidebar;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('fixed-tags-top-card'),
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: sectionSurfaceColor(theme.colorScheme),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildHeader(context, theme), _buildSearchBar(context)],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    const iconSize = 18.0;
    const iconGap = 8.0;
    const minimumTitleGlyphs = 5;
    final title = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.fixedTags_sidebarTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            context.l10n.fixedTags_enabledCount(enabledCount, totalCount),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    final leading = [
      Icon(
        Icons.push_pin_rounded,
        size: iconSize,
        color: theme.colorScheme.secondary,
      ),
      const SizedBox(width: iconGap),
    ];
    final actions = _buildHeaderActions(context);
    final actionGroup = Row(
      key: headerActionsKey,
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleWidth =
              constraints.maxWidth -
              iconSize -
              iconGap -
              actions.length * context.interactionPolicy.minimumControlExtent;
          final glyphWidth = MediaQuery.textScalerOf(
            context,
          ).scale(theme.textTheme.titleSmall?.fontSize ?? 14);
          // 标题放不下几个字时操作整体换到第二行，否则标题会被逐字折行。
          if (titleWidth >= glyphWidth * minimumTitleGlyphs) {
            return Row(children: [...leading, title, actionGroup]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [...leading, title]),
              Align(alignment: Alignment.centerRight, child: actionGroup),
            ],
          );
        },
      ),
    );
  }

  // 显式定尺寸，换行判断才能按交互策略算出操作组宽度，不受主题密度和点击区补齐影响。
  ButtonStyle _headerActionStyle(BuildContext context) {
    final extent = context.interactionPolicy.minimumControlExtent;
    return IconButton.styleFrom(
      minimumSize: Size.square(extent),
      maximumSize: Size.square(extent),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }

  List<Widget> _buildHeaderActions(BuildContext context) {
    final style = _headerActionStyle(context);
    return [
      IconButton(
        tooltip: isListMode
            ? context.l10n.fixedTags_switchGridView
            : context.l10n.fixedTags_switchListView,
        style: style,
        icon: Icon(
          isListMode ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
          size: 18,
        ),
        onPressed: onToggleViewMode,
      ),
      PopupMenuButton<FixedTagAddAction>(
        tooltip: context.l10n.fixedTags_add,
        style: style,
        icon: const Icon(Icons.add_rounded, size: 20),
        onSelected: onAddAction,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: FixedTagAddAction.positive,
            child: Text(context.l10n.fixedTags_addPositive),
          ),
          PopupMenuItem(
            value: FixedTagAddAction.negative,
            child: Text(context.l10n.fixedTags_addNegative),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: FixedTagAddAction.libraryPositive,
            child: Text(context.l10n.fixedTags_addPositiveFromLibrary),
          ),
          PopupMenuItem(
            value: FixedTagAddAction.libraryNegative,
            child: Text(context.l10n.fixedTags_addNegativeFromLibrary),
          ),
        ],
      ),
      IconButton(
        key: const ValueKey('fixed-tags-collapse-sidebar'),
        tooltip: context.l10n.nav_collapseSidebar,
        style: style,
        icon: const Icon(Icons.chevron_left_rounded, size: 20),
        onPressed: onCollapseSidebar,
      ),
    ];
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: searchController,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: context.l10n.fixedTags_searchNameOrContent,
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.fixedTags_clearSearch,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onClearSearch,
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onChanged: (value) => onSearchChanged(value.trim()),
      ),
    );
  }
}
