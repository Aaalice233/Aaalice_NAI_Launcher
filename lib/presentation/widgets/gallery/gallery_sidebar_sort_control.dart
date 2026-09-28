import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/library_sidebar_sort_provider.dart';
import '../../themes/core/layered_surface_style.dart';
import '../../utils/library_sidebar_sort.dart';
import '../common/app_toast.dart';

class GallerySidebarSortControl extends ConsumerWidget {
  const GallerySidebarSortControl({super.key, required this.section});

  final LibrarySidebarSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(librarySidebarSortProvider(section));
    final l10n = context.l10n;
    final sort = preference.sort;
    return Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(8),
      child: PopupMenuButton<LibrarySidebarSort>(
        key: ValueKey('sidebar-sort-${section.name}'),
        enabled: !preference.isSaving,
        tooltip: '${l10n.sidebarSort_title}: ${_label(l10n, sort)}',
        color: overlaySurfaceColor(Theme.of(context).colorScheme),
        surfaceTintColor: Colors.transparent,
        position: PopupMenuPosition.under,
        onSelected: (value) async {
          final owner = ref.read(librarySidebarSortProvider(section).notifier);
          try {
            await owner.setSort(value);
          } catch (error, stack) {
            AppLogger.e(
              'Failed to save sidebar sort: ${section.name}',
              error,
              stack,
              'GallerySidebar',
            );
            if (context.mounted) {
              AppToast.error(
                context,
                l10n.globalSettings_saveFailed(error.toString()),
              );
            }
          }
        },
        itemBuilder: (_) => _menuItems(l10n, sort),
        style: IconButton.styleFrom(
          fixedSize: const Size(44, 48),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          hoverColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.10),
        ),
        icon: ExcludeSemantics(child: _SortModeIcon(sort: sort)),
      ),
    );
  }

  List<PopupMenuEntry<LibrarySidebarSort>> _menuItems(
    AppLocalizations l10n,
    LibrarySidebarSort sort,
  ) => [
    for (final value in LibrarySidebarSort.values)
      PopupMenuItem(
        key: ValueKey('sidebar-sort-option-${value.name}'),
        value: value,
        child: Semantics(
          selected: sort == value,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: sort == value
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_label(l10n, value))),
              ],
            ),
          ),
        ),
      ),
  ];

  String _label(AppLocalizations l10n, LibrarySidebarSort sort) =>
      switch (sort) {
        LibrarySidebarSort.original => l10n.sidebarSort_original,
        LibrarySidebarSort.nameAscending => l10n.sidebarSort_nameAscending,
        LibrarySidebarSort.nameDescending => l10n.sidebarSort_nameDescending,
        LibrarySidebarSort.countDescending => l10n.sidebarSort_countDescending,
        LibrarySidebarSort.countAscending => l10n.sidebarSort_countAscending,
      };
}

class _SortModeIcon extends StatelessWidget {
  const _SortModeIcon({required this.sort});

  final LibrarySidebarSort sort;

  @override
  Widget build(BuildContext context) {
    final isName =
        sort == LibrarySidebarSort.nameAscending ||
        sort == LibrarySidebarSort.nameDescending;
    final ascending =
        sort == LibrarySidebarSort.nameAscending ||
        sort == LibrarySidebarSort.countAscending;
    return SizedBox(
      width: 28,
      height: 26,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 1,
            child: Icon(Icons.sort_rounded, size: 18),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: sort == LibrarySidebarSort.original
                ? const Icon(Icons.drag_indicator_rounded, size: 12)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isName ? 'A' : '#',
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 10,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
