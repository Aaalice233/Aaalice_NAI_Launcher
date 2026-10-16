import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_selection_provider.dart';

void main() {
  test(
    'filtered/current entries are immutable projections, not stored state',
    () {
      final state = VibeLibraryState(
        entries: [
          _entry('old', 'Old', DateTime(2026, 4, 13)),
          _entry('match', 'Search Match', DateTime(2026, 4, 14)),
          _entry('new', 'New', DateTime(2026, 4, 15)),
        ],
        searchQuery: 'search',
        pageSize: 1,
      );

      expect(state.filteredEntries.map((entry) => entry.id), ['match']);
      expect(state.currentEntries.map((entry) => entry.id), ['match']);
      expect(
        () => state.filteredEntries.add(_entry('x', 'X', DateTime.now())),
        throwsUnsupportedError,
      );

      final changed = state.copyWith(searchQuery: '', currentPage: 1);
      expect(changed.filteredEntries.map((entry) => entry.id), [
        'new',
        'match',
        'old',
      ]);
      expect(changed.currentEntries.single.id, 'match');
      expect(state.filteredEntries.map((entry) => entry.id), ['match']);
    },
  );

  test('切换到分类后再清空分类过滤，应恢复显示全部 Vibe', () async {
    final storage = _CategorizedStorageService();
    final container = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(vibeLibraryNotifierProvider.notifier);

    await notifier.loadFromCache(showLoading: false);
    expect(
      container.read(vibeLibraryNotifierProvider).currentEntries,
      hasLength(2),
    );

    await notifier.setCategoryFilter('cat-a');
    expect(
      container
          .read(vibeLibraryNotifierProvider)
          .currentEntries
          .map((entry) => entry.id),
      ['a'],
    );

    await notifier.clearCategoryFilter();
    expect(
      container.read(vibeLibraryNotifierProvider).selectedCategoryId,
      isNull,
    );
    expect(
      container
          .read(vibeLibraryNotifierProvider)
          .currentEntries
          .map((entry) => entry.id),
      ['b', 'a'],
      reason: '切回全部 Vibe 时必须真正清掉分类过滤，而不是继续保留旧分类',
    );
  });

  test('loadFromCache 会并行读取 entries 和 categories', () async {
    final storage = _ParallelProbeStorageService();
    final container = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final future = container
        .read(vibeLibraryNotifierProvider.notifier)
        .loadFromCache(showLoading: false);

    await storage.entriesStarted.future;

    expect(
      storage.categoriesStarted.isCompleted,
      isTrue,
      reason: 'categories 应在 entries 完成前就开始加载，避免顺序阻塞首屏',
    );

    storage.allowEntries.complete();
    storage.allowCategories.complete();

    await future;
  });

  test('加载失败会进入可重试错误态，并与空库区分', () async {
    final storage = _FlakyLoadStorageService();
    final container = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(vibeLibraryNotifierProvider.notifier);

    await notifier.loadFromCache();

    final failed = container.read(vibeLibraryNotifierProvider);
    expect(failed.entries, isEmpty);
    expect(failed.error, contains('hive read failed'));
    expect(failed.isInitializing, isFalse);

    await notifier.loadFromCache();

    final retried = container.read(vibeLibraryNotifierProvider);
    expect(retried.error, isNull);
    expect(retried.entries, hasLength(1));
  });

  test('entry 写异常返回 null 并记录错误状态', () async {
    final container = ProviderContainer(
      overrides: [
        vibeLibraryStorageServiceProvider.overrideWithValue(
          _FailingWriteStorageService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(vibeLibraryNotifierProvider.notifier)
        .saveEntry(_entry('write', 'Write', DateTime(2026)));

    expect(result, isNull);
    expect(
      container.read(vibeLibraryNotifierProvider).error,
      contains('disk write failed'),
    );
  });

  test('过滤结果写入和删除后会把 currentPage 校正到最后一个有效页', () async {
    final storage = _MutableStorageService();
    final container = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(vibeLibraryNotifierProvider.notifier);

    await notifier.loadFromCache();
    await notifier.setPageSize(1);
    await notifier.setFavoritesOnly(true);
    await notifier.loadPage(2);
    final lastId = container
        .read(vibeLibraryNotifierProvider)
        .currentEntries
        .single
        .id;

    await notifier.toggleFavorite(lastId);

    var state = container.read(vibeLibraryNotifierProvider);
    expect(state.currentPage, 1);
    expect(state.currentEntries, hasLength(1));

    await notifier.deleteEntry(state.currentEntries.single.id);

    state = container.read(vibeLibraryNotifierProvider);
    expect(state.currentPage, 0);
    expect(state.currentEntries, hasLength(1));
  });

  test('批量操作返回实际成功数，同时按已处理数报告进度', () async {
    final storage = _PartialBulkStorageService();
    final container = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(vibeLibraryNotifierProvider.notifier);
    await notifier.loadFromCache(showLoading: false);

    final moveProgress = <int>[];
    expect(
      await notifier.bulkMoveToCategory(
        ['ok', 'failed'],
        'target',
        onProgress: (completed, _) => moveProgress.add(completed),
      ),
      1,
    );
    expect(moveProgress, [1, 2]);

    final deleteProgress = <int>[];
    expect(
      await notifier.bulkDeleteEntries([
        'ok',
        'failed',
      ], onProgress: (completed, _) => deleteProgress.add(completed)),
      1,
    );
    expect(deleteProgress, [1, 2]);
  });

  test('批量修改 encoding model 按项隔离异常并返回准确计数', () async {
    final storage = _EncodingModelBulkStorageService();
    final container = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(vibeLibraryNotifierProvider.notifier)
        .bulkUpdateEncodingModel([
          'throws',
          'updated',
          'not-updated',
        ], 'nai-diffusion-4-5-full');

    expect(storage.processedIds, ['throws', 'updated', 'not-updated']);
    expect(result.successCount, 1);
    expect(result.errors, hasLength(2));
    expect(result.errors.first.itemName, 'throws');
    expect(result.errors.first.details, contains('encoding update failed'));
    expect(result.errors.last.itemName, 'not-updated');
  });

  test('loadFromCache 不应暴露 entries 已加载但 currentEntries 仍为空的中间态', () async {
    final storage = _LoadedStorageService();
    final container = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final states = <VibeLibraryState>[];
    final sub = container.listen(
      vibeLibraryNotifierProvider,
      (previous, next) => states.add(next),
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(vibeLibraryNotifierProvider.notifier).loadFromCache();

    final hasTransientEmptyPage = states.any(
      (state) =>
          state.entries.isNotEmpty &&
          state.currentEntries.isEmpty &&
          !state.isLoading &&
          !state.isInitializing,
    );

    expect(
      hasTransientEmptyPage,
      isFalse,
      reason: '首屏不应先经历“数据已到但当前页为空”的额外状态切换，否则会放大首次打开卡顿',
    );
  });

  group('派生列表按输入记忆', () {
    final entries = _derivedFixture();

    test('进度、加载、错误和分类元数据变化复用同一份筛选结果与当前页', () {
      final base = VibeLibraryState(
        entries: entries,
        pageSize: 10,
        currentPage: 1,
      );
      final filtered = base.filteredEntries;
      final page = base.currentEntries;

      final unrelatedChanges = {
        'same state': base,
        'isLoading': base.copyWith(isLoading: true),
        'isInitializing': base.copyWith(isInitializing: true),
        'bulk progress': base.copyWith(
          isBulkOperating: true,
          bulkOperationProgress: 0.5,
          bulkOperationType: VibeLibraryBulkOperationType.delete,
        ),
        'error': base.copyWith(error: 'boom'),
        'categories': base.copyWith(
          categories: [
            VibeLibraryCategory(
              id: 'cat',
              name: 'Cat',
              createdAt: DateTime(2026),
            ),
          ],
        ),
      };
      for (final MapEntry(key: change, value: state)
          in unrelatedChanges.entries) {
        expect(state.filteredEntries, same(filtered), reason: change);
        expect(state.currentEntries, same(page), reason: change);
        expect(state.totalPages, 5, reason: change);
        expect(state.filteredCount, entries.length, reason: change);
      }
    });

    test('翻页和改页大小只重新切片，不重新筛选排序', () {
      final base = VibeLibraryState(entries: entries, pageSize: 10);
      final filtered = base.filteredEntries;

      final third = base.copyWith(currentPage: 2);
      expect(third.filteredEntries, same(filtered));
      expect(
        third.currentEntries.map((entry) => entry.id),
        filtered.sublist(20, 30).map((entry) => entry.id),
      );

      final resized = base.copyWith(pageSize: 20);
      expect(resized.filteredEntries, same(filtered));
      expect(resized.totalPages, 3);
      expect(resized.currentEntries, hasLength(20));
    });

    test('筛选、排序输入或 entries 变化时重新计算', () {
      final base = VibeLibraryState(entries: entries);
      final filtered = base.filteredEntries;

      final inputChanges = {
        'searchQuery': base.copyWith(searchQuery: 'MIXED'),
        'selectedCategoryId': base.copyWith(selectedCategoryId: 'cat'),
        'favoritesOnly': base.copyWith(favoritesOnly: true),
        'sortOrder': base.copyWith(sortOrder: VibeLibrarySortOrder.name),
        'sortDescending': base.copyWith(sortDescending: false),
        'entries': base.copyWith(entries: List.of(entries)),
      };
      for (final MapEntry(key: change, value: state) in inputChanges.entries) {
        expect(state.filteredEntries, isNot(same(filtered)), reason: change);
      }
    });

    test('搜索、分类与收藏条件同时生效，升序是降序的逆序', () {
      final state = VibeLibraryState(
        entries: [
          _entry(
            'hit-old',
            'Mixed old',
            DateTime(2026, 1, 1),
            categoryId: 'cat',
            isFavorite: true,
          ),
          _entry(
            'hit-new',
            'mixed new',
            DateTime(2026, 1, 3),
            categoryId: 'cat',
            isFavorite: true,
          ),
          _entry(
            'not-favorite',
            'Mixed plain',
            DateTime(2026, 1, 2),
            categoryId: 'cat',
          ),
          _entry(
            'other-category',
            'Mixed elsewhere',
            DateTime(2026, 1, 4),
            isFavorite: true,
          ),
          _entry(
            'no-match',
            'Zeta',
            DateTime(2026, 1, 5),
            categoryId: 'cat',
            isFavorite: true,
          ),
        ],
        searchQuery: 'MIXED',
        selectedCategoryId: 'cat',
        favoritesOnly: true,
      );

      expect(state.filteredEntries.map((entry) => entry.id), [
        'hit-new',
        'hit-old',
      ]);
      expect(
        state
            .copyWith(sortDescending: false)
            .filteredEntries
            .map((entry) => entry.id),
        ['hit-old', 'hit-new'],
      );
    });

    test('分页边界：空库、整页、末页不满、越界与负页码', () {
      const empty = VibeLibraryState(pageSize: 10);
      expect(empty.filteredCount, 0);
      expect(empty.totalPages, 0);
      expect(empty.currentEntries, isEmpty);

      final twenty = VibeLibraryState(
        entries: entries.take(20).toList(),
        pageSize: 10,
      );
      expect(twenty.totalPages, 2);
      expect(twenty.copyWith(currentPage: 1).currentEntries, hasLength(10));
      expect(twenty.copyWith(currentPage: 2).currentEntries, isEmpty);

      final partial = VibeLibraryState(entries: entries, pageSize: 10);
      expect(partial.totalPages, 5);
      final last = partial.copyWith(currentPage: 4);
      expect(last.currentEntries, hasLength(entries.length - 40));
      expect(
        last.currentEntries.map((entry) => entry.id),
        partial.filteredEntries.skip(40).map((entry) => entry.id),
      );
      expect(partial.copyWith(currentPage: 5).currentEntries, isEmpty);
      expect(partial.copyWith(currentPage: -1).currentEntries, isEmpty);
      expect(
        () => last.currentEntries.add(entries.first),
        throwsUnsupportedError,
      );
    });

    test('只改变选择状态时库状态与派生列表都保持原实例', () async {
      final container = ProviderContainer(
        overrides: [
          vibeLibraryStorageServiceProvider.overrideWithValue(
            _FixedEntriesStorageService(entries),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(vibeLibraryNotifierProvider.notifier)
          .loadFromCache(showLoading: false);
      final state = container.read(vibeLibraryNotifierProvider);
      final filtered = state.filteredEntries;
      final page = state.currentEntries;

      final selection = container.read(
        vibeLibrarySelectionNotifierProvider.notifier,
      );
      selection.enterAndSelect(page.first.id);
      selection.selectAll(page.map((entry) => entry.id));
      selection.exit();

      final after = container.read(vibeLibraryNotifierProvider);
      expect(after, same(state));
      expect(after.filteredEntries, same(filtered));
      expect(after.currentEntries, same(page));
    });

    test('批量操作的进度状态序列全程复用同一份派生列表', () async {
      final container = ProviderContainer(
        overrides: [
          vibeLibraryStorageServiceProvider.overrideWithValue(
            _FixedEntriesStorageService(entries),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(vibeLibraryNotifierProvider.notifier);
      await notifier.loadFromCache(showLoading: false);
      final filtered = container
          .read(vibeLibraryNotifierProvider)
          .filteredEntries;
      final emitted = <VibeLibraryState>[];
      final subscription = container.listen(
        vibeLibraryNotifierProvider,
        (_, next) => emitted.add(next),
      );
      addTearDown(subscription.close);

      final deleted = await notifier.bulkDeleteEntries(
        entries.take(12).map((entry) => entry.id).toList(),
      );

      expect(deleted, 0);
      expect(emitted.length, greaterThan(2));
      expect(emitted.any((state) => state.isBulkOperating), isTrue);
      for (final state in emitted) {
        expect(state.filteredEntries, same(filtered));
      }
    });
  });
}

List<VibeLibraryEntry> _derivedFixture() {
  const names = ['beta', 'Alpha', 'alpha', 'Mixed Case', 'MIXED', 'zeta', ''];
  return [
    for (var index = 0; index < 45; index++)
      VibeLibraryEntry(
        id: 'derived-$index',
        name: names[index % names.length],
        vibeDisplayName: 'Display ${44 - index}',
        vibeEncoding: 'enc-$index',
        sourceTypeIndex: VibeSourceType.naiv4vibe.index,
        categoryId: index % 3 == 0 ? 'cat' : null,
        tags: index % 4 == 0 ? const ['mixed-tag'] : const [],
        isFavorite: index.isEven,
        usedCount: index % 5,
        lastUsedAt: index % 6 == 0 ? null : DateTime(2026, 1, 1, index % 7),
        createdAt: DateTime(2026, 1, 1).add(Duration(minutes: index * 7 % 45)),
      ),
  ];
}

class _FixedEntriesStorageService extends VibeLibraryStorageService {
  _FixedEntriesStorageService(this.entries);

  final List<VibeLibraryEntry> entries;

  @override
  Future<List<VibeLibraryEntry>> getDisplayEntries() async => List.of(entries);

  @override
  Future<List<VibeLibraryCategory>> getAllCategories() async => const [];

  @override
  Future<bool> deleteEntry(String id) async => false;
}

VibeLibraryEntry _entry(
  String id,
  String name,
  DateTime createdAt, {
  String? categoryId,
  bool isFavorite = false,
}) {
  return VibeLibraryEntry(
    id: id,
    name: name,
    vibeDisplayName: name,
    vibeEncoding: 'enc-$id',
    strength: 0.6,
    infoExtracted: 0.7,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    categoryId: categoryId,
    isFavorite: isFavorite,
    createdAt: createdAt,
  );
}

class _ParallelProbeStorageService extends VibeLibraryStorageService {
  final Completer<void> entriesStarted = Completer<void>();
  final Completer<void> categoriesStarted = Completer<void>();
  final Completer<void> allowEntries = Completer<void>();
  final Completer<void> allowCategories = Completer<void>();

  @override
  Future<List<VibeLibraryEntry>> getDisplayEntries() async {
    if (!entriesStarted.isCompleted) {
      entriesStarted.complete();
    }
    await allowEntries.future;
    return const [];
  }

  @override
  Future<List<VibeLibraryCategory>> getAllCategories() async {
    if (!categoriesStarted.isCompleted) {
      categoriesStarted.complete();
    }
    await allowCategories.future;
    return const [];
  }
}

class _FlakyLoadStorageService extends VibeLibraryStorageService {
  var attempts = 0;

  @override
  Future<List<VibeLibraryEntry>> getDisplayEntries() async {
    attempts++;
    if (attempts == 1) throw StateError('hive read failed');
    return [_entry('loaded', 'Loaded', DateTime(2026))];
  }

  @override
  Future<List<VibeLibraryCategory>> getAllCategories() async => const [];
}

class _FailingWriteStorageService extends VibeLibraryStorageService {
  @override
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) {
    throw StateError('disk write failed');
  }
}

class _MutableStorageService extends VibeLibraryStorageService {
  final entries = [
    _entry('a', 'Alpha', DateTime(2026, 1, 1)).copyWith(isFavorite: true),
    _entry('b', 'Beta', DateTime(2026, 1, 2)).copyWith(isFavorite: true),
    _entry('c', 'Gamma', DateTime(2026, 1, 3)).copyWith(isFavorite: true),
  ];

  @override
  Future<List<VibeLibraryEntry>> getDisplayEntries() async => List.of(entries);

  @override
  Future<List<VibeLibraryCategory>> getAllCategories() async => const [];

  @override
  Future<VibeLibraryEntry?> toggleFavorite(String id) async {
    final index = entries.indexWhere((entry) => entry.id == id);
    entries[index] = entries[index].toggleFavorite();
    return entries[index];
  }

  @override
  Future<bool> deleteEntry(String id) async {
    entries.removeWhere((entry) => entry.id == id);
    return true;
  }
}

class _PartialBulkStorageService extends VibeLibraryStorageService {
  final entries = [
    _entry('ok', 'Success', DateTime(2026, 1, 1)),
    _entry('failed', 'Failed', DateTime(2026, 1, 2)),
  ];

  @override
  Future<List<VibeLibraryEntry>> getDisplayEntries() async => List.of(entries);

  @override
  Future<List<VibeLibraryCategory>> getAllCategories() async => const [];

  @override
  Future<VibeLibraryEntry?> updateEntryCategory(
    String id,
    String? categoryId,
  ) async => id == 'ok' ? entries.first.copyWith(categoryId: categoryId) : null;

  @override
  Future<bool> deleteEntry(String id) async => id == 'ok';
}

class _EncodingModelBulkStorageService extends VibeLibraryStorageService {
  final processedIds = <String>[];

  @override
  Future<VibeLibraryEntry?> updateEntryEncodingModel(
    String id,
    String model,
  ) async {
    processedIds.add(id);
    if (id == 'throws') throw StateError('encoding update failed');
    if (id == 'not-updated') return null;
    return _entry(id, id, DateTime(2026)).copyWith(encodingModel: model);
  }

  @override
  Future<List<VibeLibraryEntry>> getDisplayEntries() async => const [];

  @override
  Future<List<VibeLibraryCategory>> getAllCategories() async => const [];
}

class _LoadedStorageService extends VibeLibraryStorageService {
  @override
  Future<List<VibeLibraryEntry>> getDisplayEntries() async => [
    VibeLibraryEntry(
      id: 'a',
      name: 'Alpha',
      vibeDisplayName: 'Alpha',
      vibeEncoding: 'enc-a',
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 14),
    ),
    VibeLibraryEntry(
      id: 'b',
      name: 'Beta',
      vibeDisplayName: 'Beta',
      vibeEncoding: 'enc-b',
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 14),
    ),
  ];

  @override
  Future<List<VibeLibraryCategory>> getAllCategories() async => const [];
}

class _CategorizedStorageService extends VibeLibraryStorageService {
  @override
  Future<List<VibeLibraryEntry>> getDisplayEntries() async => [
    VibeLibraryEntry(
      id: 'a',
      name: 'Alpha',
      vibeDisplayName: 'Alpha',
      vibeEncoding: 'enc-a',
      strength: 0.6,
      infoExtracted: 0.7,
      categoryId: 'cat-a',
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 14),
    ),
    VibeLibraryEntry(
      id: 'b',
      name: 'Beta',
      vibeDisplayName: 'Beta',
      vibeEncoding: 'enc-b',
      strength: 0.6,
      infoExtracted: 0.7,
      sourceTypeIndex: VibeSourceType.naiv4vibe.index,
      createdAt: DateTime(2026, 4, 14, 0, 0, 1),
    ),
  ];

  @override
  Future<List<VibeLibraryCategory>> getAllCategories() async => [
    VibeLibraryCategory(
      id: 'cat-a',
      name: '分类 A',
      createdAt: DateTime(2026, 4, 14),
    ),
  ];
}
