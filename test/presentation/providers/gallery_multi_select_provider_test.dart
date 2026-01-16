import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/presentation/providers/gallery_multi_select_provider.dart';

void main() {
  group('GalleryMultiSelectProvider', () {
    test('初始状态 selectedIds 应为空', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(multiSelectNotifierProvider);
      expect(state.selectedPostIds, isEmpty);
    });

    test('toggleSelection 应添加选中', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(multiSelectNotifierProvider.notifier);
      notifier.toggleSelection(123);

      final state = container.read(multiSelectNotifierProvider);
      expect(state.selectedPostIds, contains(123));
    });

    test('toggleSelection 应移除已选中的', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(multiSelectNotifierProvider.notifier);
      notifier.toggleSelection(123);
      notifier.toggleSelection(123);

      final state = container.read(multiSelectNotifierProvider);
      expect(state.selectedPostIds, isNot(contains(123)));
    });

    test('clearSelection 应清空所有选中', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(multiSelectNotifierProvider.notifier);
      notifier.toggleSelection(1);
      notifier.toggleSelection(2);
      notifier.clearSelection();

      final state = container.read(multiSelectNotifierProvider);
      expect(state.selectedPostIds, isEmpty);
    });

    test('selectAll 应选中所有', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(multiSelectNotifierProvider.notifier);
      notifier.selectAll([1, 2, 3]);

      final state = container.read(multiSelectNotifierProvider);
      expect(state.selectedPostIds, equals({1, 2, 3}));
      expect(state.isSelectionMode, isTrue);
    });

    test('isSelectionMode 应反映选择状态', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(multiSelectNotifierProvider).isSelectionMode, isFalse);

      final notifier = container.read(multiSelectNotifierProvider.notifier);
      notifier.toggleSelection(1);

      expect(container.read(multiSelectNotifierProvider).isSelectionMode, isTrue);
    });
  });
}
