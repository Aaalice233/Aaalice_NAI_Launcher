import 'package:flutter/material.dart';

import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/fixed_tags_provider.dart';

@immutable
class FixedTagsDialogViewData {
  const FixedTagsDialogViewData({
    required this.state,
    required this.libraryEntries,
  });

  final FixedTagsState state;
  final List<TagLibraryEntry> libraryEntries;

  List<FixedTagEntry> entriesFor(
    FixedTagPromptType promptType,
    String query, {
    bool enabledOnly = false,
  }) {
    final entries =
        (promptType == FixedTagPromptType.positive
                ? state.positiveEntries
                : state.negativeEntries)
            .sortedByOrder();
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty && !enabledOnly) return entries;
    return entries
        .where((entry) {
          if (enabledOnly && !entry.enabled) return false;
          return entry.name.toLowerCase().contains(normalized) ||
              entry.content.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }
}

@immutable
class FixedTagsDialogCommands {
  const FixedTagsDialogCommands({
    required this.close,
    required this.openLibraryPage,
    required this.toggleNegativePanel,
    required this.undo,
    required this.redo,
    required this.setAllEnabled,
    required this.setPromptTypeEnabled,
    required this.toggleEntry,
    required this.reorder,
    required this.editEntry,
    required this.deleteEntry,
    required this.clearAll,
    required this.pickFromLibrary,
    required this.showLinkManager,
    required this.createLink,
  });

  final VoidCallback close;
  final VoidCallback openLibraryPage;
  final VoidCallback toggleNegativePanel;
  final VoidCallback undo;
  final VoidCallback redo;
  final ValueChanged<bool> setAllEnabled;
  final void Function(FixedTagPromptType promptType, bool enabled)
  setPromptTypeEnabled;
  final ValueChanged<FixedTagEntry> toggleEntry;
  final void Function(FixedTagPromptType promptType, int oldIndex, int newIndex)
  reorder;
  final void Function(
    FixedTagEntry? entry,
    FixedTagPromptType initialPromptType,
  )
  editEntry;
  final ValueChanged<FixedTagEntry> deleteEntry;
  final VoidCallback clearAll;
  final ValueChanged<FixedTagPromptType> pickFromLibrary;
  final ValueChanged<FixedTagEntry> showLinkManager;
  final void Function(String positiveEntryId, String negativeEntryId)
  createLink;
}
