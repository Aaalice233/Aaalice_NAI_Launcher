import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/online_gallery/gallery_prompt_projection.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../common/prompt_selection_tile.dart';

class GalleryPromptCopyDialog extends StatefulWidget {
  const GalleryPromptCopyDialog._({
    required this.projection,
    required this.initialSelection,
    required this.scrollController,
  });

  final GalleryPromptCopyProjection projection;
  final GalleryPromptCopySelection initialSelection;
  final ScrollController scrollController;

  static Future<GalleryPromptCopySelection?> show(
    BuildContext context, {
    required GalleryPromptCopyProjection projection,
    required GalleryPromptCopySelection initialSelection,
  }) => AdaptivePresenter.showForm<GalleryPromptCopySelection>(
    context: context,
    titleBuilder: (panelContext) => Text(
      panelContext.l10n.onlineGallery_copyPrompt,
      style: Theme.of(panelContext).textTheme.titleMedium,
    ),
    dialogWidth: 500,
    builder: (_, scrollController) => GalleryPromptCopyDialog._(
      projection: projection,
      initialSelection: initialSelection,
      scrollController: scrollController,
    ),
  );

  @override
  State<GalleryPromptCopyDialog> createState() =>
      _GalleryPromptCopyDialogState();
}

class _GalleryPromptCopyDialogState extends State<GalleryPromptCopyDialog> {
  late GalleryPromptCopySelection _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialSelection;
  }

  bool get _canCopy =>
      widget.projection.buildText(_selection).trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = _options(context);
    return ListView(
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      children: [
        Text(
          context.l10n.onlineGallery_promptCopyDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < options.length; index++) ...[
                options[index],
                if (index + 1 < options.length) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(top: 8, bottom: 4),
          child: OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.common_cancel),
              ),
              FilledButton.icon(
                onPressed: _canCopy
                    ? () => Navigator.of(context).pop(_selection)
                    : null,
                icon: const Icon(Icons.copy, size: 17),
                label: Text(context.l10n.common_copy),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _options(BuildContext context) {
    final projection = widget.projection;
    final result = <Widget>[];
    if (projection.hasMainPositive) {
      result.add(
        PromptSelectionTile(
          key: const ValueKey('gallery-copy-main-positive'),
          icon: Icons.subject,
          title: context.l10n.promptCopy_mainPositive,
          subtitle: context.l10n.onlineGallery_promptCopyStructuredHint,
          unavailableLabel: context.l10n.detail_promptCategoryUnavailable,
          value: _selection.mainPositive,
          enabled: true,
          onChanged: (value) =>
              _update(_selection.copyWith(mainPositive: value)),
        ),
      );
    }
    for (final category in GalleryPromptCopyProjection.categoryOrder) {
      if (!projection.availableCategories.contains(category)) continue;
      result.add(
        PromptSelectionTile(
          key: ValueKey('gallery-copy-category-${category.name}'),
          icon: _categoryIcon(category),
          title: _categoryLabel(context, category),
          subtitle: context.l10n.onlineGallery_promptCopyCategoryHint,
          unavailableLabel: context.l10n.detail_promptCategoryUnavailable,
          value: _selection.tagCategories.contains(category),
          enabled: true,
          onChanged: (value) => _setCategory(category, value),
        ),
      );
    }
    if (projection.hasMainNegative) {
      result.add(
        PromptSelectionTile(
          key: const ValueKey('gallery-copy-main-negative'),
          icon: Icons.block_outlined,
          title: context.l10n.promptCopy_mainNegative,
          subtitle: context.l10n.onlineGallery_promptCopyStructuredHint,
          unavailableLabel: context.l10n.detail_promptCategoryUnavailable,
          value: _selection.mainNegative,
          enabled: true,
          onChanged: (value) =>
              _update(_selection.copyWith(mainNegative: value)),
        ),
      );
    }
    for (final index in projection.availableCharacterPositiveIndices) {
      result.add(
        PromptSelectionTile(
          key: ValueKey('gallery-copy-character-positive-$index'),
          icon: Icons.person_outline,
          title: context.l10n.promptCopy_characterPositive(index + 1),
          subtitle: _characterLabel(index),
          unavailableLabel: context.l10n.detail_promptCategoryUnavailable,
          value: _selection.characterPositiveIndices.contains(index),
          enabled: true,
          indent: 12,
          onChanged: (value) => _setCharacter(index, value, positive: true),
        ),
      );
    }
    for (final index in projection.availableCharacterNegativeIndices) {
      result.add(
        PromptSelectionTile(
          key: ValueKey('gallery-copy-character-negative-$index'),
          icon: Icons.person_off_outlined,
          title: context.l10n.promptCopy_characterNegative(index + 1),
          subtitle: _characterLabel(index),
          unavailableLabel: context.l10n.detail_promptCategoryUnavailable,
          value: _selection.characterNegativeIndices.contains(index),
          enabled: true,
          indent: 12,
          onChanged: (value) => _setCharacter(index, value, positive: false),
        ),
      );
    }
    return result;
  }

  String _characterLabel(int index) {
    final label = widget.projection.characterPrompts[index].label.trim();
    return label.isEmpty
        ? context.l10n.onlineGallery_promptCopyStructuredHint
        : label;
  }

  void _setCategory(GalleryPromptCopyCategory category, bool value) {
    final categories = {..._selection.tagCategories};
    value ? categories.add(category) : categories.remove(category);
    _update(_selection.copyWith(tagCategories: categories));
  }

  void _setCharacter(int index, bool value, {required bool positive}) {
    final indices = {
      ...(positive
          ? _selection.characterPositiveIndices
          : _selection.characterNegativeIndices),
    };
    value ? indices.add(index) : indices.remove(index);
    _update(
      positive
          ? _selection.copyWith(characterPositiveIndices: indices)
          : _selection.copyWith(characterNegativeIndices: indices),
    );
  }

  void _update(GalleryPromptCopySelection selection) {
    setState(() => _selection = selection);
  }

  String _categoryLabel(
    BuildContext context,
    GalleryPromptCopyCategory category,
  ) => switch (category) {
    GalleryPromptCopyCategory.general => context.l10n.tagCategory_general,
    GalleryPromptCopyCategory.character => context.l10n.tagCategory_character,
    GalleryPromptCopyCategory.copyright => context.l10n.tagCategory_copyright,
    GalleryPromptCopyCategory.artist => context.l10n.tagCategory_artist,
    GalleryPromptCopyCategory.meta => context.l10n.tagCategory_meta,
  };

  IconData _categoryIcon(GalleryPromptCopyCategory category) =>
      switch (category) {
        GalleryPromptCopyCategory.general => Icons.sell_outlined,
        GalleryPromptCopyCategory.character => Icons.people_outline,
        GalleryPromptCopyCategory.copyright => Icons.movie_filter_outlined,
        GalleryPromptCopyCategory.artist => Icons.brush_outlined,
        GalleryPromptCopyCategory.meta => Icons.info_outline,
      };
}
