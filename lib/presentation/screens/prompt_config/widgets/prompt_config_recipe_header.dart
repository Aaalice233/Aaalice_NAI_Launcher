import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/common/themed_input.dart';

/// 配方列表顶部：标题说明与类别搜索框
class PromptConfigRecipeHeader extends StatelessWidget {
  const PromptConfigRecipeHeader({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onQueryChanged,
    this.showShortcutHint = true,
  });

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
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.showShortcutHint = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool showShortcutHint;

  @override
  Widget build(BuildContext context) {
    final searchLabel = showShortcutHint
        ? context.l10n.randomManager_searchCategories
        : context.l10n.randomManager_searchCategoriesCompact;
    return ThemedInput(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      hintText: searchLabel,
      semanticLabel: searchLabel,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search_rounded, size: 20),
      ),
      showClearButton: true,
    );
  }
}
