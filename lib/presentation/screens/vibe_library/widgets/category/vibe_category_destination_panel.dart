import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/vibe/vibe_library_category.dart';
import '../../../../adaptive/adaptive_presenter.dart';

/// Empty string means uncategorized; null means the picker was cancelled.
class VibeCategoryDestinationPanel extends StatelessWidget {
  const VibeCategoryDestinationPanel({
    super.key,
    required this.categories,
    this.scrollController,
  });

  final List<VibeLibraryCategory> categories;
  final ScrollController? scrollController;

  static Future<String?> show(
    BuildContext context, {
    required List<VibeLibraryCategory> categories,
  }) => AdaptivePresenter.showForm<String>(
    context: context,
    title: context.l10n.vibeLibrary_moveToCategory,
    sideSheetWidth: 440,
    builder: (panelContext, scrollController) => VibeCategoryDestinationPanel(
      categories: categories,
      scrollController: scrollController,
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('vibe-category-destination-list'),
    controller: scrollController,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    children: [
      ListTile(
        leading: const Icon(Icons.folder_off_outlined),
        title: Text(context.l10n.vibeLibrary_uncategorized),
        onTap: () => Navigator.of(context).pop(''),
      ),
      for (final category in categories)
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(category.name),
          onTap: () => Navigator.of(context).pop(category.id),
        ),
    ],
  );
}
