import 'package:flutter/foundation.dart';

import '../../providers/bulk_operation_provider.dart';
import '../../providers/gallery_category_provider.dart';
import '../../providers/local_gallery_provider.dart';

/// Immutable snapshot consumed by the local gallery screen shell.
///
/// Gallery files, filters, paging, selection, and categories remain owned by
/// their Riverpod providers; this object only derives presentation geometry.
@immutable
class LocalGalleryViewModel {
  const LocalGalleryViewModel({
    required this.gallery,
    required this.bulkOperation,
    required this.categories,
    required this.isSelectionMode,
    required this.showCategoryPanel,
    required this.isPackingImages,
    required this.usePersistentCategories,
    required this.showPersistentCategories,
    required this.contentWidth,
    required this.columns,
    required this.itemWidth,
  });

  factory LocalGalleryViewModel.fromStates({
    required LocalGalleryState gallery,
    required BulkOperationState bulkOperation,
    required GalleryCategoryState categories,
    required bool isSelectionMode,
    required bool categoryPanelRequested,
    required bool isPackingImages,
    required double maxWidth,
  }) {
    final usePersistentCategories = maxWidth >= 1000;
    final showPersistentCategories =
        categoryPanelRequested && usePersistentCategories;
    final contentWidth = maxWidth - (showPersistentCategories ? 250 : 0);
    const horizontalPadding = 24.0;
    const spacing = 12.0;
    const minimumItemWidth = 160.0;
    final availableGridWidth = (contentWidth - horizontalPadding).clamp(
      0.0,
      double.infinity,
    );
    final columns =
        ((availableGridWidth + spacing) / (minimumItemWidth + spacing))
            .floor()
            .clamp(1, 8);
    final itemWidth = (availableGridWidth - spacing * (columns - 1)) / columns;

    return LocalGalleryViewModel(
      gallery: gallery,
      bulkOperation: bulkOperation,
      categories: categories,
      isSelectionMode: isSelectionMode,
      showCategoryPanel: categoryPanelRequested,
      isPackingImages: isPackingImages,
      usePersistentCategories: usePersistentCategories,
      showPersistentCategories: showPersistentCategories,
      contentWidth: contentWidth,
      columns: columns,
      itemWidth: itemWidth,
    );
  }

  final LocalGalleryState gallery;
  final BulkOperationState bulkOperation;
  final GalleryCategoryState categories;
  final bool isSelectionMode;
  final bool showCategoryPanel;
  final bool isPackingImages;
  final bool usePersistentCategories;
  final bool showPersistentCategories;
  final double contentWidth;
  final int columns;
  final double itemWidth;
}
