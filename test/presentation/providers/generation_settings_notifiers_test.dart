import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_settings_notifiers.dart';

void main() {
  group('PromptWeightScrollSettings', () {
    test('defaults to enabled when storage has no value', () {
      final storage = _MemoryLocalStorageService();
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(container.read(promptWeightScrollSettingsProvider), isTrue);
    });

    test('restores and persists the selected value', () async {
      final storage = _MemoryLocalStorageService(
        initialValues: {StorageKeys.enablePromptWeightScroll: false},
      );
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(container.read(promptWeightScrollSettingsProvider), isFalse);

      await container
          .read(promptWeightScrollSettingsProvider.notifier)
          .set(true);

      expect(container.read(promptWeightScrollSettingsProvider), isTrue);
      expect(storage.values[StorageKeys.enablePromptWeightScroll], isTrue);
    });

    test('rolls back and reports persistence failures to the caller', () async {
      final failure = StateError('settings write failed');
      final storage = _MemoryLocalStorageService(writeError: failure);
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      );
      addTearDown(container.dispose);

      expect(container.read(promptWeightScrollSettingsProvider), isTrue);

      await expectLater(
        container.read(promptWeightScrollSettingsProvider.notifier).set(false),
        throwsA(same(failure)),
      );

      expect(container.read(promptWeightScrollSettingsProvider), isTrue);
      expect(storage.values, isEmpty);
    });
  });
}

class _MemoryLocalStorageService extends LocalStorageService {
  _MemoryLocalStorageService({
    Map<String, Object?> initialValues = const {},
    this.writeError,
  }) : values = Map<String, Object?>.from(initialValues);

  final Map<String, Object?> values;
  final Object? writeError;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return values.containsKey(key) ? values[key] as T? : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    if (writeError case final error?) {
      throw error;
    }
    values[key] = value;
  }
}
