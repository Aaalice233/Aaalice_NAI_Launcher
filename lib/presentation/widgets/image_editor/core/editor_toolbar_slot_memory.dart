import 'package:flutter/foundation.dart';

/// 工具栏折叠按钮各自最近用过的项；只活在本次编辑会话，不落盘
class EditorToolbarSlotMemory extends ChangeNotifier {
  final Map<String, String> _itemIdBySlot = {};

  String? recall(String slotKey) => _itemIdBySlot[slotKey];

  void remember(String slotKey, String itemId) {
    if (_itemIdBySlot[slotKey] == itemId) return;
    _itemIdBySlot[slotKey] = itemId;
    notifyListeners();
  }

  /// 已选中的项优先，其次是记住的项，都没有时取第一项
  int displayedIndex(
    String slotKey,
    List<String> itemIds, {
    int? selectedIndex,
  }) {
    if (selectedIndex != null) return selectedIndex;
    final remembered = itemIds.indexOf(recall(slotKey) ?? '');
    return remembered < 0 ? 0 : remembered;
  }
}
