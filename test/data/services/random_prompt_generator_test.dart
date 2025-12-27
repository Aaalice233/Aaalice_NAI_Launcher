import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/local/pool_cache_service.dart';
import 'package:nai_launcher/data/datasources/local/tag_group_cache_service.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/data/services/random_prompt_generator.dart';
import 'package:nai_launcher/data/services/sequential_state_service.dart';
import 'package:nai_launcher/data/services/tag_library_service.dart';
import 'package:mocktail/mocktail.dart';

/// Mock TagLibraryService
class MockTagLibraryService extends Mock implements TagLibraryService {}

/// Mock SequentialStateService
class MockSequentialStateService extends Mock
    implements SequentialStateService {}

/// Mock TagGroupCacheService
class MockTagGroupCacheService extends Mock implements TagGroupCacheService {}

/// Mock PoolCacheService
class MockPoolCacheService extends Mock implements PoolCacheService {}

void main() {
  late MockTagLibraryService mockLibraryService;
  late MockSequentialStateService mockSequentialService;
  late MockTagGroupCacheService mockTagGroupCacheService;
  late MockPoolCacheService mockPoolCacheService;
  late RandomPromptGenerator generator;

  setUp(() {
    mockLibraryService = MockTagLibraryService();
    mockSequentialService = MockSequentialStateService();
    mockTagGroupCacheService = MockTagGroupCacheService();
    mockPoolCacheService = MockPoolCacheService();
    generator = RandomPromptGenerator(
      mockLibraryService,
      mockSequentialService,
      mockTagGroupCacheService,
      mockPoolCacheService,
    );

    // 默认配置：sequential 模式返回索引 0
    when(() => mockSequentialService.getNextIndexSync(any(), any()))
        .thenReturn(0);
  });

  group('RandomPromptGenerator 参数使用测试', () {
    group('enabled 启用状态测试', () {
      test('禁用的类别不生成标签', () async {
        // 创建预设：一个禁用的类别，一个启用的类别
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '禁用类别',
              key: 'disabled',
              enabled: false, // 禁用
              probability: 1.0,
              groups: [
                RandomTagGroup.custom(
                  name: 'Group1',
                  tags: [WeightedTag.simple('disabled_tag', 10)],
                ),
              ],
            ),
            RandomCategory(
              id: 'cat2',
              name: '启用类别',
              key: 'enabled',
              enabled: true, // 启用
              probability: 1.0,
              groups: [
                RandomTagGroup.custom(
                  name: 'Group2',
                  tags: [WeightedTag.simple('enabled_tag', 10)],
                ),
              ],
            ),
          ],
        );

        final result = await generator.generateFromPreset(preset: preset, seed: 42);

        // 验证：禁用类别的标签不应出现
        expect(result.mainPrompt, isNot(contains('disabled_tag')));
        expect(result.mainPrompt, contains('enabled_tag'));
      });

      test('禁用的词组不生成标签', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '测试类别',
              key: 'test',
              enabled: true,
              probability: 1.0,
              groupSelectionMode: SelectionMode.all, // 选择所有词组
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: '禁用词组',
                  enabled: false, // 禁用
                  tags: [WeightedTag.simple('disabled_group_tag', 10)],
                ),
                RandomTagGroup(
                  id: 'grp2',
                  name: '启用词组',
                  enabled: true, // 启用
                  tags: [WeightedTag.simple('enabled_group_tag', 10)],
                ),
              ],
            ),
          ],
        );

        final result = await generator.generateFromPreset(preset: preset, seed: 42);

        // 验证：禁用词组的标签不应出现
        expect(result.mainPrompt, isNot(contains('disabled_group_tag')));
        expect(result.mainPrompt, contains('enabled_group_tag'));
      });
    });

    group('probability 概率测试', () {
      test('概率为0的类别不生成标签', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '零概率类别',
              key: 'zero_prob',
              enabled: true,
              probability: 0.0, // 概率为0
              groups: [
                RandomTagGroup.custom(
                  name: 'Group1',
                  tags: [WeightedTag.simple('zero_prob_tag', 10)],
                ),
              ],
            ),
            RandomCategory(
              id: 'cat2',
              name: '必选类别',
              key: 'always',
              enabled: true,
              probability: 1.0, // 概率为1
              groups: [
                RandomTagGroup.custom(
                  name: 'Group2',
                  tags: [WeightedTag.simple('always_tag', 10)],
                ),
              ],
            ),
          ],
        );

        // 运行多次验证
        for (var i = 0; i < 10; i++) {
          final result = await generator.generateFromPreset(preset: preset, seed: i);
          expect(
              result.mainPrompt,
              isNot(contains('zero_prob_tag')),
              reason: '概率为0的类别不应该生成标签 (seed=$i)',
            );
        }
      });

      test('概率为0的词组不生成标签', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '测试类别',
              key: 'test',
              enabled: true,
              probability: 1.0,
              groupSelectionMode: SelectionMode.all, // 选择所有词组
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: '零概率词组',
                  enabled: true,
                  probability: 0.0, // 概率为0
                  tags: [WeightedTag.simple('zero_prob_group_tag', 10)],
                ),
                RandomTagGroup(
                  id: 'grp2',
                  name: '必选词组',
                  enabled: true,
                  probability: 1.0, // 概率为1
                  tags: [WeightedTag.simple('always_group_tag', 10)],
                ),
              ],
            ),
          ],
        );

        // 运行多次验证
        for (var i = 0; i < 10; i++) {
          final result = await generator.generateFromPreset(preset: preset, seed: i);
          expect(
              result.mainPrompt,
              isNot(contains('zero_prob_group_tag')),
              reason: '概率为0的词组不应该生成标签 (seed=$i)',
            );
        }
      });

      test('概率为1的类别始终生成标签', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '必选类别',
              key: 'always',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup.custom(
                  name: 'Group1',
                  tags: [WeightedTag.simple('always_tag', 10)],
                ),
              ],
            ),
          ],
        );

        // 运行多次验证
        for (var i = 0; i < 20; i++) {
          final result = await generator.generateFromPreset(preset: preset, seed: i);
          expect(
              result.mainPrompt,
              contains('always_tag'),
              reason: '概率为1的类别应该始终生成标签 (seed=$i)',
            );
        }
      });
    });

    group('weight 权重测试', () {
      test('高权重标签被选中频率更高', () async {
        // 创建预设：一个高权重标签，一个低权重标签
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '权重测试',
              key: 'weight_test',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: 'Weight Group',
                  enabled: true,
                  probability: 1.0,
                  selectionMode: SelectionMode.single, // 单选模式
                  tags: [
                    WeightedTag.simple('high_weight', 900), // 高权重
                    WeightedTag.simple('low_weight', 100), // 低权重
                  ],
                ),
              ],
            ),
          ],
        );

        // 统计选中频率
        var highCount = 0;
        var lowCount = 0;
        const iterations = 1000;

        for (var i = 0; i < iterations; i++) {
          final result = await generator.generateFromPreset(preset: preset, seed: i);
          if (result.mainPrompt.contains('high_weight')) {
            highCount++;
          }
          if (result.mainPrompt.contains('low_weight')) {
            lowCount++;
          }
        }

        // 验证：高权重标签应该被选中更多次
        // 理论比例 900:100 = 9:1，实际应该接近
        final ratio = highCount / (lowCount == 0 ? 1 : lowCount);

        print('高权重选中次数: $highCount, 低权重选中次数: $lowCount');
        print('实际比例: ${ratio.toStringAsFixed(2)}:1 (理论 9:1)');

        expect(
          highCount,
          greaterThan(lowCount * 3),
          reason: '高权重标签应该被选中更多次 (highCount=$highCount, lowCount=$lowCount)',
        );
      });

      test('getWeightedChoice 正确使用权重进行加权随机', () {
        final tags = [
          WeightedTag.simple('tag1', 100),
          WeightedTag.simple('tag2', 200),
          WeightedTag.simple('tag3', 700),
        ];

        final counts = <String, int>{
          'tag1': 0,
          'tag2': 0,
          'tag3': 0,
        };

        const iterations = 1000;
        for (var i = 0; i < iterations; i++) {
          final random = Random(i);
          final result = generator.getWeightedChoice(tags, random: random);
          counts[result] = (counts[result] ?? 0) + 1;
        }

        print('tag1(100): ${counts['tag1']}, tag2(200): ${counts['tag2']}, tag3(700): ${counts['tag3']}');

        // 验证比例接近 1:2:7
        expect(
          counts['tag3']!,
          greaterThan(counts['tag1']! * 3),
          reason: 'tag3(700) 应该比 tag1(100) 被选中多得多',
        );
        expect(
          counts['tag3']!,
          greaterThan(counts['tag2']! * 2),
          reason: 'tag3(700) 应该比 tag2(200) 被选中多得多',
        );
      });
    });

    group('SelectionMode 选择模式测试', () {
      test('single模式只选择一个标签', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '单选测试',
              key: 'single_test',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: 'Single Group',
                  enabled: true,
                  probability: 1.0,
                  selectionMode: SelectionMode.single,
                  tags: [
                    WeightedTag.simple('tag1', 10),
                    WeightedTag.simple('tag2', 10),
                    WeightedTag.simple('tag3', 10),
                  ],
                ),
              ],
            ),
          ],
        );

        for (var i = 0; i < 10; i++) {
          final result = await generator.generateFromPreset(preset: preset, seed: i);
          final parts = result.mainPrompt.split(', ');
          expect(
            parts.length,
            equals(1),
            reason: 'single模式应该只选择一个标签 (seed=$i, result=${result.mainPrompt})',
          );
        }
      });

      test('all模式选择所有标签', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '全选测试',
              key: 'all_test',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: 'All Group',
                  enabled: true,
                  probability: 1.0,
                  selectionMode: SelectionMode.all,
                  shuffle: false, // 不打乱，保持顺序
                  tags: [
                    WeightedTag.simple('tag_a', 10),
                    WeightedTag.simple('tag_b', 10),
                    WeightedTag.simple('tag_c', 10),
                  ],
                ),
              ],
            ),
          ],
        );

        final result = await generator.generateFromPreset(preset: preset, seed: 42);

        expect(result.mainPrompt, contains('tag_a'));
        expect(result.mainPrompt, contains('tag_b'));
        expect(result.mainPrompt, contains('tag_c'));
      });

      test('multipleNum模式选择指定数量', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '多选数量测试',
              key: 'multiple_num_test',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: 'MultipleNum Group',
                  enabled: true,
                  probability: 1.0,
                  selectionMode: SelectionMode.multipleNum,
                  multipleNum: 2, // 选择2个
                  tags: [
                    WeightedTag.simple('tag1', 10),
                    WeightedTag.simple('tag2', 10),
                    WeightedTag.simple('tag3', 10),
                    WeightedTag.simple('tag4', 10),
                    WeightedTag.simple('tag5', 10),
                  ],
                ),
              ],
            ),
          ],
        );

        for (var i = 0; i < 10; i++) {
          final result = await generator.generateFromPreset(preset: preset, seed: i);
          final parts = result.mainPrompt.split(', ');
          expect(
            parts.length,
            equals(2),
            reason: 'multipleNum=2 应该选择2个标签 (seed=$i, result=${result.mainPrompt})',
          );
        }
      });

      test('sequential模式按顺序轮替', () async {
        // 配置 sequential service 返回递增索引
        var callCount = 0;
        when(() => mockSequentialService.getNextIndexSync(any(), any()))
            .thenAnswer((_) {
          final index = callCount % 3;
          callCount++;
          return index;
        });

        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '顺序轮替测试',
              key: 'sequential_test',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: 'Sequential Group',
                  enabled: true,
                  probability: 1.0,
                  selectionMode: SelectionMode.sequential,
                  tags: [
                    WeightedTag.simple('seq_tag_0', 10),
                    WeightedTag.simple('seq_tag_1', 10),
                    WeightedTag.simple('seq_tag_2', 10),
                  ],
                ),
              ],
            ),
          ],
        );

        // 第一次调用，返回索引0
        final result1 = await generator.generateFromPreset(preset: preset, seed: 42);
        expect(result1.mainPrompt, contains('seq_tag_0'));

        // 第二次调用，返回索引1
        final result2 = await generator.generateFromPreset(preset: preset, seed: 42);
        expect(result2.mainPrompt, contains('seq_tag_1'));

        // 第三次调用，返回索引2
        final result3 = await generator.generateFromPreset(preset: preset, seed: 42);
        expect(result3.mainPrompt, contains('seq_tag_2'));

        // 验证 sequential service 被调用
        verify(() => mockSequentialService.getNextIndexSync(any(), 3)).called(3);
      });
    });

    group('括号范围测试', () {
      test('bracketMin/bracketMax正确应用权重括号', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '括号测试',
              key: 'bracket_test',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: 'Bracket Group',
                  enabled: true,
                  probability: 1.0,
                  selectionMode: SelectionMode.single,
                  bracketMin: 2, // 最少2层
                  bracketMax: 2, // 最多2层（固定2层）
                  tags: [
                    WeightedTag.simple('bracket_tag', 10),
                  ],
                ),
              ],
            ),
          ],
        );

        final result = await generator.generateFromPreset(preset: preset, seed: 42);

        // 验证：标签应该被包裹在2层 {} 中
        expect(result.mainPrompt, contains('{{bracket_tag}}'));
      });

      test('负数括号使用[]降权', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '降权括号测试',
              key: 'negative_bracket_test',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: 'Negative Bracket Group',
                  enabled: true,
                  probability: 1.0,
                  selectionMode: SelectionMode.single,
                  bracketMin: -1, // 负数
                  bracketMax: -1, // 负数
                  tags: [
                    WeightedTag.simple('lowered_tag', 10),
                  ],
                ),
              ],
            ),
          ],
        );

        final result = await generator.generateFromPreset(preset: preset, seed: 42);

        // 验证：标签应该被包裹在1层 [] 中
        expect(result.mainPrompt, contains('[lowered_tag]'));
      });
    });

    group('综合测试', () {
      test('使用固定种子产生可重复结果', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Test Preset',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '可重复性测试',
              key: 'reproducible',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: 'Test Group',
                  enabled: true,
                  probability: 1.0,
                  selectionMode: SelectionMode.single,
                  tags: [
                    WeightedTag.simple('tag_a', 10),
                    WeightedTag.simple('tag_b', 20),
                    WeightedTag.simple('tag_c', 30),
                  ],
                ),
              ],
            ),
          ],
        );

        // 使用相同种子生成两次
        final result1 = await generator.generateFromPreset(preset: preset, seed: 12345);
        final result2 = await generator.generateFromPreset(preset: preset, seed: 12345);

        expect(
          result1.mainPrompt,
          equals(result2.mainPrompt),
          reason: '使用相同种子应该产生相同结果',
        );
      });

      test('空预设返回空结果', () async {
        const preset = RandomPreset(
          id: 'test',
          name: 'Empty Preset',
          categories: [], // 空类别列表
        );

        final result = await generator.generateFromPreset(preset: preset, seed: 42);

        expect(result.mainPrompt, isEmpty);
      });

      test('全部禁用返回空结果', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'All Disabled',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '禁用类别',
              key: 'disabled',
              enabled: false, // 禁用
              groups: [
                RandomTagGroup.custom(
                  name: 'Group1',
                  tags: [WeightedTag.simple('tag1', 10)],
                ),
              ],
            ),
          ],
        );

        final result = await generator.generateFromPreset(preset: preset, seed: 42);

        expect(result.mainPrompt, isEmpty);
      });
    });

    group('嵌套词组测试', () {
      test('嵌套词组正确生成标签', () async {
        final preset = RandomPreset(
          id: 'test',
          name: 'Nested Test',
          categories: [
            RandomCategory(
              id: 'cat1',
              name: '嵌套测试',
              key: 'nested',
              enabled: true,
              probability: 1.0,
              groups: [
                RandomTagGroup(
                  id: 'grp1',
                  name: 'Parent Group',
                  enabled: true,
                  probability: 1.0,
                  nodeType: TagGroupNodeType.config, // 嵌套配置
                  selectionMode: SelectionMode.all,
                  children: [
                    RandomTagGroup(
                      id: 'child1',
                      name: 'Child Group 1',
                      enabled: true,
                      probability: 1.0,
                      selectionMode: SelectionMode.single,
                      tags: [WeightedTag.simple('child1_tag', 10)],
                    ),
                    RandomTagGroup(
                      id: 'child2',
                      name: 'Child Group 2',
                      enabled: true,
                      probability: 1.0,
                      selectionMode: SelectionMode.single,
                      tags: [WeightedTag.simple('child2_tag', 10)],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final result = await generator.generateFromPreset(preset: preset, seed: 42);

        expect(result.mainPrompt, contains('child1_tag'));
        expect(result.mainPrompt, contains('child2_tag'));
      });
    });

    group('条件过滤测试', () {
      test('getWeightedChoice 正确应用条件过滤', () {
        final tags = [
          const WeightedTag(
            tag: 'conditional_tag',
            weight: 100,
            conditions: ['context_required'], // 需要上下文
          ),
          WeightedTag.simple('always_available', 10),
        ];

        // 没有上下文时，conditional_tag 不应被选中
        var conditionalCount = 0;
        var alwaysCount = 0;
        for (var i = 0; i < 100; i++) {
          final result = generator.getWeightedChoice(
            tags,
            context: [], // 空上下文
            random: Random(i),
          );
          if (result == 'conditional_tag') conditionalCount++;
          if (result == 'always_available') alwaysCount++;
        }

        expect(
          conditionalCount,
          equals(0),
          reason: '没有匹配上下文时，条件标签不应被选中',
        );
        expect(
          alwaysCount,
          equals(100),
          reason: '无条件标签应该被选中',
        );

        // 有匹配上下文时，conditional_tag 可以被选中
        conditionalCount = 0;
        alwaysCount = 0;
        for (var i = 0; i < 100; i++) {
          final result = generator.getWeightedChoice(
            tags,
            context: ['context_required'], // 匹配上下文
            random: Random(i),
          );
          if (result == 'conditional_tag') conditionalCount++;
          if (result == 'always_available') alwaysCount++;
        }

        expect(
          conditionalCount,
          greaterThan(0),
          reason: '有匹配上下文时，条件标签应该可以被选中',
        );
        print('有上下文时 - conditional: $conditionalCount, always: $alwaysCount');
      });
    });
  });
}
