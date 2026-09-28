import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';

void main() {
  group('PreciseRefLibraryEntry', () {
    test('create 使用默认参数并生成 id 与创建时间', () {
      final entry = PreciseRefLibraryEntry.create(
        name: '  测试参考  ',
        imagePath: r'C:\refs\a.png',
      );

      expect(entry.id, isNotEmpty);
      expect(entry.name, '测试参考');
      expect(entry.type, PreciseRefType.characterAndStyle);
      expect(entry.strength, 1.0);
      expect(entry.fidelity, 1.0);
      expect(entry.isFavorite, isFalse);
      expect(entry.usedCount, 0);
      expect(entry.lastUsedAt, isNull);
    });

    test('type 索引越界时回退为 characterAndStyle', () {
      final entry = PreciseRefLibraryEntry(
        id: 'x',
        name: 'x',
        imagePath: 'x.png',
        typeIndex: 99,
        createdAt: DateTime(2026),
      );
      expect(entry.type, PreciseRefType.characterAndStyle);

      final negative = entry.copyWith(typeIndex: -1);
      expect(negative.type, PreciseRefType.characterAndStyle);
    });

    test('recordUsage 累加次数并更新最后使用时间', () {
      final entry = PreciseRefLibraryEntry.create(
        name: 'a',
        imagePath: 'a.png',
      );
      final used = entry.recordUsage();

      expect(used.usedCount, 1);
      expect(used.lastUsedAt, isNotNull);
      expect(used.recordUsage().usedCount, 2);
    });

    test('toggleFavorite 翻转收藏状态', () {
      final entry = PreciseRefLibraryEntry.create(
        name: 'a',
        imagePath: 'a.png',
      );
      expect(entry.toggleFavorite().isFavorite, isTrue);
      expect(entry.toggleFavorite().toggleFavorite().isFavorite, isFalse);
    });
  });

  group('PreciseRefLibraryEntryListExtension', () {
    List<PreciseRefLibraryEntry> buildEntries() => [
      PreciseRefLibraryEntry(
        id: '1',
        name: 'Alpha Girl',
        imagePath: '1.png',
        usedCount: 5,
        lastUsedAt: DateTime(2026, 1, 3),
        createdAt: DateTime(2026, 1, 1),
      ),
      PreciseRefLibraryEntry(
        id: '2',
        name: 'beta style',
        imagePath: '2.png',
        isFavorite: true,
        usedCount: 2,
        createdAt: DateTime(2026, 1, 2),
      ),
      PreciseRefLibraryEntry(
        id: '3',
        name: '水彩参考',
        imagePath: '3.png',
        usedCount: 9,
        lastUsedAt: DateTime(2026, 1, 5),
        createdAt: DateTime(2026, 1, 3),
      ),
    ];

    test('search 大小写不敏感，空查询返回全部', () {
      final entries = buildEntries();
      expect(entries.search('ALPHA').single.id, '1');
      expect(entries.search('水彩').single.id, '3');
      expect(entries.search('  '), hasLength(3));
      expect(entries.search('missing'), isEmpty);
    });

    test('favorites 只保留收藏条目', () {
      expect(buildEntries().favorites.single.id, '2');
    });

    test('sortedByCreatedAt 默认降序', () {
      final sorted = buildEntries().sortedByCreatedAt();
      expect(sorted.map((e) => e.id).toList(), ['3', '2', '1']);
      final ascending = buildEntries().sortedByCreatedAt(descending: false);
      expect(ascending.map((e) => e.id).toList(), ['1', '2', '3']);
    });

    test('sortedByLastUsed 未使用的条目排在最后', () {
      final sorted = buildEntries().sortedByLastUsed();
      expect(sorted.map((e) => e.id).toList(), ['3', '1', '2']);

      final ascending = buildEntries().sortedByLastUsed(descending: false);
      expect(ascending.map((e) => e.id).toList(), ['1', '3', '2']);
    });

    test('sortedByUsedCount 降序', () {
      final sorted = buildEntries().sortedByUsedCount();
      expect(sorted.map((e) => e.id).toList(), ['3', '1', '2']);
    });

    test('sortedByName 忽略大小写升序', () {
      final sorted = buildEntries().sortedByName();
      expect(sorted.first.id, '1');
      expect(sorted[1].id, '2');
    });
  });
}
