import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../providers/precise_ref_library_provider.dart';
import '../../../widgets/gallery/gallery_album_tree_view.dart';
import '../../../widgets/gallery/gallery_sidebar.dart';
import '../../../widgets/common/library_classification_drag.dart';
import '../../../../data/models/precise_ref/precise_ref_library_entry.dart';

class PreciseRefLibrarySidebar extends StatefulWidget {
  const PreciseRefLibrarySidebar({
    super.key,
    required this.state,
    required this.onFilterChanged,
    this.modal = false,
    this.onEntryTypeDrop,
    this.onFavoriteDrop,
  });

  final PreciseRefLibraryState state;
  final void Function({required bool favoritesOnly, PreciseRefType? type})
  onFilterChanged;
  final bool modal;
  final void Function(PreciseRefLibraryEntry entry, PreciseRefType type)?
  onEntryTypeDrop;
  final ValueChanged<PreciseRefLibraryEntry>? onFavoriteDrop;

  @override
  State<PreciseRefLibrarySidebar> createState() =>
      _PreciseRefLibrarySidebarState();
}

class _PreciseRefLibrarySidebarState extends State<PreciseRefLibrarySidebar> {
  bool _typesExpanded = true;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final l10n = context.l10n;
    return GallerySidebarSurface(
      key: widget.modal
          ? const Key('precise-ref-library-category-panel')
          : const Key('precise-ref-library-category-sidebar'),
      modal: widget.modal,
      child: Column(
        children: [
          if (!widget.modal)
            const SizedBox(
              height: GalleryCollectionChrome.navigationTopPadding,
            ),
          GalleryAllImagesItem(
            key: const Key('precise-ref-sidebar-all'),
            count: state.entries.length,
            isSelected: !state.favoritesOnly && state.typeFilter == null,
            onTap: () => widget.onFilterChanged(favoritesOnly: false),
          ),
          GallerySidebarSectionHeader(
            toggleKey: const Key('precise-ref-type-section-toggle'),
            icon: Icons.category_outlined,
            title: l10n.tagLibrary_categories,
            isExpanded: _typesExpanded,
            onToggle: () => setState(() => _typesExpanded = !_typesExpanded),
          ),
          if (_typesExpanded)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  LibraryClassificationDropTarget<PreciseRefLibraryEntry>(
                    enabled: widget.onFavoriteDrop != null,
                    canAccept: (entry) => !entry.isFavorite,
                    onAccept: (entry) => widget.onFavoriteDrop?.call(entry),
                    child: GallerySidebarFavoritesItem(
                      key: const Key('precise-ref-sidebar-favorites'),
                      label: l10n.tagLibrary_favorites,
                      count: state.entries
                          .where((entry) => entry.isFavorite)
                          .length,
                      isSelected: state.favoritesOnly,
                      onTap: () => widget.onFilterChanged(favoritesOnly: true),
                    ),
                  ),
                  for (final type in PreciseRefType.values)
                    LibraryClassificationDropTarget<PreciseRefLibraryEntry>(
                      enabled: widget.onEntryTypeDrop != null,
                      canAccept: (entry) => entry.type != type,
                      onAccept: (entry) =>
                          widget.onEntryTypeDrop?.call(entry, type),
                      child: GallerySidebarNavigationItem(
                        key: Key('precise-ref-sidebar-type-${type.name}'),
                        icon: type.icon,
                        selectedIcon: type.icon,
                        label: type.getDisplayName(
                          character: l10n.preciseRef_typeCharacter,
                          style: l10n.preciseRef_typeStyle,
                          characterAndStyle:
                              l10n.preciseRef_typeCharacterAndStyle,
                        ),
                        count: state.entries
                            .where((entry) => entry.type == type)
                            .length,
                        isSelected:
                            !state.favoritesOnly && state.typeFilter == type,
                        onTap: () => widget.onFilterChanged(
                          favoritesOnly: false,
                          type: type,
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}
