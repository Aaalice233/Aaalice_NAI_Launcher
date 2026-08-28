import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_selection_provider.dart';

void main() {
  test('取消当前页全选会保留其他页的选择', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      vibeLibrarySelectionNotifierProvider.notifier,
    );

    notifier.selectAll(['page-1-a', 'page-1-b', 'page-2-a']);
    notifier.deselectAll(['page-1-a', 'page-1-b']);

    expect(container.read(vibeLibrarySelectionNotifierProvider).selectedIds, {
      'page-2-a',
    });
  });
}
