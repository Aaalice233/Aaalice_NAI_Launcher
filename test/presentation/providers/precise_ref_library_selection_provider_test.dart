import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/precise_ref_library_selection_provider.dart';

void main() {
  test('精准参考选择状态支持进入、跨页追加、当前页取消与退出', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      preciseRefLibrarySelectionNotifierProvider.notifier,
    );

    notifier.enterAndSelect('page-1');
    notifier.selectAll(['page-2', 'page-3']);
    expect(
      container.read(preciseRefLibrarySelectionNotifierProvider).selectedIds,
      {'page-1', 'page-2', 'page-3'},
    );

    notifier.deselectAll(['page-2', 'page-3']);
    expect(
      container.read(preciseRefLibrarySelectionNotifierProvider).selectedIds,
      {'page-1'},
    );

    notifier.exit();
    final state = container.read(preciseRefLibrarySelectionNotifierProvider);
    expect(state.isActive, isFalse);
    expect(state.selectedIds, isEmpty);
  });
}
