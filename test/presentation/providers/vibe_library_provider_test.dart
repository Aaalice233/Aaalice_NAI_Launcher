import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';

void main() {
  test('切换到分类后再清空分类过滤，应恢复显示全部 Vibe', () async {
    final storage = _CategorizedStorageService();
    final container = ProviderContainer(
      overrides: [
        vibeLibraryStorageServiceProvider.overrideWithValue(storage),
      ],
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
      overrides: [
        vibeLibraryStorageServiceProvider.overrideWithValue(storage),
      ],
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

  test('loadFromCache 不应暴露 entries 已加载但 currentEntries 仍为空的中间态', () async {
    final storage = _LoadedStorageService();
    final container = ProviderContainer(
      overrides: [
        vibeLibraryStorageServiceProvider.overrideWithValue(storage),
      ],
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
