import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/enums/precise_ref_type.dart';
import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../providers/precise_ref_library_provider.dart';
import '../../../widgets/gallery/gallery_album_tree_view.dart';
import '../../../widgets/gallery/gallery_sidebar.dart';

class PreciseRefLibrarySidebar extends StatefulWidget {
  const PreciseRefLibrarySidebar({
    super.key,
    required this.state,
    required this.onFilterChanged,
    this.modal = false,
  });

  final PreciseRefLibraryState state;
  final void Function({required bool favoritesOnly, PreciseRefType? type})
  onFilterChanged;
  final bool modal;

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
          GalleryAllImagesItem(
            key: const Key('precise-ref-sidebar-all'),
            count: state.entries.length,
            isSelected: !state.favoritesOnly && state.typeFilter == null,
            onTap: () => widget.onFilterChanged(favoritesOnly: false),
          ),
          GallerySidebarNavigationItem(
            key: const Key('precise-ref-sidebar-favorites'),
            icon: Icons.star_border_rounded,
            selectedIcon: Icons.star_rounded,
            iconColor: Colors.amber.shade700,
            label: l10n.tagLibrary_favorites,
            count: state.entries.where((entry) => entry.isFavorite).length,
            isSelected: state.favoritesOnly,
            onTap: () => widget.onFilterChanged(favoritesOnly: true),
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
                  for (final type in PreciseRefType.values)
                    GallerySidebarNavigationItem(
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
