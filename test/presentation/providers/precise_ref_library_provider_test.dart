import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/precise_ref_library_provider.dart';
import 'package:path/path.dart' as p;

Uint8List _pngBytes() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(50, 60, 70));
  return Uint8List.fromList(img.encodePng(image));
}

class _CountingStorage extends PreciseRefLibraryStorageService {
  int getAllCalls = 0;

  @override
  Future<List<PreciseRefLibraryEntry>> getAllEntries() async {
    getAllCalls++;
    return const [];
  }
}

class _ConcurrencyTrackingStorage extends PreciseRefLibraryStorageService {
  int activeImports = 0;
  int maxActiveImports = 0;
  int _nextId = 0;

  @override
  Future<List<PreciseRefLibraryEntry>> getAllEntries() async => const [];

  @override
  Future<PreciseRefLibraryEntry> importFromBytes(
    Uint8List bytes, {
    required String name,
    PreciseRefType type = PreciseRefType.characterAndStyle,
    double strength = 1.0,
    double fidelity = 1.0,
  }) async {
    activeImports++;
    if (activeImports > maxActiveImports) {
      maxActiveImports = activeImports;
    }
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final id = 'batch-${_nextId++}';
      return PreciseRefLibraryEntry(
        id: id,
        name: name,
        imagePath: '$id.png',
        typeIndex: type.index,
        strength: strength,
        fidelity: fidelity,
        createdAt: DateTime(2026),
      );
    } finally {
      activeImports--;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PreciseRefLibraryStorageService storage;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'precise_ref_provider_test_',
    );
    Hive.init(p.join(tempDir.path, 'hive'));
    storage = PreciseRefLibraryStorageService(
      overrideDirectory: p.join(tempDir.path, 'images'),
    );
    container = ProviderContainer(
      overrides: [
        preciseRefLibraryStorageServiceProvider.overrideWithValue(storage),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await storage.close();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  PreciseRefLibraryNotifier notifier() =>
      container.read(preciseRefLibraryNotifierProvider.notifier);

  PreciseRefLibraryState state() =>
      container.read(preciseRefLibraryNotifierProvider);

  test('initialize 加载已有条目且幂等', () async {
    await storage.importFromBytes(_pngBytes(), name: 'existing');

    await notifier().initialize();
    expect(state().entries, hasLength(1));
    expect(state().filteredEntries, hasLength(1));

    // 已有数据时再次调用不重复加载
    await notifier().initialize();
    expect(state().entries, hasLength(1));
  });

  test('initialize 对空库同样幂等', () async {
    final countingStorage = _CountingStorage();
    final testContainer = ProviderContainer(
      overrides: [
        preciseRefLibraryStorageServiceProvider.overrideWithValue(
          countingStorage,
        ),
      ],
    );
    addTearDown(testContainer.dispose);
    final testNotifier = testContainer.read(
      preciseRefLibraryNotifierProvider.notifier,
    );

    await testNotifier.initialize();
    await testNotifier.initialize();

    expect(countingStorage.getAllCalls, 1);
  });

  test('importFromBytes 就地插入 state 并应用过滤', () async {
    await notifier().initialize();

    await notifier().importFromBytes(
      _pngBytes(),
      name: 'girl a',
      type: PreciseRefType.character,
      strength: 0.7,
      fidelity: 0.9,
    );

    expect(state().entries.single.name, 'girl a');
    expect(state().filteredEntries.single.type, PreciseRefType.character);
  });

  test('importMany 有限并发导入并只合并成功条目', () async {
    final trackingStorage = _ConcurrencyTrackingStorage();
    final testContainer = ProviderContainer(
      overrides: [
        preciseRefLibraryStorageServiceProvider.overrideWithValue(
          trackingStorage,
        ),
      ],
    );
    addTearDown(testContainer.dispose);
    final testNotifier = testContainer.read(
      preciseRefLibraryNotifierProvider.notifier,
    );

    final result = await testNotifier.importMany([
      for (var i = 0; i < 5; i++)
        PreciseRefLibraryImportSource(
          name: 'entry-$i',
          loadBytes: () async => i == 3 ? null : _pngBytes(),
        ),
    ], maxConcurrent: 2);

    expect(result.importedCount, 4);
    expect(result.failedCount, 1);
    expect(trackingStorage.maxActiveImports, 2);
    expect(
      testContainer.read(preciseRefLibraryNotifierProvider).entries,
      hasLength(4),
    );
  });

  test('搜索与收藏过滤共同作用', () async {
    await notifier().initialize();
    await notifier().importFromBytes(_pngBytes(), name: 'alpha');
    final beta = await notifier().importFromBytes(_pngBytes(), name: 'beta');
    await notifier().toggleFavorite(beta.id);

    notifier().setSearchQuery('beta');
    expect(state().filteredEntries.single.name, 'beta');

    notifier().setSearchQuery('');
    notifier().toggleFavoritesOnly();
    expect(state().filteredEntries.single.name, 'beta');

    notifier().setSearchQuery('alpha');
    expect(state().filteredEntries, isEmpty);
    expect(state().entries, hasLength(2));
  });

  test('setTypeFilter 按类型过滤，null 恢复全部', () async {
    await notifier().initialize();
    await notifier().importFromBytes(
      _pngBytes(),
      name: 'char',
      type: PreciseRefType.character,
    );
    await notifier().importFromBytes(
      _pngBytes(),
      name: 'style',
      type: PreciseRefType.style,
    );
    await notifier().importFromBytes(
      _pngBytes(),
      name: 'both',
      type: PreciseRefType.characterAndStyle,
    );

    notifier().setTypeFilter(PreciseRefType.style);
    expect(state().filteredEntries.single.name, 'style');
    expect(state().hasFilters, isTrue);

    // 类型过滤与搜索叠加
    notifier().setSearchQuery('char');
    expect(state().filteredEntries, isEmpty);

    notifier().setSearchQuery('');
    notifier().setTypeFilter(null);
    expect(state().filteredEntries, hasLength(3));
    expect(state().hasFilters, isFalse);
  });

  test('setSidebarFilter 原子切换收藏和类型分类', () async {
    await notifier().initialize();
    await notifier().importFromBytes(
      _pngBytes(),
      name: 'character',
      type: PreciseRefType.character,
    );
    final style = await notifier().importFromBytes(
      _pngBytes(),
      name: 'style',
      type: PreciseRefType.style,
    );
    await notifier().toggleFavorite(style.id);

    notifier().setSidebarFilter(
      favoritesOnly: false,
      type: PreciseRefType.style,
    );
    expect(state().favoritesOnly, isFalse);
    expect(state().typeFilter, PreciseRefType.style);
    expect(state().filteredEntries.single.name, 'style');

    notifier().setSidebarFilter(favoritesOnly: true);
    expect(state().favoritesOnly, isTrue);
    expect(state().typeFilter, isNull);
    expect(state().filteredEntries.single.name, 'style');
  });

  test('setSortOrder 重复选择同一排序时翻转方向', () async {
    await notifier().initialize();
    await notifier().importFromBytes(_pngBytes(), name: 'b');
    await notifier().importFromBytes(_pngBytes(), name: 'a');

    notifier().setSortOrder(PreciseRefLibrarySortOrder.name);
    expect(state().sortDescending, isTrue);
    expect(state().filteredEntries.first.name, 'b');

    notifier().setSortOrder(PreciseRefLibrarySortOrder.name);
    expect(state().sortDescending, isFalse);
    expect(state().filteredEntries.first.name, 'a');
  });

  test('updateEntry 与 recordUsage 就地替换条目', () async {
    await notifier().initialize();
    final entry = await notifier().importFromBytes(_pngBytes(), name: 'a');

    await notifier().updateEntry(entry.id, name: 'renamed', strength: 0.3);
    expect(state().entries.single.name, 'renamed');
    expect(state().entries.single.strength, 0.3);

    await notifier().recordUsage(entry.id);
    expect(state().entries.single.usedCount, 1);
  });

  test('deleteEntry 从 state 移除条目', () async {
    await notifier().initialize();
    final entry = await notifier().importFromBytes(_pngBytes(), name: 'a');

    final removed = await notifier().deleteEntry(entry.id);

    expect(removed, isTrue);
    expect(state().entries, isEmpty);
    expect(state().filteredEntries, isEmpty);
  });

  test('批量修改类型、统一收藏与删除只更新指定条目', () async {
    await notifier().initialize();
    final first = await notifier().importFromBytes(_pngBytes(), name: 'first');
    final second = await notifier().importFromBytes(
      _pngBytes(),
      name: 'second',
    );
    await notifier().importFromBytes(_pngBytes(), name: 'untouched');

    await notifier().updateEntriesType({
      first.id,
      second.id,
    }, PreciseRefType.style);
    await notifier().setEntriesFavorite({
      first.id,
      second.id,
    }, isFavorite: true);

    expect(
      state().entries.where(
        (entry) => {first.id, second.id}.contains(entry.id),
      ),
      everyElement(
        isA<PreciseRefLibraryEntry>()
            .having((entry) => entry.type, 'type', PreciseRefType.style)
            .having((entry) => entry.isFavorite, 'isFavorite', isTrue),
      ),
    );

    final deleted = await notifier().deleteEntries({first.id, second.id});
    expect(deleted, 2);
    expect(state().entries.single.name, 'untouched');
  });
}
