import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync.dart';
import 'package:nai_launcher/presentation/providers/library_sidebar_sort_provider.dart';
import 'package:nai_launcher/presentation/utils/library_sidebar_sort.dart';

void main() {
  ProviderContainer containerFor(_Storage storage) {
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'defaults and saved preferences stay independent and survive recreation',
    () async {
      final storage = _Storage();
      final container = containerFor(storage);
      for (final section in LibrarySidebarSection.values) {
        expect(
          container.read(librarySidebarSortProvider(section)).sort,
          section.defaultSort,
        );
      }
      await container
          .read(
            librarySidebarSortProvider(LibrarySidebarSection.folders).notifier,
          )
          .setSort(LibrarySidebarSort.nameAscending);
      await container
          .read(
            librarySidebarSortProvider(
              LibrarySidebarSection.vibeCategories,
            ).notifier,
          )
          .setSort(LibrarySidebarSort.countDescending);
      expect(
        container
            .read(librarySidebarSortProvider(LibrarySidebarSection.albums))
            .sort,
        LibrarySidebarSort.original,
      );
      final reopened = containerFor(storage);
      expect(
        reopened
            .read(librarySidebarSortProvider(LibrarySidebarSection.folders))
            .sort,
        LibrarySidebarSort.nameAscending,
      );
      expect(
        reopened
            .read(
              librarySidebarSortProvider(LibrarySidebarSection.vibeCategories),
            )
            .sort,
        LibrarySidebarSort.countDescending,
      );
      expect(storage.values.length, 2);
    },
  );

  test(
    'a failed write reports its error and restores the previous selection',
    () async {
      final storage = _Storage()..failure = StateError('disk full');
      final container = containerFor(storage);
      final provider = librarySidebarSortProvider(
        LibrarySidebarSection.folders,
      );
      await expectLater(
        container
            .read(provider.notifier)
            .setSort(LibrarySidebarSort.countAscending),
        throwsStateError,
      );
      expect(container.read(provider).sort, LibrarySidebarSort.nameDescending);
      expect(container.read(provider).isSaving, isFalse);
      expect(storage.values, isEmpty);
    },
  );

  test(
    'pending writes expose disabled state and do not lose the saved mode',
    () async {
      final gate = Completer<void>();
      final storage = _Storage()..gate = gate.future;
      final container = containerFor(storage);
      final provider = librarySidebarSortProvider(LibrarySidebarSection.albums);
      final write = container
          .read(provider.notifier)
          .setSort(LibrarySidebarSort.countDescending);
      expect(container.read(provider).isSaving, isTrue);
      expect(container.read(provider).sort, LibrarySidebarSort.original);
      gate.complete();
      await write;
      expect(container.read(provider).isSaving, isFalse);
      expect(container.read(provider).sort, LibrarySidebarSort.countDescending);
    },
  );

  test(
    'all sidebar sort keys are excluded from cloud export and restore',
    () async {
      final storage = _Storage();
      final adapter = SettingsCloudSyncAdapter(storage);
      for (final section in LibrarySidebarSection.values) {
        storage.values[section.storageKey] =
            LibrarySidebarSort.countDescending.name;
        expect(adapter.exportedKeys, isNot(contains(section.storageKey)));
        expect(
          () => adapter.validateRecord(
            PortableSyncRecord(
              adapterId: adapter.id,
              id: section.storageKey,
              kind: 'setting',
              data: {'key': section.storageKey, 'value': 'nameAscending'},
            ),
          ),
          throwsA(isA<CloudSyncPreflightException>()),
        );
      }
      expect(await adapter.exportRecords().toList(), isEmpty);
    },
  );

  test('manual move commits order and persists original mode', () async {
    final storage = _Storage();
    final container = containerFor(storage);
    final provider = librarySidebarSortProvider(LibrarySidebarSection.folders);
    expect(
      await container.read(provider.notifier).applyManualMove((sort) async {
        expect(sort, LibrarySidebarSort.nameDescending);
        return true;
      }),
      isTrue,
    );
    expect(container.read(provider).sort, LibrarySidebarSort.original);
    expect(
      containerFor(storage).read(provider).sort,
      LibrarySidebarSort.original,
    );
  });

  test('unchanged and failed moves preserve the automatic mode', () async {
    final storage = _Storage();
    final container = containerFor(storage);
    final provider = librarySidebarSortProvider(LibrarySidebarSection.folders);
    final owner = container.read(provider.notifier);
    expect(await owner.applyManualMove((_) async => false), isFalse);
    await expectLater(
      owner.applyManualMove((_) async => throw StateError('move failed')),
      throwsStateError,
    );
    expect(container.read(provider).sort, LibrarySidebarSort.nameDescending);
    expect(container.read(provider).isSaving, isFalse);
    expect(storage.values, isEmpty);
  });

  test(
    'preference failure reports committed move without hiding its order',
    () async {
      final cause = StateError('preference disk full');
      final storage = _Storage()..failure = cause;
      final container = containerFor(storage);
      final provider = librarySidebarSortProvider(
        LibrarySidebarSection.folders,
      );
      await expectLater(
        container.read(provider.notifier).applyManualMove((_) async => true),
        throwsA(
          isA<SidebarSortPreferenceSaveException>().having(
            (error) => error.cause,
            'cause',
            same(cause),
          ),
        ),
      );
      expect(container.read(provider).sort, LibrarySidebarSort.original);
      expect(container.read(provider).isSaving, isFalse);
      expect(storage.values, isEmpty);
    },
  );
}

class _Storage extends LocalStorageService {
  final values = <String, Object?>{};
  Object? failure;
  Future<void>? gate;
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] ?? defaultValue) as T?;
  @override
  Future<void> setSetting<T>(String key, T value) async {
    if (gate != null) await gate;
    if (failure != null) throw failure!;
    values[key] = value;
  }
}
