import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/precise_ref_library_provider.dart';
import 'package:path/path.dart' as p;

Uint8List _pngBytes() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(50, 60, 70));
  return Uint8List.fromList(img.encodePng(image));
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
}
