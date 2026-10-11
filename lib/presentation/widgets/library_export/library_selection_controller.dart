import 'dart:collection';

import 'package:flutter/foundation.dart';

/// 分类树中的分类节点。
@immutable
class LibraryCategoryNode {
  const LibraryCategoryNode({
    required this.id,
    required this.displayName,
    this.parentId,
  });

  final String id;
  final String displayName;
  final String? parentId;
}

/// 分类树中的条目节点；[value] 保留原始模型供调用方渲染。
@immutable
class LibraryEntryNode<E> {
  const LibraryEntryNode({
    required this.id,
    required this.value,
    this.categoryId,
  });

  final String id;
  final E value;
  final String? categoryId;
}

/// 分类与条目的父子归属，同级顺序与传入顺序一致。
class LibrarySelectionTree<E> {
  LibrarySelectionTree({
    required List<LibraryCategoryNode> categories,
    required List<LibraryEntryNode<E>> entries,
  }) : categories = List.unmodifiable(categories),
       entries = List.unmodifiable(entries) {
    for (final category in this.categories) {
      _childCategories
          .putIfAbsent(category.parentId, () => <LibraryCategoryNode>[])
          .add(category);
    }
    for (final entry in this.entries) {
      _entriesByCategory
          .putIfAbsent(entry.categoryId, () => <LibraryEntryNode<E>>[])
          .add(entry);
    }
  }

  final List<LibraryCategoryNode> categories;
  final List<LibraryEntryNode<E>> entries;

  final Map<String?, List<LibraryCategoryNode>> _childCategories = {};
  final Map<String?, List<LibraryEntryNode<E>>> _entriesByCategory = {};

  List<LibraryCategoryNode> get rootCategories => childCategoriesOf(null);

  List<LibraryEntryNode<E>> get uncategorizedEntries => entriesOf(null);

  List<LibraryCategoryNode> childCategoriesOf(String? categoryId) =>
      _childCategories[categoryId] ?? const <LibraryCategoryNode>[];

  List<LibraryEntryNode<E>> entriesOf(String? categoryId) =>
      _entriesByCategory[categoryId] ?? List<LibraryEntryNode<E>>.empty();
}

/// 条目与分类的多选、展开与级联状态。
///
/// 初始状态为全选，并展开全部根分类；存在未分类条目时一并展开未分类分组。
class LibrarySelectionController extends ChangeNotifier {
  LibrarySelectionController({required LibrarySelectionTree<Object?> tree})
    : _tree = tree {
    _selectedEntryIds.addAll(tree.entries.map((entry) => entry.id));
    _selectedCategoryIds.addAll(tree.categories.map((category) => category.id));
    _expandedCategoryIds.addAll(
      tree.rootCategories.map((category) => category.id),
    );
    if (tree.uncategorizedEntries.isNotEmpty) {
      _expandedCategoryIds.add(uncategorizedCategoryId);
    }
  }

  /// 未分类分组在展开集合中的占位 id。
  static const String uncategorizedCategoryId = '__uncategorized__';

  final LibrarySelectionTree<Object?> _tree;
  final Set<String> _selectedEntryIds = <String>{};
  final Set<String> _selectedCategoryIds = <String>{};
  final Set<String> _expandedCategoryIds = <String>{};

  Set<String> get selectedEntryIds => UnmodifiableSetView(_selectedEntryIds);
  Set<String> get selectedCategoryIds =>
      UnmodifiableSetView(_selectedCategoryIds);
  Set<String> get expandedCategoryIds =>
      UnmodifiableSetView(_expandedCategoryIds);

  bool isEntrySelected(String entryId) => _selectedEntryIds.contains(entryId);

  bool isCategorySelected(String categoryId) =>
      _selectedCategoryIds.contains(categoryId);

  bool isExpanded(String categoryId) =>
      _expandedCategoryIds.contains(categoryId);

  bool get isEverythingSelected =>
      _selectedEntryIds.length == _tree.entries.length &&
      _selectedCategoryIds.length == _tree.categories.length;

  bool get isNothingSelected =>
      _selectedEntryIds.isEmpty && _selectedCategoryIds.isEmpty;

  int get selectedCount => _selectedEntryIds.length + _selectedCategoryIds.length;

  /// 分类下直接子分类与直接条目的总数。
  int childCount(String categoryId) =>
      _tree.childCategoriesOf(categoryId).length +
      _tree.entriesOf(categoryId).length;

  /// 分类下直接子分类与直接条目中已选中的数量。
  int selectedChildCount(String categoryId) =>
      _tree
          .childCategoriesOf(categoryId)
          .where((category) => isCategorySelected(category.id))
          .length +
      _tree.entriesOf(categoryId).where((entry) => isEntrySelected(entry.id)).length;

  int get selectedUncategorizedCount =>
      _tree.uncategorizedEntries.where((entry) => isEntrySelected(entry.id)).length;

  /// 分类行的三态值：无子项选中为 false，子项与自身全选为 true，其余为部分选中。
  bool? categoryCheckboxValue(String categoryId) {
    final selected = selectedChildCount(categoryId);
    if (selected == 0) return false;
    if (selected == childCount(categoryId) && isCategorySelected(categoryId)) {
      return true;
    }
    return null;
  }

  bool? get uncategorizedCheckboxValue {
    final selected = selectedUncategorizedCount;
    if (selected == 0) return false;
    return selected == _tree.uncategorizedEntries.length ? true : null;
  }

  void setEntrySelected(String entryId, bool selected) {
    if (selected) {
      _selectedEntryIds.add(entryId);
    } else {
      _selectedEntryIds.remove(entryId);
    }
    notifyListeners();
  }

  void toggleEntry(String entryId) =>
      setEntrySelected(entryId, !isEntrySelected(entryId));

  /// 只改变该分类自身的选中状态。
  void setCategorySelected(String categoryId, bool selected) {
    if (selected) {
      _selectedCategoryIds.add(categoryId);
    } else {
      _selectedCategoryIds.remove(categoryId);
    }
    notifyListeners();
  }

  /// 连同直接子分类与直接条目一起改变选中状态。
  void setCategoryBranchSelected(String categoryId, bool selected) {
    _applyCategoryBranch(categoryId, selected);
    notifyListeners();
  }

  void toggleCategoryBranch(String categoryId) =>
      setCategoryBranchSelected(categoryId, !isCategorySelected(categoryId));

  void setUncategorizedSelected(bool selected) {
    _applyEntries(_tree.uncategorizedEntries, selected);
    notifyListeners();
  }

  void toggleUncategorized() {
    final entries = _tree.uncategorizedEntries;
    final allSelected = entries.every((entry) => isEntrySelected(entry.id));
    setUncategorizedSelected(!allSelected);
  }

  void toggleExpanded(String categoryId) {
    if (!_expandedCategoryIds.remove(categoryId)) {
      _expandedCategoryIds.add(categoryId);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedEntryIds.addAll(_tree.entries.map((entry) => entry.id));
    _selectedCategoryIds.addAll(
      _tree.categories.map((category) => category.id),
    );
    notifyListeners();
  }

  void selectNone() {
    _selectedEntryIds.clear();
    _selectedCategoryIds.clear();
    notifyListeners();
  }

  void _applyCategoryBranch(String categoryId, bool selected) {
    if (selected) {
      _selectedCategoryIds.add(categoryId);
    } else {
      _selectedCategoryIds.remove(categoryId);
    }
    for (final child in _tree.childCategoriesOf(categoryId)) {
      if (selected) {
        _selectedCategoryIds.add(child.id);
      } else {
        _selectedCategoryIds.remove(child.id);
      }
    }
    _applyEntries(_tree.entriesOf(categoryId), selected);
  }

  void _applyEntries(List<LibraryEntryNode<Object?>> entries, bool selected) {
    for (final entry in entries) {
      if (selected) {
        _selectedEntryIds.add(entry.id);
      } else {
        _selectedEntryIds.remove(entry.id);
      }
    }
  }
}
