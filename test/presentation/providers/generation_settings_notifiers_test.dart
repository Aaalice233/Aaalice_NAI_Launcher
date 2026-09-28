import 'dart:async';

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

    test(
      'serializes overlapping writes and ignores a stale failure rollback',
      () async {
        final storage = _ControlledLocalStorageService(initialValue: true);
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(
          promptWeightScrollSettingsProvider.notifier,
        );

        final first = notifier.set(false);
        final second = notifier.set(true);
        final third = notifier.set(false);

        expect(container.read(promptWeightScrollSettingsProvider), isFalse);
        await _flushAsyncWork();
        expect(storage.writes, hasLength(1));

        final firstFailure = StateError('first write failed');
        final firstResult = expectLater(first, throwsA(same(firstFailure)));
        storage.failWrite(0, firstFailure);
        await firstResult;
        await _flushAsyncWork();

        expect(container.read(promptWeightScrollSettingsProvider), isFalse);
        expect(storage.writes, hasLength(2));

        storage.succeedWrite(1);
        await second;
        await _flushAsyncWork();
        expect(storage.writes, hasLength(3));

        storage.succeedWrite(2);
        await third;

        expect(container.read(promptWeightScrollSettingsProvider), isFalse);
        expect(storage.values[StorageKeys.enablePromptWeightScroll], isFalse);
      },
    );

    test(
      'overlapping failed writes restore the last confirmed value',
      () async {
        final storage = _ControlledLocalStorageService(initialValue: true);
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(
          promptWeightScrollSettingsProvider.notifier,
        );

        final first = notifier.set(false);
        final second = notifier.set(true);
        final third = notifier.set(false);
        final failures = [
          StateError('first write failed'),
          StateError('second write failed'),
          StateError('third write failed'),
        ];

        expect(container.read(promptWeightScrollSettingsProvider), isFalse);
        await _flushAsyncWork();
        expect(storage.writes, hasLength(1));
        final results = [
          expectLater(first, throwsA(same(failures[0]))),
          expectLater(second, throwsA(same(failures[1]))),
          expectLater(third, throwsA(same(failures[2]))),
        ];

        for (var index = 0; index < failures.length; index++) {
          storage.failWrite(index, failures[index]);
          await results[index];
          await _flushAsyncWork();
          if (index < failures.length - 1) {
            expect(storage.writes, hasLength(index + 2));
            expect(container.read(promptWeightScrollSettingsProvider), isFalse);
          }
        }

        expect(container.read(promptWeightScrollSettingsProvider), isTrue);
        expect(storage.values[StorageKeys.enablePromptWeightScroll], isTrue);
      },
    );

    test(
      'latest failure restores a value confirmed by an earlier write',
      () async {
        final storage = _ControlledLocalStorageService(initialValue: true);
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(
          promptWeightScrollSettingsProvider.notifier,
        );

        final first = notifier.set(false);
        final second = notifier.set(true);

        expect(container.read(promptWeightScrollSettingsProvider), isTrue);
        await _flushAsyncWork();
        expect(storage.writes, hasLength(1));

        storage.succeedWrite(0);
        await first;
        await _flushAsyncWork();
        expect(storage.writes, hasLength(2));
        expect(container.read(promptWeightScrollSettingsProvider), isTrue);

        final failure = StateError('latest write failed');
        final secondResult = expectLater(second, throwsA(same(failure)));
        storage.failWrite(1, failure);
        await secondResult;

        expect(container.read(promptWeightScrollSettingsProvider), isFalse);
        expect(storage.values[StorageKeys.enablePromptWeightScroll], isFalse);
      },
    );
  });
}

Future<void> _flushAsyncWork() => Future<void>.delayed(Duration.zero);

class _ControlledLocalStorageService extends LocalStorageService {
  _ControlledLocalStorageService({required bool initialValue})
    : values = {StorageKeys.enablePromptWeightScroll: initialValue};

  final Map<String, Object?> values;
  final List<_ControlledWrite> writes = [];

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return values.containsKey(key) ? values[key] as T? : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    final write = _ControlledWrite();
    writes.add(write);
    await write.completer.future;
    values[key] = value;
  }

  void succeedWrite(int index) {
    writes[index].completer.complete();
  }

  void failWrite(int index, Object error) {
    writes[index].completer.completeError(error);
  }
}

class _ControlledWrite {
  final Completer<void> completer = Completer<void>();
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
