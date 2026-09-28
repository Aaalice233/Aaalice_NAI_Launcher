import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/history_click_behavior_provider.dart';

void main() {
  group('HistoryClickBehaviorNotifier', () {
    test('missing storage value defaults to classic open detail', () {
      final storage = LocalStorageService();
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(storage.getHistoryClickBehavior(), 'open_detail');
      expect(
        container.read(historyClickBehaviorNotifierProvider),
        HistoryClickBehavior.openDetail,
      );
    });

    test('unknown storage value never creates a linked state', () {
      final storage = _FakeStorage()..behavior = 'unknown';
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(historyClickBehaviorNotifierProvider),
        HistoryClickBehavior.openDetail,
      );
    });

    test('setBehavior persists and updates state', () async {
      final storage = _FakeStorage();
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      await container
          .read(historyClickBehaviorNotifierProvider.notifier)
          .setBehavior(HistoryClickBehavior.selectPreview);

      expect(
        container.read(historyClickBehaviorNotifierProvider),
        HistoryClickBehavior.selectPreview,
      );
      expect(storage.behavior, 'select_preview');
    });
  });
}

class _FakeStorage extends LocalStorageService {
  String behavior = 'open_detail';

  @override
  String getHistoryClickBehavior() => behavior;

  @override
  Future<void> setHistoryClickBehavior(String value) async {
    behavior = value;
  }
}
