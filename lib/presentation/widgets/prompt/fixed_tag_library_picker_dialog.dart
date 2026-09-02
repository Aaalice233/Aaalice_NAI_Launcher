import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/window_size_class.dart';
import '../common/adaptive_dialog_frame.dart';
import '../common/themed_input.dart';
import '../tag_library/tag_library_entry_hover_preview.dart';

class FixedTagLibraryPickerDialog extends StatefulWidget {
  const FixedTagLibraryPickerDialog({
    super.key,
    required this.entries,
    required this.onSelect,
    this.presentationManaged = false,
  });

  final List<TagLibraryEntry> entries;
  final ValueChanged<TagLibraryEntry> onSelect;
  final bool presentationManaged;

  static Future<TagLibraryEntry?> show({
    required BuildContext context,
    required List<TagLibraryEntry> entries,
  }) {
    return AdaptivePresenter.showForm<TagLibraryEntry>(
      context: context,
      title: context.l10n.fixedTags_addFromLibrary,
      sideSheetWidth: 460,
      builder: (_, __) => FixedTagLibraryPickerDialog(
        entries: entries,
        presentationManaged: true,
        onSelect: (_) {},
      ),
    );
  }

  @override
  State<FixedTagLibraryPickerDialog> createState() =>
      _FixedTagLibraryPickerDialogState();
}

class _FixedTagLibraryPickerDialogState
    extends State<FixedTagLibraryPickerDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<TagLibraryEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return widget.entries;
    final query = _searchQuery.toLowerCase();
    return widget.entries
        .where((entry) {
          return entry.name.toLowerCase().contains(query) ||
              entry.content.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredEntries;
    final isCompact = context.adaptiveWindow.isCompact;
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ThemedInput(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.l10n.fixedTags_searchLibraryEntries,
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: theme.colorScheme.outline,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    context.l10n.fixedTags_noMatchingResults,
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final tile = _LibraryEntryTile(
                      key: ValueKey('fixed-tag-library-entry-${entry.id}'),
                      entry: entry,
                      onTap: () {
                        widget.onSelect(entry);
                        Navigator.of(context).pop(entry);
                      },
                    );
                    if (!entry.hasThumbnail) return tile;
                    return TagLibraryEntryHoverPreview(
                      entry: entry,
                      child: tile,
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
      ],
    );
    if (widget.presentationManaged) return body;

    final content = AdaptiveDialogFrame(
      maxWidth: 420,
      maxHeight: 480,
      reservedVerticalSpace: isCompact ? 0 : 48,
      scaleReservedVerticalSpace: true,
      horizontalMargin: isCompact ? 0 : 24,
      child: body,
    );
    return Dialog(
      insetPadding: EdgeInsets.all(isCompact ? 0 : 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isCompact ? 0 : 6),
      ),
      child: isCompact ? SafeArea(child: content) : content,
    );
  }
}

class _LibraryEntryTile extends StatelessWidget {
  const _LibraryEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final TagLibraryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name.isNotEmpty ? entry.name : entry.content,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.name.isNotEmpty && entry.content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          entry.content.replaceAll('\n', ' '),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.add_rounded,
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
