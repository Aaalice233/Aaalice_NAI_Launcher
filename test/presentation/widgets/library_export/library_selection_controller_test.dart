import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/library_export/library_selection_controller.dart';

void main() {
  late LibrarySelectionController controller;

  setUp(() {
    controller = LibrarySelectionController(tree: _buildTree());
    addTearDown(controller.dispose);
  });

  test('初始全选条目与分类，并展开根分类和未分类', () {
    expect(controller.selectedEntryIds, {'e-root', 'e-child', 'e-free'});
    expect(controller.selectedCategoryIds, {'root', 'child', 'empty'});
    expect(controller.expandedCategoryIds, {
      'root',
      'empty',
      LibrarySelectionController.uncategorizedCategoryId,
    });
    expect(controller.isEverythingSelected, isTrue);
    expect(controller.isNothingSelected, isFalse);
    expect(controller.selectedCount, 6);
  });

  test('取消分类只级联到直接子分类与直接条目', () {
    controller.toggleCategoryBranch('root');

    expect(controller.isCategorySelected('root'), isFalse);
    expect(controller.isCategorySelected('child'), isFalse);
    expect(controller.isEntrySelected('e-root'), isFalse);
    expect(controller.isEntrySelected('e-child'), isTrue);
    expect(controller.categoryCheckboxValue('root'), isFalse);
    expect(controller.categoryCheckboxValue('child'), isNull);
  });

  test('重新选中分类同样只覆盖直接子项', () {
    controller.selectNone();
    controller.toggleCategoryBranch('root');

    expect(controller.selectedCategoryIds, {'root', 'child'});
    expect(controller.selectedEntryIds, {'e-root'});
    expect(controller.categoryCheckboxValue('root'), isTrue);
  });

  test('部分选中时分类呈现第三态', () {
    controller.setEntrySelected('e-root', false);

    expect(controller.categoryCheckboxValue('root'), isNull);
    expect(controller.selectedChildCount('root'), 1);
    expect(controller.childCount('root'), 2);
  });

  test('无子项的分类即使自身选中也不显示为全选', () {
    expect(controller.isCategorySelected('empty'), isTrue);
    expect(controller.categoryCheckboxValue('empty'), isFalse);
    expect(controller.childCount('empty'), 0);
  });

  test('单个分类可以在不级联的情况下改变选中状态', () {
    controller.setCategorySelected('root', false);

    expect(controller.isCategorySelected('root'), isFalse);
    expect(controller.isCategorySelected('child'), isTrue);
    expect(controller.isEntrySelected('e-root'), isTrue);
    expect(controller.categoryCheckboxValue('root'), isNull);
  });

  test('未分类分组整体切换并维持三态', () {
    expect(controller.uncategorizedCheckboxValue, isTrue);

    controller.toggleUncategorized();
    expect(controller.isEntrySelected('e-free'), isFalse);
    expect(controller.uncategorizedCheckboxValue, isFalse);
    expect(controller.selectedUncategorizedCount, 0);

    controller.toggleUncategorized();
    expect(controller.isEntrySelected('e-free'), isTrue);
    expect(controller.uncategorizedCheckboxValue, isTrue);
  });

  test('展开状态可切换且互不影响', () {
    controller.toggleExpanded('root');
    expect(controller.isExpanded('root'), isFalse);
    expect(controller.isExpanded('empty'), isTrue);

    controller.toggleExpanded('child');
    expect(controller.isExpanded('child'), isTrue);
  });

  test('清空与全选互为逆操作', () {
    controller.selectNone();
    expect(controller.isNothingSelected, isTrue);
    expect(controller.isEverythingSelected, isFalse);
    expect(controller.selectedCount, 0);

    controller.selectAll();
    expect(controller.isEverythingSelected, isTrue);
    expect(controller.selectedEntryIds, {'e-root', 'e-child', 'e-free'});
  });

  test('每次选择变更都通知监听者', () {
    var notifications = 0;
    void listener() => notifications++;
    controller.addListener(listener);
    addTearDown(() => controller.removeListener(listener));

    controller.toggleEntry('e-root');
    controller.toggleCategoryBranch('root');
    controller.toggleExpanded('root');
    controller.selectNone();

    expect(notifications, 4);
  });

  test('选择集合对外只读', () {
    expect(
      () => controller.selectedEntryIds.add('外部写入'),
      throwsUnsupportedError,
    );
  });

  test('树按传入顺序保留同级次序并按父级归组', () {
    final tree = _buildTree();

    expect(tree.rootCategories.map((c) => c.id), ['root', 'empty']);
    expect(tree.childCategoriesOf('root').map((c) => c.id), ['child']);
    expect(tree.childCategoriesOf('child'), isEmpty);
    expect(tree.entriesOf('root').map((e) => e.id), ['e-root']);
    expect(tree.uncategorizedEntries.map((e) => e.id), ['e-free']);
  });
}

LibrarySelectionTree<String> _buildTree() {
  return LibrarySelectionTree<String>(
    categories: const [
      LibraryCategoryNode(id: 'root', displayName: '根分类'),
      LibraryCategoryNode(id: 'child', displayName: '子分类', parentId: 'root'),
      LibraryCategoryNode(id: 'empty', displayName: '空分类'),
    ],
    entries: const [
      LibraryEntryNode<String>(
        id: 'e-root',
        value: '根条目',
        categoryId: 'root',
      ),
      LibraryEntryNode<String>(
        id: 'e-child',
        value: '子条目',
        categoryId: 'child',
      ),
      LibraryEntryNode<String>(id: 'e-free', value: '未分类条目'),
    ],
  );
}
