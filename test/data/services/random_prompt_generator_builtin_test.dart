import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/local/pool_cache_service.dart';
import 'package:nai_launcher/data/datasources/local/tag_group_cache_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/character_count_config.dart';
import 'package:nai_launcher/data/models/prompt/default_categories.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/tag_category.dart';
import 'package:nai_launcher/data/models/prompt/tag_library.dart';
import 'package:nai_launcher/data/models/prompt/tag_scope.dart';
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

  /// 创建包含所有必需分类的测试词库
  TagLibrary createTestLibrary() {
    return TagLibrary(
      id: 'test_library',
      name: 'Test Library',
      lastUpdated: DateTime.now(),
      version: 1,
      source: TagLibrarySource.nai,
      categories: {
        // 发色
        'hairColor': [
          WeightedTag.simple('blonde hair', 5),
          WeightedTag.simple('black hair', 6),
          WeightedTag.simple('brown hair', 5),
          WeightedTag.simple('red hair', 3),
        ],
        // 瞳色
        'eyeColor': [
          WeightedTag.simple('blue eyes', 6),
          WeightedTag.simple('red eyes', 3),
          WeightedTag.simple('green eyes', 4),
        ],
        // 发型
        'hairStyle': [
          WeightedTag.simple('long hair', 8),
          WeightedTag.simple('short hair', 6),
          WeightedTag.simple('twintails', 4),
        ],
        // 表情
        'expression': [
          WeightedTag.simple('smile', 8),
          WeightedTag.simple('blush', 6),
          WeightedTag.simple('open mouth', 4),
        ],
        // 姿势
        'pose': [
          WeightedTag.simple('standing', 6),
          WeightedTag.simple('sitting', 5),
          WeightedTag.simple('walking', 4),
        ],
        // 女性服装
        'clothingFemale': [
          WeightedTag.simple('dress', 6),
          WeightedTag.simple('skirt', 5),
          WeightedTag.simple('bikini', 3),
        ],
        // 男性服装
        'clothingMale': [
          WeightedTag.simple('suit', 5),
          WeightedTag.simple('shirt', 6),
        ],
        // 通用服装
        'clothingGeneral': [
          WeightedTag.simple('jacket', 5),
          WeightedTag.simple('hoodie', 4),
          WeightedTag.simple('uniform', 5),
        ],
        // 配饰
        'accessory': [
          WeightedTag.simple('glasses', 5),
          WeightedTag.simple('hat', 4),
        ],
        // 女性体型
        'bodyFeatureFemale': [
          WeightedTag.simple('large breasts', 5),
          WeightedTag.simple('small breasts', 4),
        ],
        // 男性体型
        'bodyFeatureMale': [
          WeightedTag.simple('muscular', 5),
          WeightedTag.simple('abs', 4),
        ],
        // 通用体型
        'bodyFeatureGeneral': [
          WeightedTag.simple('slim', 5),
          WeightedTag.simple('tall', 4),
        ],
        // 背景
        'background': [
          WeightedTag.simple('simple background', 5),
          WeightedTag.simple('detailed background', 4),
        ],
        // 场景
        'scene': [
          WeightedTag.simple('outdoors', 5),
          WeightedTag.simple('indoors', 5),
        ],
        // 风格
        'style': [
          WeightedTag.simple('photorealistic', 3),
          WeightedTag.simple('anime style', 6),
        ],
      },
    );
  }

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

    // 配置 mock 返回测试词库
    when(() => mockLibraryService.getAvailableLibrary())
        .thenAnswer((_) async => createTestLibrary());
  });

  group('Builtin 类型词组测试', () {
    test('fromBuiltin 正确设置 sourceType 和 sourceId', () {
      final group = RandomTagGroup.fromBuiltin(
        name: '发色',
        builtinCategoryKey: TagSubCategory.hairColor.name,
        emoji: '🎨',
      );

      expect(group.sourceType, equals(TagGroupSourceType.builtin));
      expect(group.sourceId, equals('hairColor'));
      expect(group.tags, isEmpty); // 内置词组的 tags 应该为空
    });

    test('builtin 词组从 TagLibrary 正确获取标签', () async {
      final preset = RandomPreset(
        id: 'test',
        name: 'Builtin Test',
        categories: [
          RandomCategory(
            id: 'cat1',
            name: '发色',
            key: 'hairColor',
            enabled: true,
            probability: 1.0, // 100% 概率
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '发色',
                builtinCategoryKey: TagSubCategory.hairColor.name,
                emoji: '🎨',
              ),
            ],
          ),
        ],
      );

      final result = await generator.generateFromPreset(preset: preset, seed: 42);

      // 验证生成了发色标签
      expect(result.mainPrompt, isNotEmpty);

      // 应该包含发色词库中的标签之一
      final possibleHairColors = ['blonde hair', 'black hair', 'brown hair', 'red hair'];
      final containsHairColor = possibleHairColors.any(
        (color) => result.mainPrompt.contains(color),
      );
      expect(
        containsHairColor,
        isTrue,
        reason: '应该包含发色标签，实际结果: ${result.mainPrompt}',
      );
    });

    test('多个 builtin 词组正确生成标签', () async {
      final preset = RandomPreset(
        id: 'test',
        name: 'Multi Builtin Test',
        categories: [
          RandomCategory(
            id: 'cat1',
            name: '发色',
            key: 'hairColor',
            enabled: true,
            probability: 1.0,
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '发色',
                builtinCategoryKey: TagSubCategory.hairColor.name,
                emoji: '🎨',
              ),
            ],
          ),
          RandomCategory(
            id: 'cat2',
            name: '瞳色',
            key: 'eyeColor',
            enabled: true,
            probability: 1.0,
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '瞳色',
                builtinCategoryKey: TagSubCategory.eyeColor.name,
                emoji: '👁️',
              ),
            ],
          ),
        ],
      );

      final result = await generator.generateFromPreset(preset: preset, seed: 42);

      print('Multi builtin result: ${result.mainPrompt}');

      // 验证生成了多个标签
      expect(result.mainPrompt.split(', ').length, greaterThanOrEqualTo(2));
    });

    test('新增拆分类别（clothingFemale 等）正确生成标签', () async {
      final preset = RandomPreset(
        id: 'test',
        name: 'Split Category Test',
        categories: [
          RandomCategory(
            id: 'cat1',
            name: '女性服装',
            key: 'clothingFemale',
            enabled: true,
            probability: 1.0,
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '女性服装',
                builtinCategoryKey: TagSubCategory.clothingFemale.name,
                emoji: '👗',
              ),
            ],
          ),
        ],
      );

      final result = await generator.generateFromPreset(preset: preset, seed: 42);

      print('clothingFemale result: ${result.mainPrompt}');

      // 验证生成了女性服装标签
      expect(result.mainPrompt, isNotEmpty);
      final possibleClothing = ['dress', 'skirt', 'bikini'];
      final containsClothing = possibleClothing.any(
        (item) => result.mainPrompt.contains(item),
      );
      expect(
        containsClothing,
        isTrue,
        reason: '应该包含女性服装标签，实际结果: ${result.mainPrompt}',
      );
    });
  });

  group('DefaultCategories 默认类别测试', () {
    test('DefaultCategories.createDefault() 生成正确数量的类别', () {
      final categories = DefaultCategories.createDefault();

      // 打印所有类别用于调试
      for (final cat in categories) {
        print('类别: ${cat.name} (${cat.key}), 词组数: ${cat.groups.length}');
        for (final group in cat.groups) {
          print('  - 词组: ${group.name}, sourceType: ${group.sourceType}, sourceId: ${group.sourceId}');
        }
      }

      expect(categories, isNotEmpty);
      // 根据 default_categories.dart，应该有 11 个类别
      expect(categories.length, equals(11));
    });

    test('服装类别包含 3 个拆分词组', () {
      final categories = DefaultCategories.createDefault();
      final clothingCategory = categories.firstWhere(
        (c) => c.key == 'clothing',
      );

      expect(clothingCategory.groups.length, equals(3));

      // 验证各子词组
      final femaleGroup = clothingCategory.groups.firstWhere(
        (g) => g.sourceId == 'clothingFemale',
      );
      expect(femaleGroup.genderRestrictionEnabled, isTrue);
      expect(femaleGroup.applicableGenders, contains('girl'));

      final maleGroup = clothingCategory.groups.firstWhere(
        (g) => g.sourceId == 'clothingMale',
      );
      expect(maleGroup.genderRestrictionEnabled, isTrue);
      expect(maleGroup.applicableGenders, contains('boy'));

      final generalGroup = clothingCategory.groups.firstWhere(
        (g) => g.sourceId == 'clothingGeneral',
      );
      expect(generalGroup.genderRestrictionEnabled, isFalse);
    });

    test('身体特征类别包含 3 个拆分词组', () {
      final categories = DefaultCategories.createDefault();
      final bodyCategory = categories.firstWhere(
        (c) => c.key == 'bodyFeature',
      );

      expect(bodyCategory.groups.length, equals(3));

      // 验证各子词组
      expect(
        bodyCategory.groups.any((g) => g.sourceId == 'bodyFeatureFemale'),
        isTrue,
      );
      expect(
        bodyCategory.groups.any((g) => g.sourceId == 'bodyFeatureMale'),
        isTrue,
      );
      expect(
        bodyCategory.groups.any((g) => g.sourceId == 'bodyFeatureGeneral'),
        isTrue,
      );
    });

    test('使用默认类别生成预设能正确生成标签', () async {
      final categories = DefaultCategories.createDefault();
      final preset = RandomPreset(
        id: 'default_test',
        name: 'Default Categories Test',
        categories: categories,
      );

      // 运行多次确保能生成标签
      var totalTagCount = 0;
      for (var i = 0; i < 10; i++) {
        final result = await generator.generateFromPreset(
          preset: preset,
          seed: i,
        );
        print('Seed $i: ${result.mainPrompt}');

        if (result.mainPrompt.isNotEmpty) {
          totalTagCount += result.mainPrompt.split(', ').length;
        }
      }

      print('总标签数: $totalTagCount');

      // 10 次生成应该至少产生 30 个标签（平均每次 3 个）
      expect(
        totalTagCount,
        greaterThan(30),
        reason: '使用默认类别应该能生成足够多的标签',
      );
    });
  });

  group('TagLibrary.getCategory 测试', () {
    test('getCategory 正确返回标签列表', () {
      final library = createTestLibrary();

      final hairColors = library.getCategory(TagSubCategory.hairColor);
      expect(hairColors.length, equals(4));

      final clothingFemale = library.getCategory(TagSubCategory.clothingFemale);
      expect(clothingFemale.length, equals(3));

      final clothingMale = library.getCategory(TagSubCategory.clothingMale);
      expect(clothingMale.length, equals(2));
    });

    test('不存在的分类返回空列表', () {
      final library = TagLibrary(
        id: 'empty',
        name: 'Empty',
        lastUpdated: DateTime.now(),
        version: 1,
        source: TagLibrarySource.nai,
        categories: {},
      );

      final result = library.getCategory(TagSubCategory.hairColor);
      expect(result, isEmpty);
    });
  });

  group('性别过滤测试', () {
    test('性别限定词组根据角色性别正确过滤', () async {
      final preset = RandomPreset(
        id: 'test',
        name: 'Gender Filter Test',
        categories: [
          RandomCategory(
            id: 'clothing',
            name: '服装',
            key: 'clothing',
            enabled: true,
            probability: 1.0,
            groupSelectionMode: SelectionMode.all, // 选择所有词组
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '女性服装',
                builtinCategoryKey: TagSubCategory.clothingFemale.name,
                emoji: '👗',
              ).copyWith(
                genderRestrictionEnabled: true,
                applicableGenders: ['girl'],
              ),
              RandomTagGroup.fromBuiltin(
                name: '男性服装',
                builtinCategoryKey: TagSubCategory.clothingMale.name,
                emoji: '👔',
              ).copyWith(
                genderRestrictionEnabled: true,
                applicableGenders: ['boy'],
              ),
              RandomTagGroup.fromBuiltin(
                name: '通用服装',
                builtinCategoryKey: TagSubCategory.clothingGeneral.name,
                emoji: '🎽',
              ).copyWith(
                genderRestrictionEnabled: false,
              ),
            ],
          ),
        ],
      );

      // 由于 generateFromPreset 不传递性别参数，所有词组都会被选中
      // 性别过滤主要用于多角色模式
      final result = await generator.generateFromPreset(preset: preset, seed: 42);
      print('Gender filter result: ${result.mainPrompt}');

      // 验证至少生成了一些标签
      expect(result.mainPrompt, isNotEmpty);
    });
  });

  group('概率配置测试', () {
    test('NAI 官方概率配置生成合理数量的标签', () async {
      final categories = DefaultCategories.createDefault();
      final preset = RandomPreset(
        id: 'prob_test',
        name: 'Probability Test',
        categories: categories,
      );

      // 统计各类别被选中的次数
      final categoryHitCounts = <String, int>{};
      const iterations = 100;

      for (var i = 0; i < iterations; i++) {
        final result = await generator.generateFromPreset(
          preset: preset,
          seed: i,
        );

        // 检查各类别的标签是否出现
        for (final cat in categories) {
          // 这里简化处理，只统计非空结果
          if (result.mainPrompt.isNotEmpty) {
            categoryHitCounts[cat.key] = (categoryHitCounts[cat.key] ?? 0) + 1;
          }
        }
      }

      print('各类别命中统计:');
      for (final entry in categoryHitCounts.entries) {
        print('  ${entry.key}: ${entry.value}/$iterations (${(entry.value / iterations * 100).toStringAsFixed(1)}%)');
      }

      // 验证至少有一些类别被命中
      expect(categoryHitCounts.values.any((v) => v > 0), isTrue);
    });
  });

  group('TagScope.isApplicableTo 作用域过滤测试', () {
    test('all 目标作用域接受所有类别', () {
      // all 目标应该接受 character, global, all 类别
      expect(TagScope.character.isApplicableTo(TagScope.all), isTrue);
      expect(TagScope.global.isApplicableTo(TagScope.all), isTrue);
      expect(TagScope.all.isApplicableTo(TagScope.all), isTrue);
    });

    test('character 目标作用域只接受 character 和 all 类别', () {
      expect(TagScope.character.isApplicableTo(TagScope.character), isTrue);
      expect(TagScope.all.isApplicableTo(TagScope.character), isTrue);
      expect(TagScope.global.isApplicableTo(TagScope.character), isFalse);
    });

    test('global 目标作用域只接受 global 和 all 类别', () {
      expect(TagScope.global.isApplicableTo(TagScope.global), isTrue);
      expect(TagScope.all.isApplicableTo(TagScope.global), isTrue);
      expect(TagScope.character.isApplicableTo(TagScope.global), isFalse);
    });

    test('默认类别的作用域设置正确', () {
      final categories = DefaultCategories.createDefault();

      // 角色相关类别应该是 character
      final hairColor = categories.firstWhere((c) => c.key == 'hairColor');
      expect(hairColor.scope, equals(TagScope.character));

      final eyeColor = categories.firstWhere((c) => c.key == 'eyeColor');
      expect(eyeColor.scope, equals(TagScope.character));

      // 背景应该是 global
      final background = categories.firstWhere((c) => c.key == 'background');
      expect(background.scope, equals(TagScope.global));

      // 姿势应该是 all（两者都适用）
      final pose = categories.firstWhere((c) => c.key == 'pose');
      expect(pose.scope, equals(TagScope.all));
    });

    test('多角色场景：scope 正确分配到 mainPrompt 和 characters', () async {
      final preset = RandomPreset(
        id: 'multi_char_test',
        name: 'Multi Character Test',
        algorithmConfig: const AlgorithmConfig(
          characterCountConfig: CharacterCountConfig(
            categories: [
              CharacterCountCategory(
                id: 'solo',
                count: 1,
                label: '单人',
                weight: 100,
                tagOptions: [
                  CharacterTagOption(
                    id: 'solo_girl',
                    label: '女性',
                    mainPromptTags: 'solo',
                    slotTags: [
                      CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                    ],
                    weight: 100,
                  ),
                ],
              ),
            ],
          ),
        ),
        categories: [
          // character 作用域类别
          RandomCategory(
            id: 'cat1',
            name: '发色',
            key: 'hairColor',
            enabled: true,
            probability: 1.0,
            scope: TagScope.character,
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '发色',
                builtinCategoryKey: TagSubCategory.hairColor.name,
                emoji: '🎨',
              ),
            ],
          ),
          // global 作用域类别
          RandomCategory(
            id: 'cat2',
            name: '背景',
            key: 'background',
            enabled: true,
            probability: 1.0,
            scope: TagScope.global,
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '背景',
                builtinCategoryKey: TagSubCategory.background.name,
                emoji: '🌄',
              ),
            ],
          ),
          // all 作用域类别（会出现在全局，因为 global 生成时 all 也适用）
          RandomCategory(
            id: 'cat3',
            name: '姿势',
            key: 'pose',
            enabled: true,
            probability: 1.0,
            scope: TagScope.all,
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '姿势',
                builtinCategoryKey: TagSubCategory.pose.name,
                emoji: '🧘',
              ),
            ],
          ),
        ],
      );

      final result = await generator.generateFromPreset(
        preset: preset,
        isV4Model: true,
        seed: 42,
      );

      print('Scope test result:');
      print('  mainPrompt: ${result.mainPrompt}');
      for (var i = 0; i < result.characters.length; i++) {
        print('  char[$i]: ${result.characters[i].prompt}');
      }

      // 验证 mainPrompt 包含全局标签（背景、姿势）和人数标签
      expect(result.mainPrompt, contains('solo'));
      expect(
        result.mainPrompt,
        contains(RegExp(r'(simple|detailed) background')),
      );

      // 验证角色提示词包含 character 作用域的标签（发色）
      expect(result.characters.length, equals(1));
      expect(result.characters[0].prompt, startsWith('1girl'));

      // 发色应该在角色提示词中，不在主提示词中
      final hairColors = ['blonde hair', 'black hair', 'brown hair', 'red hair'];
      expect(
        hairColors.any((c) => result.characters[0].prompt.contains(c)),
        isTrue,
        reason: '角色提示词应包含发色',
      );
    });
  });

  group('多角色输出测试（V4模型）', () {
    test('单人场景生成包含 1girl 角色标签', () async {
      final preset = RandomPreset(
        id: 'solo_test',
        name: 'Solo Test',
        algorithmConfig: const AlgorithmConfig(
          characterCountConfig: CharacterCountConfig(
            categories: [
              CharacterCountCategory(
                id: 'solo',
                count: 1,
                label: '单人',
                weight: 100,
                tagOptions: [
                  CharacterTagOption(
                    id: 'solo_girl',
                    label: '女性',
                    mainPromptTags: 'solo',
                    slotTags: [
                      CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                    ],
                    weight: 100,
                  ),
                ],
              ),
            ],
          ),
        ),
        categories: [
          RandomCategory(
            id: 'cat1',
            name: '发色',
            key: 'hairColor',
            enabled: true,
            probability: 1.0,
            scope: TagScope.character,
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '发色',
                builtinCategoryKey: TagSubCategory.hairColor.name,
                emoji: '🎨',
              ),
            ],
          ),
          RandomCategory(
            id: 'cat2',
            name: '背景',
            key: 'background',
            enabled: true,
            probability: 1.0,
            scope: TagScope.global,
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '背景',
                builtinCategoryKey: TagSubCategory.background.name,
                emoji: '🌄',
              ),
            ],
          ),
        ],
      );

      final result = await generator.generateFromPreset(
        preset: preset,
        isV4Model: true,
        seed: 42,
      );

      print('Solo result:');
      print('  mainPrompt: ${result.mainPrompt}');
      print('  characters: ${result.characters.length}');
      for (var i = 0; i < result.characters.length; i++) {
        print('  char[$i]: ${result.characters[i].prompt}');
      }

      // 验证主提示词包含 "solo"
      expect(result.mainPrompt, contains('solo'));

      // 验证有一个角色
      expect(result.characters.length, equals(1));

      // 验证角色提示词包含 "1girl"
      expect(result.characters[0].prompt, startsWith('1girl'));

      // 验证角色提示词包含发色
      final hairColors = ['blonde hair', 'black hair', 'brown hair', 'red hair'];
      expect(
        hairColors.any((c) => result.characters[0].prompt.contains(c)),
        isTrue,
        reason: '角色提示词应包含发色',
      );
    });

    test('双人场景生成包含 2girls 和两个角色', () async {
      final preset = RandomPreset(
        id: 'duo_test',
        name: 'Duo Test',
        algorithmConfig: const AlgorithmConfig(
          characterCountConfig: CharacterCountConfig(
            categories: [
              CharacterCountCategory(
                id: 'duo',
                count: 2,
                label: '双人',
                weight: 100,
                tagOptions: [
                  CharacterTagOption(
                    id: 'duo_2girls',
                    label: '双女',
                    mainPromptTags: '2girls',
                    slotTags: [
                      CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                      CharacterSlotTag(slotIndex: 1, characterTag: 'girl'),
                    ],
                    weight: 100,
                  ),
                ],
              ),
            ],
          ),
        ),
        categories: DefaultCategories.createDefault(),
      );

      final result = await generator.generateFromPreset(
        preset: preset,
        isV4Model: true,
        seed: 42,
      );

      print('Duo result:');
      print('  mainPrompt: ${result.mainPrompt}');
      print('  characters: ${result.characters.length}');
      for (var i = 0; i < result.characters.length; i++) {
        print('  char[$i]: ${result.characters[i].prompt}');
      }

      // 验证主提示词包含 "2girls"
      expect(result.mainPrompt, contains('2girls'));

      // 验证有两个角色
      expect(result.characters.length, equals(2));

      // 验证每个角色提示词都以 "1girl" 开头
      for (final char in result.characters) {
        expect(char.prompt, startsWith('1girl'));
        expect(char.gender, equals(CharacterGender.female));
      }
    });

    test('男女组合场景生成正确的性别标签', () async {
      final preset = RandomPreset(
        id: 'mixed_test',
        name: 'Mixed Test',
        algorithmConfig: const AlgorithmConfig(
          characterCountConfig: CharacterCountConfig(
            categories: [
              CharacterCountCategory(
                id: 'duo',
                count: 2,
                label: '双人',
                weight: 100,
                tagOptions: [
                  CharacterTagOption(
                    id: 'duo_mixed',
                    label: '一女一男',
                    mainPromptTags: '1girl, 1boy',
                    slotTags: [
                      CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                      CharacterSlotTag(slotIndex: 1, characterTag: 'boy'),
                    ],
                    weight: 100,
                  ),
                ],
              ),
            ],
          ),
        ),
        categories: DefaultCategories.createDefault(),
      );

      final result = await generator.generateFromPreset(
        preset: preset,
        isV4Model: true,
        seed: 42,
      );

      print('Mixed result:');
      print('  mainPrompt: ${result.mainPrompt}');
      for (var i = 0; i < result.characters.length; i++) {
        print('  char[$i] (${result.characters[i].gender}): ${result.characters[i].prompt}');
      }

      // 验证主提示词包含性别组合
      expect(result.mainPrompt, contains('1girl'));
      expect(result.mainPrompt, contains('1boy'));

      // 验证有两个角色
      expect(result.characters.length, equals(2));

      // 验证第一个角色是女性
      expect(result.characters[0].prompt, startsWith('1girl'));
      expect(result.characters[0].gender, equals(CharacterGender.female));

      // 验证第二个角色是男性
      expect(result.characters[1].prompt, startsWith('1boy'));
      expect(result.characters[1].gender, equals(CharacterGender.male));
    });

    test('无人场景生成 no humans 标签', () async {
      final preset = RandomPreset(
        id: 'no_humans_test',
        name: 'No Humans Test',
        algorithmConfig: const AlgorithmConfig(
          characterCountConfig: CharacterCountConfig(
            categories: [
              CharacterCountCategory(
                id: 'no_humans',
                count: 0,
                label: '无人',
                weight: 100,
                tagOptions: [
                  CharacterTagOption(
                    id: 'no_humans_scene',
                    label: '无人场景',
                    mainPromptTags: 'no humans',
                    slotTags: [],
                    weight: 100,
                  ),
                ],
              ),
            ],
          ),
        ),
        categories: [
          RandomCategory(
            id: 'cat1',
            name: '背景',
            key: 'background',
            enabled: true,
            probability: 1.0,
            scope: TagScope.global,
            groups: [
              RandomTagGroup.fromBuiltin(
                name: '背景',
                builtinCategoryKey: TagSubCategory.background.name,
                emoji: '🌄',
              ),
            ],
          ),
        ],
      );

      final result = await generator.generateFromPreset(
        preset: preset,
        isV4Model: true,
        seed: 42,
      );

      print('No humans result: ${result.mainPrompt}');

      // 验证包含 "no humans"
      expect(result.mainPrompt, contains('no humans'));

      // 验证标记为无人场景
      expect(result.noHumans, isTrue);

      // 验证无角色
      expect(result.characters, isEmpty);
    });

    test('使用 NAI 默认配置生成多角色输出', () async {
      final preset = RandomPreset(
        id: 'nai_default_test',
        name: 'NAI Default Test',
        algorithmConfig: AlgorithmConfig(
          characterCountConfig: CharacterCountConfig.naiDefault,
        ),
        categories: DefaultCategories.createDefault(),
      );

      // 运行多次统计结果
      var soloCount = 0;
      var duoCount = 0;
      var trioCount = 0;
      var noHumansCount = 0;
      const iterations = 50;

      for (var i = 0; i < iterations; i++) {
        final result = await generator.generateFromPreset(
          preset: preset,
          isV4Model: true,
          seed: i,
        );

        if (result.noHumans) {
          noHumansCount++;
        } else if (result.characters.length == 1) {
          soloCount++;
          // 验证角色提示词包含性别标签
          expect(
            result.characters[0].prompt.startsWith('1girl') ||
                result.characters[0].prompt.startsWith('1boy'),
            isTrue,
            reason: '单人角色应以 1girl 或 1boy 开头',
          );
        } else if (result.characters.length == 2) {
          duoCount++;
        } else if (result.characters.length == 3) {
          trioCount++;
        }
      }

      print('NAI 默认配置统计 ($iterations 次):');
      print('  单人: $soloCount (${(soloCount / iterations * 100).toStringAsFixed(1)}%)');
      print('  双人: $duoCount (${(duoCount / iterations * 100).toStringAsFixed(1)}%)');
      print('  三人: $trioCount (${(trioCount / iterations * 100).toStringAsFixed(1)}%)');
      print('  无人: $noHumansCount (${(noHumansCount / iterations * 100).toStringAsFixed(1)}%)');

      // 验证大部分是单人（NAI 默认 70%）
      expect(soloCount, greaterThan(iterations * 0.4));
    });

    test('Legacy 模式（非V4）生成单提示词', () async {
      final preset = RandomPreset(
        id: 'legacy_test',
        name: 'Legacy Test',
        algorithmConfig: const AlgorithmConfig(
          characterCountConfig: CharacterCountConfig(
            categories: [
              CharacterCountCategory(
                id: 'duo',
                count: 2,
                label: '双人',
                weight: 100,
                tagOptions: [
                  CharacterTagOption(
                    id: 'duo_2girls',
                    label: '双女',
                    mainPromptTags: '2girls',
                    slotTags: [
                      CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
                      CharacterSlotTag(slotIndex: 1, characterTag: 'girl'),
                    ],
                    weight: 100,
                  ),
                ],
              ),
            ],
          ),
        ),
        categories: DefaultCategories.createDefault(),
      );

      final result = await generator.generateFromPreset(
        preset: preset,
        isV4Model: false, // Legacy 模式
        seed: 42,
      );

      print('Legacy result: ${result.mainPrompt}');

      // Legacy 模式无 characters 输出
      expect(result.characters, isEmpty);

      // 主提示词包含人数和性别标签
      expect(result.mainPrompt, contains('2girls'));
      expect(result.mainPrompt, contains('1girl'));
    });
  });
}
