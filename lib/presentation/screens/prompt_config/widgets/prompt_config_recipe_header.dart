import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../themes/core/input_surface_style.dart';

/// 配方列表顶部：标题说明与类别搜索框
class PromptConfigRecipeHeader extends StatelessWidget {
  const PromptConfigRecipeHeader({
    super.key,
    required this.query,
    required this.searchController,
    required this.searchFocusNode,
    required this.onQueryChanged,
    this.showShortcutHint = true,
  });

  final String query;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onQueryChanged;
  final bool showShortcutHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RecipeHeading(),
        const SizedBox(height: 14),
        _LibrarySearchField(
          query: query,
          controller: searchController,
          focusNode: searchFocusNode,
          onChanged: onQueryChanged,
          showShortcutHint: showShortcutHint,
        ),
      ],
    );
  }
}

class _RecipeHeading extends StatelessWidget {
  const _RecipeHeading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.randomManager_recipeTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          context.l10n.randomManager_recipeSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LibrarySearchField extends StatelessWidget {
  const _LibrarySearchField({
    required this.query,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.showShortcutHint = true,
  });

  final String query;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool showShortcutHint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final searchLabel = showShortcutHint
        ? context.l10n.randomManager_searchCategories
        : context.l10n.randomManager_searchCategoriesCompact;
    return Semantics(
      textField: true,
      label: searchLabel,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: searchLabel,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.common_clear,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          filled: true,
          fillColor: inputSurfaceFillColor(colors),
          border: inputSurfaceBorder(colors, BorderRadius.circular(10)),
          enabledBorder: inputSurfaceBorder(colors, BorderRadius.circular(10)),
          focusedBorder: inputSurfaceBorder(
            colors,
            BorderRadius.circular(10),
            focused: true,
          ),
        ),
      ),
    );
  }
}
