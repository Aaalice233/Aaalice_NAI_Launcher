import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../agent_chat/widgets/agent_resource_drop_region.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../providers/tag_library_selection_provider.dart';
import 'entry_card.dart';
import 'entry_list_item.dart';
import 'entry_reorder/entry_reorder_item.dart';

enum TagLibraryEntryTileLayout { card, list }

/// 词库条目在网格、列表与分组视图中的统一组装：多选、资源拖动源与拖拽重排
class TagLibraryEntryTile extends ConsumerWidget {
  const TagLibraryEntryTile({
    super.key,
    required this.entry,
    required this.layout,
    required this.onEdit,
    required this.onDelete,
    required this.onSend,
    required this.onClassify,
    this.showCategory = true,
  });

  final TagLibraryEntry entry;
  final TagLibraryEntryTileLayout layout;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// 打开「发送到主页」对话框
  final VoidCallback onSend;
  final VoidCallback onClassify;

  /// 分组视图的组标题已表明分类，条目上不再重复
  final bool showCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(tagLibrarySelectionNotifierProvider);
    final categoryName = showCategory
        ? ref.watch(
            tagLibraryPageNotifierProvider.select(
              (state) => _categoryName(state.categories, entry.categoryId),
            ),
          )
        : null;

    void toggleSelection() {
      final notifier = ref.read(tagLibrarySelectionNotifierProvider.notifier);
      if (HardwareKeyboard.instance.isShiftPressed) {
        final ids = ref
            .read(tagLibraryPageNotifierProvider)
            .presentedEntries
            .map((e) => e.id)
            .toList();
        notifier.selectRange(entry.id, ids);
      } else if (!selection.isActive) {
        notifier.enterAndSelect(entry.id);
      } else {
        notifier.toggle(entry.id);
      }
    }

    void toggleFavorite() => ref
        .read(tagLibraryPageNotifierProvider.notifier)
        .toggleFavorite(entry.id);

    return EntryReorderItem(
      entry: entry,
      axis: switch (layout) {
        TagLibraryEntryTileLayout.card => Axis.horizontal,
        TagLibraryEntryTileLayout.list => Axis.vertical,
      },
      builder: (context, {required longPressSelects}) =>
          AgentResourceDragSource(
            reference: AgentChatResourceReference(
              kind: AgentChatResourceKind.tagLibraryEntry,
              source: 'tag_library',
              resourceId: entry.id,
              display: {'name': entry.displayName},
            ),
            child: switch (layout) {
              TagLibraryEntryTileLayout.card => EntryCard(
                entry: entry,
                categoryName: categoryName,
                isSelectionMode: selection.isActive,
                isSelected: selection.isSelected(entry.id),
                onToggleSelection: toggleSelection,
                longPressSelects: longPressSelects,
                onTap: onEdit,
                onDelete: onDelete,
                onEdit: onEdit,
                onSend: onSend,
                onClassify: onClassify,
                onToggleFavorite: toggleFavorite,
              ),
              TagLibraryEntryTileLayout.list => EntryListItem(
                entry: entry,
                categoryName: categoryName,
                isSelectionMode: selection.isActive,
                isSelected: selection.isSelected(entry.id),
                onToggleSelection: toggleSelection,
                longPressSelects: longPressSelects,
                onTap: onSend,
                onDelete: onDelete,
                onEdit: onEdit,
                onClassify: onClassify,
                onToggleFavorite: toggleFavorite,
              ),
            },
          ),
    );
  }

  static String _categoryName(
    List<TagLibraryCategory> categories,
    String? categoryId,
  ) {
    if (categoryId == null) return '';
    return categories
            .firstWhereOrNull((category) => category.id == categoryId)
            ?.displayName ??
        '';
  }
}
