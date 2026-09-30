import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/local/pool_cache_service.dart';
import 'package:nai_launcher/data/datasources/local/tag_group_cache_service.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/character_count_config.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/pool_post.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/data/services/random_prompt_generator.dart';
import 'package:nai_launcher/data/services/sequential_state_service.dart';
import 'package:nai_launcher/data/services/tag_library_service.dart';

const _items = ['a', 'b', 'c', 'd', 'e'];

void main() {
  late RandomPromptGenerator generator;
  late _MockPoolCacheService pools;

  setUpAll(() => registerFallbackValue(_FakeRandom()));

  setUp(() {
    pools = _MockPoolCacheService();
    generator = RandomPromptGenerator(
      _MockTagLibraryService(),
      _CountingSequentialStateService(),
      _MockTagGroupCacheService(),
      pools,
    );
  });

  Future<List<String>> generate(RandomTagGroup group, {int seed = 1}) async {
    final result = await generator.generateFromPreset(
      preset: _preset(group),
      seed: seed,
    );
    return result.mainPrompt
        .split(', ')
        .where(_items.contains)
        .toList(growable: false);
  }

  for (final mode in SelectionMode.values) {
    test('$mode 下数量依赖决定抽取数量，超过可选数量时全部选取且不重复', () async {
      for (var seed = 0; seed < 20; seed++) {
        final three = await generate(_dependentGroup(mode, '3'), seed: seed);
        expect(three, hasLength(3), reason: 'seed=$seed');
        expect(three.toSet(), hasLength(3), reason: 'seed=$seed');

        final capped = await generate(_dependentGroup(mode, '9'), seed: seed);
        expect(capped.toSet(), _items.toSet(), reason: 'seed=$seed');
        expect(capped, hasLength(_items.length), reason: 'seed=$seed');
      }
    });
  }

  test('顺序轮替按轮替顺序连续取数，跨轮也不重复', () async {
    final seen = <String>[];
    for (var round = 0; round < 5; round++) {
      final picked = await generate(
        _dependentGroup(SelectionMode.sequential, '2'),
      );
      expect(picked.toSet(), hasLength(2));
      seen.addAll(picked);
    }
    expect(seen.take(5).toSet(), hasLength(5));
  });

  test('值依赖同样覆盖选择模式的数量', () async {
    final group = _dependentGroup(SelectionMode.all, '2').copyWith(
      dependencyConfig: const DependencyConfig(
        type: DependencyType.value,
        sourceCategoryId: 'pose',
        mappingRules: {'portrait': '2'},
      ),
    );

    expect(await generate(group), hasLength(2));
  });

  test('没有匹配的映射且未设默认值时不抽取', () async {
    expect(
      await generate(_dependentGroup(SelectionMode.single, '3', on: '2')),
      isEmpty,
    );
  });

  test('嵌套词组按依赖数量抽取子词组', () async {
    final group = _dependentGroup(SelectionMode.single, '2').copyWith(
      tags: const [],
      nodeType: TagGroupNodeType.config,
      children: [
        for (final item in _items.take(4))
          RandomTagGroup(
            id: 'child_$item',
            name: 'child_$item',
            shuffle: false,
            selectionMode: SelectionMode.all,
            tags: [WeightedTag.simple(item, 10, TagSource.custom)],
          ),
      ],
    );

    expect(await generate(group), hasLength(2));
  });

  test('Pool 词组按依赖数量抽取帖子', () async {
    when(() => pools.getPool(7)).thenAnswer(
      (_) async => PoolCacheEntry(
        poolId: 7,
        poolName: 'pool',
        posts: const [
          PoolPost(postId: 1, generalTags: ['a']),
          PoolPost(postId: 2, generalTags: ['b']),
          PoolPost(postId: 3, generalTags: ['c']),
        ],
        totalPostCount: 3,
        lastSyncedAt: DateTime.utc(2026),
      ),
    );
    when(() => pools.getRandomPosts(7, any(), any())).thenReturn(const []);

    await generate(
      _dependentGroup(SelectionMode.single, '2').copyWith(
        tags: const [],
        sourceType: TagGroupSourceType.pool,
        sourceId: '7',
      ),
    );

    verify(() => pools.getRandomPosts(7, 2, any())).called(1);
  });
}

RandomTagGroup _dependentGroup(
  SelectionMode mode,
  String count, {
  String on = '1',
}) {
  return RandomTagGroup(
    id: 'dependent',
    name: 'dependent',
    selectionMode: mode,
    shuffle: false,
    tags: [
      for (final item in _items) WeightedTag.simple(item, 10, TagSource.custom),
    ],
    dependencyConfig: DependencyConfig(
      sourceCategoryId: 'pose',
      mappingRules: {on: count},
    ),
  );
}

RandomPreset _preset(RandomTagGroup group) {
  return RandomPreset(
    id: 'preset',
    name: 'Preset',
    algorithmConfig: const AlgorithmConfig(
      globalEmphasisProbability: 0,
      characterCountConfig: CharacterCountConfig(
        categories: [
          CharacterCountCategory(
            id: 'no_humans',
            count: 0,
            label: 'No humans',
            weight: 100,
          ),
        ],
      ),
    ),
    categories: [
      RandomCategory(
        id: 'pose',
        key: 'pose',
        name: 'pose',
        groupSelectionMode: SelectionMode.all,
        shuffle: false,
        groups: [
          RandomTagGroup(
            id: 'pose_group',
            name: 'pose_group',
            selectionMode: SelectionMode.all,
            tags: [WeightedTag.simple('portrait', 10, TagSource.custom)],
          ),
        ],
      ),
      RandomCategory(
        id: 'detail',
        key: 'detail',
        name: 'detail',
        groupSelectionMode: SelectionMode.all,
        shuffle: false,
        groups: [group],
      ),
    ],
  );
}

class _MockTagLibraryService extends Mock implements TagLibraryService {}

class _MockTagGroupCacheService extends Mock implements TagGroupCacheService {}

class _MockPoolCacheService extends Mock implements PoolCacheService {}

class _FakeRandom extends Fake implements Random {}

class _CountingSequentialStateService extends Mock
    implements SequentialStateService {
  final _cursors = <String, int>{};

  @override
  Future<void> init() async {}

  @override
  int getNextCursorSync(String key) {
    final cursor = _cursors[key] ?? 0;
    _cursors[key] = cursor + 1;
    return cursor;
  }
}
