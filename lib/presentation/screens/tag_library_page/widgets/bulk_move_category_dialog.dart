import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../adaptive/window_size_class.dart';
import '../../../widgets/common/adaptive_dialog_frame.dart';

/// 批量转移分类对话框
class BulkMoveCategoryDialog extends StatelessWidget {
  final List<TagLibraryCategory> categories;
  final String? currentCategoryId;

  const BulkMoveCategoryDialog({
    super.key,
    required this.categories,
    this.currentCategoryId,
  });

  /// 显示自适应分类选择面；选择分类时返回分类 ID，取消或返回时返回 null。
  static Future<String?> show(
    BuildContext context, {
    required List<TagLibraryCategory> categories,
    String? currentCategoryId,
  }) {
    return AdaptivePresenter.showForm<String>(
      context: context,
      titleBuilder: _buildTitle,
      sideSheetWidth: 440,
      builder: (panelContext, scrollController) => _BulkMoveCategoryContent(
        categories: categories,
        currentCategoryId: currentCategoryId,
        scrollController: scrollController,
      ),
    );
  }

  static Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.drive_file_move_outline, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.l10n.tagLibrary_moveToCategoryTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: AdaptiveDialogFrame(
        maxWidth: 440,
        maxHeight: 560,
        reservedVerticalSpace: 32,
        horizontalMargin: 16,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(child: _buildTitle(context)),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _BulkMoveCategoryContent(
                categories: categories,
                currentCategoryId: currentCategoryId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkMoveCategoryContent extends StatelessWidget {
  const _BulkMoveCategoryContent({
    required this.categories,
    required this.currentCategoryId,
    this.scrollController,
  });

  final List<TagLibraryCategory> categories;
  final String? currentCategoryId;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = context.adaptiveWindow.isCompact;

    return AdaptiveDialogFrame(
      key: const ValueKey('bulk-move-category-dialog-frame'),
      maxWidth: 440,
      maxHeight: isCompact ? double.infinity : 560,
      reservedVerticalSpace: 0,
      horizontalMargin: 0,
      child: ListView(
        key: const ValueKey('bulk-move-category-list'),
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              context.l10n.tagLibrary_selectTargetCategory,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _CategoryTile(
                    id: null,
                    name: context.l10n.tagLibrary_rootCategory,
                    isSelected: currentCategoryId == null,
                    onTap: () => Navigator.of(context).pop(''),
                    depth: 0,
                  ),
                  const Divider(height: 1, indent: 8, endIndent: 8),
                  ..._buildCategoryTree(context, null),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(context.l10n.common_cancel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryTree(
    BuildContext context,
    String? parentId, {
    int depth = 0,
  }) {
    final result = <Widget>[];
    final children = categories.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final category in children) {
      result.add(
        _CategoryTile(
          id: category.id,
          name: category.displayName,
          isSelected: category.id == currentCategoryId,
          onTap: () => Navigator.of(context).pop(category.id),
          depth: depth,
        ),
      );
      result.addAll(_buildCategoryTree(context, category.id, depth: depth + 1));
    }

    return result;
  }
}

/// 分类列表项
class _CategoryTile extends StatelessWidget {
  final String? id;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final int depth;

  const _CategoryTile({
    required this.id,
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.fromLTRB(8 + depth * 20, 10, 12, 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.folder : Icons.folder_outlined,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
