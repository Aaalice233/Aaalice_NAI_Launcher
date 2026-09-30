import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/local/pool_cache_service.dart';
import 'package:nai_launcher/data/datasources/local/tag_group_cache_service.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/character_count_config.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/diy_category_references.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/tag_category.dart';
import 'package:nai_launcher/data/models/prompt/tag_library.dart';
import 'package:nai_launcher/data/models/prompt/tag_scope.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/data/services/random_prompt_generator.dart';
import 'package:nai_launcher/data/services/sequential_state_service.dart';
import 'package:nai_launcher/data/services/tag_library_service.dart';

void main() {
  late RandomPromptGenerator generator;
  late _MockTagLibraryService libraryService;

  setUp(() {
    libraryService = _MockTagLibraryService();
    generator = RandomPromptGenerator(
      libraryService,
      _MockSequentialStateService(),
      _MockTagGroupCacheService(),
      _MockPoolCacheService(),
    );
  });

  test('generateFromPreset returns tags from the selected preset', () async {
    final preset = _preset([
      _category(
        id: 'scene',
        key: 'scene',
        groups: [
          _group(id: 'scene_group', tags: ['city']),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('city'));
  });

  test('keeps the first occurrence when generated tags overlap', () async {
    final preset = _preset([
      _category(
        id: 'detail',
        key: 'detail',
        groups: [
          _group(id: 'first', tags: ['city']),
          _group(id: 'second', tags: ['city']),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(
      result.mainPrompt.split(', ').where((tag) => tag == 'city'),
      hasLength(1),
    );
  });

  test('built-in groups generate from the verified catalog library', () async {
    when(() => libraryService.getAvailableLibrary()).thenAnswer(
      (_) async => TagLibrary(
        id: 'catalog-test',
        name: 'Catalog',
        lastUpdated: DateTime.utc(2026),
        source: TagLibrarySource.catalog,
        categories: {
          TagSubCategory.detail.name: const [
            WeightedTag(tag: 'city', weight: 10),
            WeightedTag(
              tag: 'remote only',
              weight: 10,
              source: TagSource.danbooru,
            ),
          ],
        },
      ),
    );
    final preset = _preset([
      _category(
        id: 'detail',
        key: 'detail',
        groups: [
          RandomTagGroup(
            id: 'catalog_detail',
            name: 'Detail',
            sourceType: TagGroupSourceType.builtin,
            sourceId: TagSubCategory.detail.name,
          ),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('city'));
    expect(result.mainPrompt, isNot(contains('remote only')));
    verify(() => libraryService.getAvailableLibrary()).called(1);
  });

  test('uses effective legacy character count config when new config is absent',
      () async {
    final preset = _preset(
      [
        _category(
          id: 'scene',
          key: 'scene',
          groups: [
            _group(id: 'scene_group', tags: ['city']),
          ],
        ),
      ],
      algorithmConfig: const AlgorithmConfig(
        characterCountWeights: [
          [0, 100],
          [1, 0],
          [2, 0],
          [3, 0],
          [-1, 0],
        ],
      ),
      forceNoHumanConfig: false,
    );

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.noHumans, isTrue);
    expect(result.mainPrompt, contains('no humans'));
  });

  test('applies global visibility rules using prior category context',
      () async {
    final preset = _preset(
      [
        _category(
          id: 'pose',
          key: 'pose',
          groups: [
            _group(id: 'pose_group', tags: ['portrait']),
          ],
        ),
        _category(
          id: 'lower',
          key: 'lower',
          groups: [
            _group(id: 'lower_group', tags: ['boots']),
          ],
        ),
      ],
      algorithmConfig: const AlgorithmConfig(
        characterCountConfig: _noHumanConfig,
        globalVisibilityRules: VisibilityRuleSet(
          rules: [
            VisibilityRule(
              id: 'hide_lower',
              name: 'Hide lower body',
              targetCategoryId: 'lower',
              sourceCategoryId: 'pose',
              conditionValue: 'portrait',
              visibleWhenMatched: false,
            ),
          ],
        ),
      ),
    );

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('portrait'));
    expect(result.mainPrompt, isNot(contains('boots')));
  });

  test('skips groups outside their active time condition', () async {
    final preset = _preset([
      _category(
        id: 'seasonal',
        key: 'seasonal',
        groups: [
          _group(
            id: 'christmas',
            tags: ['santa hat'],
            timeCondition: TimeCondition.christmas(),
          ),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(
      preset: preset,
      seed: 1,
      generationTime: DateTime(2026, 1, 1),
    );

    expect(result.mainPrompt, isNot(contains('santa hat')));
  });

  test('dependencies resolve category ids distinct from keys', () async {
    final preset = _preset([
      _category(
        id: 'cat-pose-id',
        key: 'pose',
        groups: [
          _group(id: 'pose_group', tags: ['portrait']),
        ],
      ),
      _category(
        id: 'cat-extra-id',
        key: 'extra',
        groups: [
          _group(
            id: 'needs_pose',
            tags: ['hat'],
            dependencyConfig: const DependencyConfig(
              type: DependencyType.exists,
              sourceCategoryId: 'cat-pose-id',
            ),
          ),
          _group(
            id: 'excluded_by_pose',
            tags: ['scarf'],
            dependencyConfig: const DependencyConfig(
              type: DependencyType.excludes,
              sourceCategoryId: 'cat-pose-id',
            ),
          ),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('hat'));
    expect(result.mainPrompt, isNot(contains('scarf')));
  });

  test('dependency config controls multiple selection count', () async {
    final preset = _preset([
      _category(
        id: 'accessory',
        key: 'accessory',
        groups: [
          _group(
            id: 'accessory_group',
            tags: ['ribbon', 'hat', 'necklace'],
            selectionMode: SelectionMode.multipleNum,
            multipleNum: 3,
            dependencyConfig: const DependencyConfig(
              sourceCategoryId: 'character_count',
              mappingRules: {'0': '2'},
            ),
          ),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    final tags = result.mainPrompt.split(',').map((tag) => tag.trim()).toList();
    expect(
      tags.where((tag) => ['ribbon', 'hat', 'necklace'].contains(tag)),
      hasLength(2),
    );
  });

  test('conditional branch selects configured child group', () async {
    final preset = _preset([
      _category(
        id: 'clothing',
        key: 'clothing',
        groups: [
          RandomTagGroup(
            id: 'branch_parent',
            name: 'Branch',
            nodeType: TagGroupNodeType.config,
            conditionalBranchConfig: const ConditionalBranchConfig(
              id: 'branch',
              name: 'Branch',
              branches: [
                ConditionalBranch(
                  name: 'uniform',
                  probability: 100,
                  tagGroupIds: ['uniform_child'],
                ),
              ],
            ),
            children: [
              _group(id: 'uniform_child', tags: ['school uniform']),
              _group(id: 'casual_child', tags: ['hoodie']),
            ],
          ),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('school uniform'));
    expect(result.mainPrompt, isNot(contains('hoodie')));
  });

  test('group post-process rules remove conflicting selected tags', () async {
    final preset = _preset([
      _category(
        id: 'face',
        key: 'face',
        groups: [
          _group(
            id: 'face_group',
            tags: ['sleeping', 'blue eyes'],
            selectionMode: SelectionMode.all,
            postProcessRules: const [
              PostProcessRule(
                id: 'sleeping_eye',
                name: 'Sleeping eye',
                triggerTags: ['sleeping'],
                action: PostProcessAction.remove,
                targetTags: ['blue eyes'],
              ),
            ],
          ),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('sleeping'));
    expect(result.mainPrompt, isNot(contains('blue eyes')));
  });

  test('group emphasis probability wraps selected tags', () async {
    final preset = _preset([
      _category(
        id: 'style',
        key: 'style',
        groups: [
          _group(
            id: 'style_group',
            tags: ['sparkle'],
            emphasisProbability: 1,
            emphasisBracketCount: 1,
          ),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('{sparkle}'));
  });

  test('global emphasis probability wraps preset route tags', () async {
    final preset = _preset(
      [
        _category(
          id: 'style',
          key: 'style',
          groups: [
            _group(id: 'style_group', tags: ['sparkle']),
          ],
        ),
      ],
      algorithmConfig: const AlgorithmConfig(
        characterCountConfig: _noHumanConfig,
        globalEmphasisProbability: 1,
        globalEmphasisBracketCount: 1,
      ),
      forceNoHumanConfig: false,
    );

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('{sparkle}'));
  });

  test('character contexts do not leak gender variables between slots',
      () async {
    final preset = _preset(
      [
        _category(
          id: 'character_detail',
          key: 'character_detail',
          scope: TagScope.character,
          groups: [
            RandomTagGroup(
              id: 'gender_branch',
              name: 'Gender Branch',
              tags: [
                WeightedTag.simple('fallback detail', 10, TagSource.custom),
              ],
              conditionalBranchConfig: const ConditionalBranchConfig(
                id: 'gender_branch',
                name: 'Gender Branch',
                branches: [
                  ConditionalBranch(
                    name: 'girl branch',
                    probability: 100,
                    tagGroupIds: ['girl_child'],
                    conditions: {'character_gender': 'girl'},
                  ),
                  ConditionalBranch(
                    name: 'boy branch',
                    probability: 100,
                    tagGroupIds: ['boy_child'],
                    conditions: {'character_gender': 'boy'},
                  ),
                ],
              ),
              children: [
                _group(id: 'girl_child', tags: ['girl detail']),
                _group(id: 'boy_child', tags: ['boy detail']),
              ],
            ),
          ],
        ),
      ],
      algorithmConfig: const AlgorithmConfig(
        characterCountConfig: _duoGirlBoyConfig,
      ),
      forceNoHumanConfig: false,
    );

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.characters, hasLength(2));
    expect(result.characters[0].prompt, contains('girl detail'));
    expect(result.characters[0].prompt, isNot(contains('boy detail')));
    expect(result.characters[1].prompt, contains('boy detail'));
    expect(result.characters[1].prompt, isNot(contains('girl detail')));
  });

  test('global post-process removals stop triggering later visibility rules',
      () async {
    final preset = _preset(
      [
        _category(
          id: 'state',
          key: 'state',
          groups: [
            _group(id: 'state_group', tags: ['sleeping']),
          ],
        ),
        _category(
          id: 'eyes',
          key: 'eyes',
          scope: TagScope.character,
          groups: [
            _group(id: 'eyes_group', tags: ['blue eyes']),
          ],
        ),
      ],
      algorithmConfig: const AlgorithmConfig(
        characterCountConfig: _soloGirlConfig,
        globalPostProcessRules: PostProcessRuleSet(
          rules: [
            PostProcessRule(
              id: 'remove_sleeping',
              name: 'Remove sleeping',
              triggerTags: ['sleeping'],
              action: PostProcessAction.remove,
              targetTags: ['sleeping'],
            ),
          ],
        ),
        globalVisibilityRules: VisibilityRuleSet(
          rules: [
            VisibilityRule(
              id: 'eyes_when_sleeping',
              name: 'Eyes when sleeping',
              targetCategoryId: 'eyes',
              sourceCategoryId: 'state',
              conditionValue: 'sleeping',
              visibleWhenMatched: false,
            ),
          ],
        ),
      ),
      forceNoHumanConfig: false,
    );

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, isNot(contains('sleeping')));
    expect(result.characters.single.prompt, contains('blue eyes'));
  });

  test('disabled conditional branch config falls back to normal group tags',
      () async {
    final preset = _preset([
      _category(
        id: 'clothing',
        key: 'clothing',
        groups: [
          RandomTagGroup(
            id: 'branch_parent',
            name: 'Branch',
            selectionMode: SelectionMode.all,
            shuffle: false,
            tags: [
              WeightedTag.simple('plain clothes', 10, TagSource.custom),
            ],
            conditionalBranchConfig: const ConditionalBranchConfig(
              id: 'branch',
              name: 'Branch',
              enabled: false,
              branches: [
                ConditionalBranch(
                  name: 'uniform',
                  probability: 100,
                  tagGroupIds: ['uniform_child'],
                ),
              ],
            ),
            children: [
              _group(id: 'uniform_child', tags: ['school uniform']),
            ],
          ),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('plain clothes'));
    expect(result.mainPrompt, isNot(contains('school uniform')));
  });

  group('词组上的可见性规则', () {
    VisibilityRule hideLowerWhen(
      String tag, {
      String source = 'cat-pose',
      String target = 'cat-lower',
    }) => VisibilityRule(
      id: 'hide_lower',
      name: 'Hide lower',
      sourceCategoryId: source,
      targetCategoryId: target,
      conditionValue: tag,
      visibleWhenMatched: false,
    );

    RandomPreset lowerBodyPreset({
      required String pose,
      required List<VisibilityRule> ownerRules,
      bool ownerEnabled = true,
      List<VisibilityRule> shoesRules = const [],
    }) => _preset([
      _category(
        id: 'cat-pose',
        key: 'pose',
        name: '姿势',
        groups: [
          _group(id: 'pose_group', tags: [pose]),
        ],
      ),
      _category(
        id: 'cat-lower',
        key: 'lower',
        name: '下装',
        groups: [
          _group(id: 'shoes', tags: ['boots'], visibilityRules: shoesRules),
          _group(id: 'pants', tags: ['jeans']),
        ],
      ),
      _category(
        id: 'cat-extra',
        key: 'extra',
        groups: [
          _group(
            id: 'owner',
            tags: ['smile'],
            enabled: ownerEnabled,
            visibilityRules: ownerRules,
          ),
        ],
      ),
    ]);

    test('目标为类别时作用于该类别下全部词组', () async {
      final result = await generator.generateFromPreset(
        preset: lowerBodyPreset(
          pose: 'portrait',
          ownerRules: [hideLowerWhen('portrait')],
        ),
        seed: 1,
      );

      final tags = _promptTags(result.mainPrompt);
      expect(tags, containsAll(['portrait', 'smile']));
      expect(tags, isNot(contains('boots')));
      expect(tags, isNot(contains('jeans')));
    });

    test('条件标签被强调括号包裹、用户输入下划线时仍然命中', () async {
      final preset = _preset([
        _category(
          id: 'cat-pose',
          key: 'pose',
          groups: [
            _group(
              id: 'pose_group',
              tags: ['full body'],
              emphasisProbability: 1,
            ),
          ],
        ),
        _category(
          id: 'cat-lower',
          key: 'lower',
          groups: [
            _group(id: 'shoes', tags: ['boots']),
          ],
        ),
        _category(
          id: 'cat-extra',
          key: 'extra',
          groups: [
            _group(
              id: 'owner',
              tags: ['smile'],
              visibilityRules: [hideLowerWhen('Full_Body')],
            ),
          ],
        ),
      ]);

      final result = await generator.generateFromPreset(
        preset: preset,
        seed: 1,
      );

      final tags = _promptTags(result.mainPrompt);
      expect(tags, contains('{full body}'));
      expect(tags, isNot(contains('boots')));
    });

    test('条件不成立时目标类别照常生成', () async {
      final result = await generator.generateFromPreset(
        preset: lowerBodyPreset(
          pose: 'full body',
          ownerRules: [hideLowerWhen('portrait')],
        ),
        seed: 1,
      );

      expect(
        _promptTags(result.mainPrompt),
        containsAll(['full body', 'boots', 'jeans', 'smile']),
      );
    });

    test('按类别名称或键名保存的存量引用在生成时同样生效', () async {
      final result = await generator.generateFromPreset(
        preset: lowerBodyPreset(
          pose: 'portrait',
          ownerRules: [hideLowerWhen('portrait', source: 'pose', target: '下装')],
        ),
        seed: 1,
      );

      final tags = _promptTags(result.mainPrompt);
      expect(tags, isNot(contains('boots')));
      expect(tags, isNot(contains('jeans')));
    });

    test('默认的"条件匹配时可见"只在条件成立时生成目标', () async {
      VisibilityRule showLowerWhenFullBody() => const VisibilityRule(
        id: 'show_lower',
        name: 'Show lower',
        sourceCategoryId: 'cat-pose',
        targetCategoryId: 'cat-lower',
        conditionValue: 'full body',
      );

      final portrait = await generator.generateFromPreset(
        preset: lowerBodyPreset(
          pose: 'portrait',
          ownerRules: [showLowerWhenFullBody()],
        ),
        seed: 1,
      );
      final fullBody = await generator.generateFromPreset(
        preset: lowerBodyPreset(
          pose: 'full body',
          ownerRules: [showLowerWhenFullBody()],
        ),
        seed: 1,
      );

      expect(_promptTags(portrait.mainPrompt), isNot(contains('boots')));
      expect(_promptTags(portrait.mainPrompt), isNot(contains('jeans')));
      expect(_promptTags(fullBody.mainPrompt), containsAll(['boots', 'jeans']));
    });

    test('以本词组 ID 为目标的存量规则仍只控制该词组', () async {
      final result = await generator.generateFromPreset(
        preset: lowerBodyPreset(
          pose: 'portrait',
          ownerRules: const [],
          shoesRules: [hideLowerWhen('portrait', target: 'shoes')],
        ),
        seed: 1,
      );

      final tags = _promptTags(result.mainPrompt);
      expect(tags, isNot(contains('boots')));
      expect(tags, contains('jeans'));
    });

    test('停用的词组不再施加它的类别规则', () async {
      final result = await generator.generateFromPreset(
        preset: lowerBodyPreset(
          pose: 'portrait',
          ownerRules: [hideLowerWhen('portrait')],
          ownerEnabled: false,
        ),
        seed: 1,
      );

      expect(_promptTags(result.mainPrompt), containsAll(['boots', 'jeans']));
    });
  });

  group('词组上的后处理规则', () {
    RandomPreset sleepingPreset({
      required List<String> poseTags,
      required List<String> eyeFeatureTags,
      required PostProcessRule rule,
      bool ownerEnabled = true,
    }) => _preset([
      _category(
        id: 'cat-eyes',
        key: 'eyeColor',
        name: '眼睛',
        groups: [
          _group(id: 'eye_color', tags: ['blue eyes']),
          _group(id: 'eye_feature', tags: eyeFeatureTags),
        ],
      ),
      _category(
        id: 'cat-pose',
        key: 'pose',
        groups: [
          _group(
            id: 'pose_group',
            tags: poseTags,
            enabled: ownerEnabled,
            postProcessRules: [rule],
          ),
          _group(id: 'pose_extra', tags: ['arms up']),
        ],
      ),
    ]);

    test('睡眠预设移除其他类别里的瞳色', () async {
      final result = await generator.generateFromPreset(
        preset: sleepingPreset(
          poseTags: ['sleeping'],
          eyeFeatureTags: const [],
          rule: PostProcessRule.sleepingRule(targetCategoryIds: ['cat-eyes']),
        ),
        seed: 1,
      );

      final tags = _promptTags(result.mainPrompt);
      expect(tags, contains('sleeping'));
      expect(tags, isNot(contains('blue eyes')));
    });

    test('触发标签本身属于目标类别时保留，只移除同类的其他标签', () async {
      final result = await generator.generateFromPreset(
        preset: sleepingPreset(
          poseTags: ['standing'],
          eyeFeatureTags: ['closed eyes'],
          rule: PostProcessRule.sleepingRule(targetCategoryIds: ['cat-eyes']),
        ),
        seed: 1,
      );

      final tags = _promptTags(result.mainPrompt);
      expect(tags, contains('closed eyes'));
      expect(tags, isNot(contains('blue eyes')));
    });

    test('按类别键名保存的存量目标同样生效，且不触发时不改动结果', () async {
      final legacyRule = PostProcessRule.sleepingRule(
        targetCategoryIds: ['eyeColor'],
      );
      final sleeping = await generator.generateFromPreset(
        preset: sleepingPreset(
          poseTags: ['sleeping'],
          eyeFeatureTags: const [],
          rule: legacyRule,
        ),
        seed: 1,
      );
      final awake = await generator.generateFromPreset(
        preset: sleepingPreset(
          poseTags: ['standing'],
          eyeFeatureTags: const [],
          rule: legacyRule,
        ),
        seed: 1,
      );

      expect(_promptTags(sleeping.mainPrompt), isNot(contains('blue eyes')));
      expect(
        _promptTags(awake.mainPrompt),
        containsAll(['standing', 'blue eyes', 'arms up']),
      );
    });

    test('停用的词组不再施加它的后处理规则', () async {
      final result = await generator.generateFromPreset(
        preset: sleepingPreset(
          poseTags: ['sleeping'],
          eyeFeatureTags: ['closed eyes'],
          rule: PostProcessRule.sleepingRule(targetCategoryIds: ['cat-eyes']),
          ownerEnabled: false,
        ),
        seed: 1,
      );

      expect(
        _promptTags(result.mainPrompt),
        containsAll(['blue eyes', 'closed eyes']),
      );
    });

    test('美人鱼规则移除用户选定的腿部服装类别', () async {
      final preset = _preset([
        _category(
          id: 'cat-species',
          key: 'species',
          groups: [
            _group(
              id: 'species_group',
              tags: ['mermaid'],
              postProcessRules: [
                PostProcessRule.mermaidRule(targetCategoryIds: ['cat-legwear']),
              ],
            ),
          ],
        ),
        _category(
          id: 'cat-legwear',
          key: 'custom3',
          groups: [
            _group(id: 'legwear', tags: ['thighhighs']),
          ],
        ),
        _category(
          id: 'cat-top',
          key: 'custom4',
          groups: [
            _group(id: 'top', tags: ['seashell bra']),
          ],
        ),
      ]);

      final result = await generator.generateFromPreset(
        preset: preset,
        seed: 1,
      );

      final tags = _promptTags(result.mainPrompt);
      expect(tags, containsAll(['mermaid', 'seashell bra']));
      expect(tags, isNot(contains('thighhighs')));
    });
  });

  group('依赖配置', () {
    RandomPreset characterCountPreset(CharacterCountConfig countConfig) =>
        _preset(
          [
            _category(
              id: 'cat-scene',
              key: 'scene',
              groups: [
                _group(
                  id: 'with_people',
                  tags: ['crowd'],
                  dependencyConfig: const DependencyConfig(
                    type: DependencyType.exists,
                    sourceCategoryId: characterCountReference,
                  ),
                ),
                _group(
                  id: 'empty_scene',
                  tags: ['scenery'],
                  dependencyConfig: const DependencyConfig(
                    type: DependencyType.excludes,
                    sourceCategoryId: characterCountReference,
                  ),
                ),
              ],
            ),
          ],
          algorithmConfig: AlgorithmConfig(characterCountConfig: countConfig),
          forceNoHumanConfig: false,
        );

    test('角色数量源：存在依赖只在有角色时生成，排斥依赖只在无人时生成', () async {
      final solo = await generator.generateFromPreset(
        preset: characterCountPreset(_soloGirlConfig),
        seed: 1,
      );
      final noHumans = await generator.generateFromPreset(
        preset: characterCountPreset(_noHumanConfig),
        seed: 1,
      );

      expect(_promptTags(solo.mainPrompt), contains('crowd'));
      expect(_promptTags(solo.mainPrompt), isNot(contains('scenery')));
      expect(_promptTags(noHumans.mainPrompt), contains('scenery'));
      expect(_promptTags(noHumans.mainPrompt), isNot(contains('crowd')));
    });

    test('存在依赖满足时保留词组自己的多选数量', () async {
      final preset = _preset([
        _category(
          id: 'cat-pose',
          key: 'pose',
          groups: [
            _group(id: 'pose_group', tags: ['standing']),
          ],
        ),
        _category(
          id: 'cat-accessory',
          key: 'accessory',
          groups: [
            _group(
              id: 'accessories',
              tags: ['ribbon', 'hat', 'necklace'],
              selectionMode: SelectionMode.multipleNum,
              multipleNum: 2,
              dependencyConfig: const DependencyConfig(
                type: DependencyType.exists,
                sourceCategoryId: 'cat-pose',
              ),
            ),
          ],
        ),
      ]);

      final result = await generator.generateFromPreset(
        preset: preset,
        seed: 1,
      );

      expect(
        _promptTags(
          result.mainPrompt,
        ).where((tag) => ['ribbon', 'hat', 'necklace'].contains(tag)),
        hasLength(2),
      );
    });

    RandomPreset dependentAccessoryPreset({
      required List<String> expressionTags,
      required DependencyConfig dependency,
    }) => _preset([
      _category(
        id: 'cat-expression',
        key: 'expression',
        groups: [_group(id: 'expression_group', tags: expressionTags)],
      ),
      _category(
        id: 'cat-accessory',
        key: 'accessory',
        groups: [
          _group(
            id: 'accessories',
            tags: ['ribbon', 'hat', 'necklace'],
            selectionMode: SelectionMode.multipleNum,
            multipleNum: 3,
            dependencyConfig: dependency,
          ),
        ],
      ),
    ]);

    int accessoryCount(RandomPromptResult result) => _promptTags(
      result.mainPrompt,
    ).where((tag) => ['ribbon', 'hat', 'necklace'].contains(tag)).length;

    test('数量依赖以类别源的已选标签数查映射', () async {
      final result = await generator.generateFromPreset(
        preset: dependentAccessoryPreset(
          expressionTags: ['smile', 'blush'],
          dependency: const DependencyConfig(
            sourceCategoryId: 'cat-expression',
            mappingRules: {'2': '1'},
          ),
        ),
        seed: 1,
      );

      expect(accessoryCount(result), 1);
    });

    test('存量的数量依赖按标签名映射时仍按已选标签生效', () async {
      final result = await generator.generateFromPreset(
        preset: dependentAccessoryPreset(
          expressionTags: ['smile'],
          dependency: const DependencyConfig(
            sourceCategoryId: 'cat-expression',
            mappingRules: {'smile': '2'},
          ),
        ),
        seed: 1,
      );

      expect(accessoryCount(result), 2);
    });

    test('值依赖匹配类别源的任一已选标签', () async {
      final result = await generator.generateFromPreset(
        preset: dependentAccessoryPreset(
          expressionTags: ['smile', 'blush'],
          dependency: const DependencyConfig(
            type: DependencyType.value,
            sourceCategoryId: 'cat-expression',
            mappingRules: {'blush': '2'},
          ),
        ),
        seed: 1,
      );

      expect(accessoryCount(result), 2);
    });
  });
}

class _MockTagLibraryService extends Mock implements TagLibraryService {}

class _MockSequentialStateService extends Mock
    implements SequentialStateService {
  @override
  Future<void> init() async {}
}

class _MockTagGroupCacheService extends Mock implements TagGroupCacheService {}

class _MockPoolCacheService extends Mock implements PoolCacheService {}

RandomPreset _preset(
  List<RandomCategory> categories, {
  AlgorithmConfig algorithmConfig = const AlgorithmConfig(),
  bool forceNoHumanConfig = true,
}) {
  return RandomPreset(
    id: 'preset',
    name: 'Preset',
    algorithmConfig:
        forceNoHumanConfig && algorithmConfig.characterCountConfig == null
            ? algorithmConfig.copyWith(characterCountConfig: _noHumanConfig)
            : algorithmConfig,
    categories: categories,
  );
}

RandomCategory _category({
  required String id,
  required String key,
  required List<RandomTagGroup> groups,
  String? name,
  TagScope scope = TagScope.global,
}) {
  return RandomCategory(
    id: id,
    key: key,
    name: name ?? key,
    groupSelectionMode: SelectionMode.all,
    shuffle: false,
    scope: scope,
    groups: groups,
  );
}

RandomTagGroup _group({
  required String id,
  List<String> tags = const [],
  bool enabled = true,
  SelectionMode selectionMode = SelectionMode.all,
  int multipleNum = 1,
  DependencyConfig? dependencyConfig,
  TimeCondition? timeCondition,
  List<VisibilityRule> visibilityRules = const [],
  List<PostProcessRule> postProcessRules = const [],
  double emphasisProbability = 0,
  int emphasisBracketCount = 1,
}) {
  return RandomTagGroup(
    id: id,
    name: id,
    enabled: enabled,
    selectionMode: selectionMode,
    multipleNum: multipleNum,
    shuffle: false,
    tags: tags
        .map((tag) => WeightedTag.simple(tag, 10, TagSource.custom))
        .toList(),
    dependencyConfig: dependencyConfig,
    timeCondition: timeCondition,
    visibilityRules: visibilityRules,
    postProcessRules: postProcessRules,
    emphasisProbability: emphasisProbability,
    emphasisBracketCount: emphasisBracketCount,
  );
}

List<String> _promptTags(String prompt) =>
    prompt.split(',').map((tag) => tag.trim()).toList();

const _noHumanConfig = CharacterCountConfig(
  categories: [
    CharacterCountCategory(
      id: 'no_humans',
      count: 0,
      label: 'No humans',
      weight: 100,
      tagOptions: [
        CharacterTagOption(
          id: 'no_humans_scene',
          label: 'No humans',
          mainPromptTags: 'no humans',
          weight: 100,
        ),
      ],
    ),
  ],
);

const _soloGirlConfig = CharacterCountConfig(
  categories: [
    CharacterCountCategory(
      id: 'solo',
      count: 1,
      label: 'Solo',
      weight: 100,
      tagOptions: [
        CharacterTagOption(
          id: 'solo_girl',
          label: 'Solo girl',
          mainPromptTags: 'solo',
          weight: 100,
          slotTags: [
            CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
          ],
        ),
      ],
    ),
  ],
);

const _duoGirlBoyConfig = CharacterCountConfig(
  categories: [
    CharacterCountCategory(
      id: 'duo',
      count: 2,
      label: 'Duo',
      weight: 100,
      tagOptions: [
        CharacterTagOption(
          id: 'duo_girl_boy',
          label: 'Girl and boy',
          mainPromptTags: '1girl, 1boy',
          weight: 100,
          slotTags: [
            CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
            CharacterSlotTag(slotIndex: 1, characterTag: 'boy'),
          ],
        ),
      ],
    ),
  ],
);
