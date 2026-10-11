import 'package:flutter/material.dart';

import '../../adaptive/compact_control_metrics.dart';
import '../../adaptive/interaction_policy.dart';
import 'library_selection_controller.dart';

/// 选择列表的滚动归属。
enum LibraryExportListMode {
  /// 面板自带视口，高度按可用空间 clamp。
  scrollable,

  /// 跟随外层滚动视图收缩。
  shrinkWrap,
}

/// 词库导出对话框共用的分类树多选面板。
class LibraryExportPanel<E> extends StatelessWidget {
  const LibraryExportPanel({
    super.key,
    required this.tree,
    required this.selection,
    required this.uncategorizedLabel,
    required this.entryContentBuilder,
    this.mode = LibraryExportListMode.scrollable,
    this.hidesEmptyCategories = false,
  });

  final LibrarySelectionTree<E> tree;
  final LibrarySelectionController selection;
  final String uncategorizedLabel;

  /// 条目行复选框之后的内容，由调用方按自己的模型渲染。
  final Widget Function(BuildContext context, LibraryEntryNode<E> entry)
  entryContentBuilder;

  final LibraryExportListMode mode;

  /// 既无子分类也无条目的分类是否隐藏。
  final bool hidesEmptyCategories;

  /// 自带视口时的列表高度：可用高度的 35%，取 120～320。
  static double listHeightFor(MediaQueryData mediaQuery) {
    return ((mediaQuery.size.height -
                mediaQuery.padding.vertical -
                mediaQuery.viewInsets.vertical) *
            0.35)
        .clamp(120.0, 320.0);
  }

  static double indentFor(int depth) =>
      (depth * 16.0).clamp(0.0, 64.0).toDouble();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) => _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    final rootCategories = tree.rootCategories;
    final hasUncategorized = tree.uncategorizedEntries.isNotEmpty;
    final metrics = CompactControlMetrics.forPolicy(context.interactionPolicy);
    final shrinkWrap = mode == LibraryExportListMode.shrinkWrap;

    final list = ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: rootCategories.length + (hasUncategorized ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < rootCategories.length) {
          return _CategoryTile<E>(
            panel: this,
            metrics: metrics,
            category: rootCategories[index],
            depth: 0,
          );
        }
        return _UncategorizedSection<E>(panel: this, metrics: metrics);
      },
    );

    if (shrinkWrap) return list;
    return SizedBox(
      height: listHeightFor(MediaQuery.of(context)),
      child: list,
    );
  }
}

class _CategoryTile<E> extends StatelessWidget {
  const _CategoryTile({
    required this.panel,
    required this.metrics,
    required this.category,
    required this.depth,
  });

  final LibraryExportPanel<E> panel;
  final CompactControlMetrics metrics;
  final LibraryCategoryNode category;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final childCategories = panel.tree.childCategoriesOf(category.id);
    final categoryEntries = panel.tree.entriesOf(category.id);
    if (panel.hidesEmptyCategories &&
        childCategories.isEmpty &&
        categoryEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    final selection = panel.selection;
    final isExpanded = selection.isExpanded(category.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => selection.toggleCategoryBranch(category.id),
          child: Padding(
            padding: EdgeInsets.only(
              left: LibraryExportPanel.indentFor(depth),
            ),
            child: _buildHeader(
              context,
              hasChildren:
                  childCategories.isNotEmpty || categoryEntries.isNotEmpty,
              isExpanded: isExpanded,
            ),
          ),
        ),
        if (isExpanded) ...[
          ...childCategories.map(
            (child) => _CategoryTile<E>(
              panel: panel,
              metrics: metrics,
              category: child,
              depth: depth + 1,
            ),
          ),
          ...categoryEntries.map(
            (entry) =>
                _EntryTile<E>(panel: panel, entry: entry, depth: depth + 1),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool hasChildren,
    required bool isExpanded,
  }) {
    final theme = Theme.of(context);
    final selection = panel.selection;
    final totalChildren = selection.childCount(category.id);

    return Row(
      children: [
        if (hasChildren)
          IconButton(
            icon: Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 20,
            ),
            onPressed: () => selection.toggleExpanded(category.id),
            padding: EdgeInsets.zero,
            visualDensity: metrics.density,
            constraints: metrics.constraints,
          )
        else
          SizedBox(width: metrics.extent),
        SizedBox(
          width: 40,
          child: Checkbox(
            value: selection.categoryCheckboxValue(category.id),
            tristate: true,
            onChanged: (value) => selection.setCategoryBranchSelected(
              category.id,
              value == true,
            ),
          ),
        ),
        Icon(
          isExpanded ? Icons.folder_open : Icons.folder,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            category.displayName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (totalChildren > 0)
          Text(
            '${selection.selectedChildCount(category.id)}/$totalChildren',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
      ],
    );
  }
}

class _UncategorizedSection<E> extends StatelessWidget {
  const _UncategorizedSection({required this.panel, required this.metrics});

  final LibraryExportPanel<E> panel;
  final CompactControlMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final selection = panel.selection;
    final entries = panel.tree.uncategorizedEntries;
    final isExpanded = selection.isExpanded(
      LibrarySelectionController.uncategorizedCategoryId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: selection.toggleUncategorized,
          child: _buildHeader(context, entries.length, isExpanded),
        ),
        if (isExpanded)
          ...entries.map(
            (entry) => _EntryTile<E>(panel: panel, entry: entry, depth: 1),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, int total, bool isExpanded) {
    final theme = Theme.of(context);
    final selection = panel.selection;

    return Row(
      children: [
        IconButton(
          icon: Icon(
            isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
            size: 20,
          ),
          onPressed: () => selection.toggleExpanded(
            LibrarySelectionController.uncategorizedCategoryId,
          ),
          padding: EdgeInsets.zero,
          visualDensity: metrics.density,
          constraints: metrics.constraints,
        ),
        SizedBox(
          width: 40,
          child: Checkbox(
            value: selection.uncategorizedCheckboxValue,
            tristate: true,
            onChanged: (value) =>
                selection.setUncategorizedSelected(value == true),
          ),
        ),
        Icon(
          Icons.folder_open_outlined,
          size: 20,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            panel.uncategorizedLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Text(
          '${selection.selectedUncategorizedCount}/$total',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _EntryTile<E> extends StatelessWidget {
  const _EntryTile({
    required this.panel,
    required this.entry,
    required this.depth,
  });

  final LibraryExportPanel<E> panel;
  final LibraryEntryNode<E> entry;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final selection = panel.selection;

    return InkWell(
      onTap: () => selection.toggleEntry(entry.id),
      child: Padding(
        padding: EdgeInsets.only(left: LibraryExportPanel.indentFor(depth)),
        child: Row(
          children: [
            const SizedBox(width: 32),
            SizedBox(
              width: 40,
              child: Checkbox(
                value: selection.isEntrySelected(entry.id),
                onChanged: (value) =>
                    selection.setEntrySelected(entry.id, value == true),
              ),
            ),
            Expanded(child: panel.entryContentBuilder(context, entry)),
          ],
        ),
      ),
    );
  }
}
