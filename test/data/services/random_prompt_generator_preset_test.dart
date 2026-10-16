import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/character_count_config.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/diy_category_references.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
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

import '../../helpers/random_preset_generator_fixture.dart';

void main() {
  late RandomPromptGenerator generator;
  late MockTagLibraryService libraryService;

  setUp(() {
    libraryService = MockTagLibraryService();
    generator = createTestGenerator(libraryService: libraryService);
  });

  test('generateFromPreset returns tags from the selected preset', () async {
    final preset = testPreset([
      testCategory(
        id: 'scene',
        key: 'scene',
        groups: [
          testGroup(id: 'scene_group', tags: ['city']),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('city'));
  });

  test('keeps the first occurrence when generated tags overlap', () async {
    final preset = testPreset([
      testCategory(
        id: 'detail',
        key: 'detail',
        groups: [
          testGroup(id: 'first', tags: ['city']),
          testGroup(id: 'second', tags: ['city']),
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
    final preset = testPreset([
      testCategory(
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
    final preset = testPreset(
      [
        testCategory(
          id: 'scene',
          key: 'scene',
          groups: [
            testGroup(id: 'scene_group', tags: ['city']),
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
    final preset = testPreset(
      [
        testCategory(
          id: 'pose',
          key: 'pose',
          groups: [
            testGroup(id: 'pose_group', tags: ['portrait']),
          ],
        ),
        testCategory(
          id: 'lower',
          key: 'lower',
          groups: [
            testGroup(id: 'lower_group', tags: ['boots']),
          ],
        ),
      ],
      algorithmConfig: const AlgorithmConfig(
        characterCountConfig: noHumanCountConfig,
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
    final preset = testPreset([
      testCategory(
        id: 'seasonal',
        key: 'seasonal',
        groups: [
          testGroup(
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

  test('停用的时间条件不限制词组，关闭每年重复后只在所选年份生效', () async {
    final preset = testPreset([
      testCategory(
        id: 'seasonal',
        key: 'seasonal',
        groups: [
          testGroup(
            id: 'disabled',
            tags: ['santa hat'],
            timeCondition: TimeCondition.christmas().copyWith(enabled: false),
          ),
          testGroup(
            id: 'only_2026',
            tags: ['snowman'],
            timeCondition: TimeCondition.christmas().copyWith(
              recurring: false,
              specificYear: 2026,
            ),
          ),
        ],
      ),
    ]);

    Future<List<String>> tagsAt(DateTime time) async => _promptTags(
      (await generator.generateFromPreset(
        preset: preset,
        seed: 1,
        generationTime: time,
      )).mainPrompt,
    );

    final january = await tagsAt(DateTime(2026, 1, 1));
    expect(january, contains('santa hat'));
    expect(january, isNot(contains('snowman')));
    expect(await tagsAt(DateTime(2026, 12, 25)), contains('snowman'));
    expect(await tagsAt(DateTime(2027, 12, 25)), isNot(contains('snowman')));
  });

  test('变量展开得到的标签同样受按类别与按标签的后处理规则约束', () async {
    final preset = testPreset(
      [
        testCategory(
          id: 'palette-id',
          key: 'palette',
          groups: [
            testGroup(id: 'eye_color', tags: ['blue eyes']),
          ],
        ).copyWith(enabled: false),
        testCategory(
          id: 'accents-id',
          key: 'accents',
          groups: [
            testGroup(id: 'accent', tags: ['red ribbon', 'star earrings']),
          ],
        ).copyWith(enabled: false),
        testCategory(
          id: 'look',
          key: 'look',
          groups: [
            testGroup(id: 'look_group', tags: ['__palette__', '__accent__']),
            testGroup(id: 'state_group', tags: ['sleeping']),
          ],
        ),
      ],
      algorithmConfig: const AlgorithmConfig(
        globalPostProcessRules: PostProcessRuleSet(
          rules: [
            PostProcessRule(
              id: 'sleeping_hides_palette',
              name: 'Sleeping hides palette',
              triggerTags: ['sleeping'],
              action: PostProcessAction.removeCategory,
              targetCategoryIds: ['palette-id'],
            ),
            PostProcessRule(
              id: 'sleeping_drops_earrings',
              name: 'Sleeping drops earrings',
              triggerTags: ['sleeping'],
              targetTags: ['star_earrings'],
            ),
          ],
        ),
      ),
    );

    final result = await generator.generateFromPreset(preset: preset, seed: 1);
    final tags = _promptTags(result.mainPrompt);

    expect(tags, containsAll(['sleeping', 'red ribbon']));
    expect(tags, isNot(contains('blue eyes')));
    expect(tags, isNot(contains('star earrings')));
    expect(result.mainPrompt, isNot(contains('__')));
  });

  test('变量在本轮生成的时间下展开', () async {
    final preset = testPreset([
      testCategory(
        id: 'seasonal',
        key: 'seasonal',
        groups: [
          testGroup(
            id: 'christmas',
            tags: ['santa hat'],
            timeCondition: TimeCondition.christmas(),
          ),
        ],
      ).copyWith(enabled: false),
      testCategory(
        id: 'look',
        key: 'look',
        groups: [
          testGroup(id: 'look_group', tags: ['__seasonal__', 'smile']),
        ],
      ),
    ]);

    Future<List<String>> tagsAt(DateTime time) async => _promptTags(
      (await generator.generateFromPreset(
        preset: preset,
        seed: 1,
        generationTime: time,
      )).mainPrompt,
    );

    expect(await tagsAt(DateTime(2026, 12, 24)), contains('santa hat'));
    final summer = await tagsAt(DateTime(2026, 7, 1));
    expect(summer, contains('smile'));
    expect(summer, isNot(contains('santa hat')));
    expect(summer.where((tag) => tag.contains('__')), isEmpty);
  });

  test('dependencies resolve category ids distinct from keys', () async {
    final preset = testPreset([
      testCategory(
        id: 'cat-pose-id',
        key: 'pose',
        groups: [
          testGroup(id: 'pose_group', tags: ['portrait']),
        ],
      ),
      testCategory(
        id: 'cat-extra-id',
        key: 'extra',
        groups: [
          testGroup(
            id: 'needs_pose',
            tags: ['hat'],
            dependencyConfig: const DependencyConfig(
              type: DependencyType.exists,
              sourceCategoryId: 'cat-pose-id',
            ),
          ),
          testGroup(
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
    final preset = testPreset([
      testCategory(
        id: 'accessory',
        key: 'accessory',
        groups: [
          testGroup(
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
    final preset = testPreset([
      testCategory(
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
              testGroup(id: 'uniform_child', tags: ['school uniform']),
              testGroup(id: 'casual_child', tags: ['hoodie']),
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
    final preset = testPreset([
      testCategory(
        id: 'face',
        key: 'face',
        groups: [
          testGroup(
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
    final preset = testPreset([
      testCategory(
        id: 'style',
        key: 'style',
        groups: [
          testGroup(
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
    final preset = testPreset(
      [
        testCategory(
          id: 'style',
          key: 'style',
          groups: [
            testGroup(id: 'style_group', tags: ['sparkle']),
          ],
        ),
      ],
      algorithmConfig: const AlgorithmConfig(
        characterCountConfig: noHumanCountConfig,
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
    final preset = testPreset(
      [
        testCategory(
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
                testGroup(id: 'girl_child', tags: ['girl detail']),
                testGroup(id: 'boy_child', tags: ['boy detail']),
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

  group('角色性别', () {
    RandomTagGroup onlyFor(String gender, String id, String tag) => testGroup(
      id: id,
      tags: [tag],
    ).copyWith(genderRestrictionEnabled: true, applicableGenders: [gender]);

    test('无槽位配置的单角色按 girl 筛选类别与顶层词组', () async {
      final preset = testPreset(
        [
          testCategory(
            id: 'looks',
            key: 'looks',
            scope: TagScope.character,
            groups: [
              onlyFor('girl', 'girls', 'ribbon'),
              onlyFor('boy', 'boys', 'necktie'),
            ],
          ),
          testCategory(
            id: 'beard',
            key: 'beard',
            scope: TagScope.character,
            groups: [
              testGroup(id: 'beard_group', tags: ['beard']),
            ],
          ).copyWith(
            genderRestrictionEnabled: true,
            applicableGenders: const ['boy'],
          ),
        ],
        algorithmConfig: const AlgorithmConfig(
          characterCountConfig: CharacterCountConfig(
            categories: [
              CharacterCountCategory(
                id: 'solo',
                count: 1,
                label: 'Solo',
                weight: 100,
              ),
            ],
          ),
        ),
        forceNoHumanConfig: false,
      );

      final result = await generator.generateFromPreset(
        preset: preset,
        seed: 1,
      );
      final tags = _promptTags(result.characters.single.prompt);

      expect(tags, contains('ribbon'));
      expect(tags, isNot(anyOf(contains('necktie'), contains('beard'))));
    });

    test('角色提示词里的变量按该角色性别展开', () async {
      final preset = testPreset(
        [
          testCategory(
            id: 'accessories',
            key: 'accessories',
            scope: TagScope.character,
            groups: [
              onlyFor('girl', 'girls', 'ribbon'),
              onlyFor('boy', 'boys', 'necktie'),
            ],
          ).copyWith(enabled: false),
          testCategory(
            id: 'look',
            key: 'look',
            scope: TagScope.character,
            groups: [
              testGroup(id: 'look_group', tags: ['__accessories__']),
            ],
          ),
        ],
        algorithmConfig: const AlgorithmConfig(
          characterCountConfig: _soloGirlConfig,
        ),
        forceNoHumanConfig: false,
      );

      final result = await generator.generateFromPreset(
        preset: preset,
        seed: 1,
      );
      final tags = _promptTags(result.characters.single.prompt);

      expect(tags, contains('ribbon'));
      expect(tags, isNot(contains('necktie')));
    });
  });

  test('global post-process removals stop triggering later visibility rules',
      () async {
    final preset = testPreset(
      [
        testCategory(
          id: 'state',
          key: 'state',
          groups: [
            testGroup(id: 'state_group', tags: ['sleeping']),
          ],
        ),
        testCategory(
          id: 'eyes',
          key: 'eyes',
          scope: TagScope.character,
          groups: [
            testGroup(id: 'eyes_group', tags: ['blue eyes']),
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

  test('子词组与顶层词组一样求值时间、可见性、依赖与性别', () async {
    final preset = testPreset(
      [
        testCategory(
          id: 'pose',
          key: 'pose',
          groups: [
            testGroup(id: 'pose_group', tags: ['portrait']),
          ],
        ),
        testCategory(
          id: 'outfit',
          key: 'outfit',
          scope: TagScope.character,
          groups: [
            testGroup(id: 'outfit_parent').copyWith(
              nodeType: TagGroupNodeType.config,
              children: [
                testGroup(id: 'plain', tags: ['shirt']),
                testGroup(
                  id: 'seasonal',
                  tags: ['santa hat'],
                  timeCondition: TimeCondition.christmas(),
                ),
                testGroup(
                  id: 'hidden_in_portrait',
                  tags: ['boots'],
                  visibilityRules: const [
                    VisibilityRule(
                      id: 'hide_boots',
                      name: 'Hide boots',
                      targetCategoryId: 'hidden_in_portrait',
                      sourceCategoryId: 'pose',
                      conditionValue: 'portrait',
                      visibleWhenMatched: false,
                    ),
                  ],
                ),
                testGroup(
                  id: 'needs_missing',
                  tags: ['cape'],
                  dependencyConfig: const DependencyConfig(
                    type: DependencyType.exists,
                    sourceCategoryId: 'missing',
                  ),
                ),
                testGroup(id: 'boys_only', tags: ['necktie']).copyWith(
                  genderRestrictionEnabled: true,
                  applicableGenders: const ['boy'],
                ),
                testGroup(
                  id: 'two_by_pose',
                  tags: ['gloves', 'scarf', 'belt'],
                  selectionMode: SelectionMode.multipleNum,
                  dependencyConfig: const DependencyConfig(
                    sourceCategoryId: 'pose',
                    mappingRules: {'1': '2'},
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      algorithmConfig: const AlgorithmConfig(
        characterCountConfig: _soloGirlConfig,
      ),
      forceNoHumanConfig: false,
    );

    final result = await generator.generateFromPreset(
      preset: preset,
      seed: 1,
      generationTime: DateTime(2026, 6, 1),
    );
    final tags = _promptTags(result.characters.single.prompt);

    expect(tags, contains('shirt'));
    expect(
      tags,
      isNot(anyOf(contains('santa hat'), contains('boots'), contains('cape'))),
    );
    expect(tags, isNot(contains('necktie')));
    expect(
      tags.where(const {'gloves', 'scarf', 'belt'}.contains),
      hasLength(2),
    );
  });

  test('子词组上以类别为目标的可见性规则作用于目标类别', () async {
    final preset = testPreset([
      testCategory(
        id: 'mood',
        key: 'mood',
        groups: [
          testGroup(id: 'mood_parent').copyWith(
            nodeType: TagGroupNodeType.config,
            children: [
              testGroup(
                id: 'sleepy',
                tags: ['sleeping'],
                visibilityRules: const [
                  VisibilityRule(
                    id: 'hide_eyes',
                    name: 'Hide eyes',
                    targetCategoryId: 'eyes',
                    sourceCategoryId: 'mood',
                    conditionValue: 'sleeping',
                    visibleWhenMatched: false,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      testCategory(
        id: 'eyes',
        key: 'eyes',
        groups: [
          testGroup(id: 'eye_group', tags: ['blue eyes']),
        ],
      ),
    ]);

    final result = await generator.generateFromPreset(preset: preset, seed: 1);

    expect(result.mainPrompt, contains('sleeping'));
    expect(result.mainPrompt, isNot(contains('blue eyes')));
  });

  group('条件分支输出同类别词组', () {
    RandomPreset outfitPreset({bool branchEnabled = true}) => testPreset([
      testCategory(
        id: 'outfit',
        key: 'outfit',
        groups: [
          testGroup(id: 'type').copyWith(
            conditionalBranchConfig: ConditionalBranchConfig(
              id: 'type_config',
              name: 'Type',
              branches: [
                ConditionalBranch(
                  name: 'uniform',
                  probability: 100,
                  tagGroupIds: const ['uniform'],
                  enabled: branchEnabled,
                ),
                ConditionalBranch(
                  name: 'casual',
                  probability: 0,
                  tagGroupIds: const ['casual'],
                  enabled: branchEnabled,
                ),
              ],
            ),
          ),
          testGroup(id: 'uniform', tags: ['school uniform']),
          testGroup(id: 'casual', tags: ['t-shirt']),
          testGroup(id: 'always', tags: ['hat']),
        ],
      ),
    ]);

    test('被引用的词组只在分支选中时输出，不参与常规抽取', () async {
      final tags = _promptTags(
        (await generator.generateFromPreset(
          preset: outfitPreset(),
          seed: 1,
        )).mainPrompt,
      );

      expect(tags, containsAll(['school uniform', 'hat']));
      expect(tags, isNot(contains('t-shirt')));
    });

    test('分支停用后被引用的词组恢复常规抽取', () async {
      final tags = _promptTags(
        (await generator.generateFromPreset(
          preset: outfitPreset(branchEnabled: false),
          seed: 1,
        )).mainPrompt,
      );

      expect(tags, containsAll(['school uniform', 't-shirt', 'hat']));
    });

    test('输出的同类别词组按本轮作用域筛选，不会跨入主提示词或角色提示词', () async {
      final preset = testPreset(
        [
          testCategory(
            id: 'outfit',
            key: 'outfit',
            scope: TagScope.all,
            groups: [
              testGroup(id: 'type').copyWith(
                conditionalBranchConfig: const ConditionalBranchConfig(
                  id: 'type_config',
                  name: 'Type',
                  branches: [
                    ConditionalBranch(
                      name: 'both',
                      probability: 100,
                      tagGroupIds: ['uniform', 'backdrop'],
                    ),
                  ],
                ),
              ),
              testGroup(
                id: 'uniform',
                tags: ['school uniform'],
              ).copyWith(scope: TagScope.character),
              testGroup(
                id: 'backdrop',
                tags: ['classroom'],
              ).copyWith(scope: TagScope.global),
            ],
          ),
        ],
        algorithmConfig: const AlgorithmConfig(
          characterCountConfig: _soloGirlConfig,
        ),
        forceNoHumanConfig: false,
      );

      final result = await generator.generateFromPreset(
        preset: preset,
        seed: 1,
      );
      final mainTags = _promptTags(result.mainPrompt);
      final characterTags = _promptTags(result.characters.single.prompt);

      expect(mainTags, contains('classroom'));
      expect(mainTags, isNot(contains('school uniform')));
      expect(characterTags, contains('school uniform'));
      expect(characterTags, isNot(contains('classroom')));
    });

    test('存量数据里的循环引用在生成时被截断，不会无限展开', () async {
      ConditionalBranchConfig to(String target) => ConditionalBranchConfig(
        id: 'to_$target',
        name: 'to $target',
        branches: [
          ConditionalBranch(
            name: target,
            probability: 100,
            tagGroupIds: [target],
          ),
        ],
      );
      final preset = testPreset([
        testCategory(
          id: 'loop',
          key: 'loop',
          groups: [
            testGroup(id: 'root').copyWith(conditionalBranchConfig: to('a')),
            testGroup(id: 'a', tags: ['a tag']).copyWith(
              conditionalBranchConfig: to('b'),
            ),
            testGroup(id: 'b', tags: ['b tag']).copyWith(
              conditionalBranchConfig: to('a'),
            ),
          ],
        ),
      ]);

      final tags = _promptTags(
        (await generator.generateFromPreset(preset: preset, seed: 1))
            .mainPrompt,
      );

      expect(tags, contains('b tag'));
      expect(tags, isNot(contains('a tag')));
    });

    RandomPreset chainedConditionPreset({
      String moodKey = 'mood-id',
      String typeKey = 'type',
    }) => testPreset([
      testCategory(
        id: 'mood-id',
        key: 'mood',
        name: '心情',
        groups: [
          testGroup(id: 'mood_group', tags: ['{Sleeping}']),
        ],
      ),
      testCategory(
        id: 'outfit',
        key: 'outfit',
        groups: [
          testGroup(id: 'type').copyWith(
            name: '类型',
            conditionalBranchConfig: ConditionalBranchConfig(
              id: 'type_config',
              name: 'Type',
              branches: [
                ConditionalBranch(
                  name: 'pajamas',
                  probability: 1,
                  tagGroupIds: const ['pajamas'],
                  conditions: {moodKey: 'sleeping'},
                ),
                ConditionalBranch(
                  name: 'casual',
                  probability: 100,
                  tagGroupIds: const ['casual'],
                  conditions: {moodKey: 'running'},
                ),
              ],
            ),
          ),
          testGroup(id: 'pajamas', tags: ['pajamas']),
          testGroup(id: 'casual', tags: ['t-shirt']),
          testGroup(id: 'accessory').copyWith(
            conditionalBranchConfig: ConditionalBranchConfig(
              id: 'accessory_config',
              name: 'Accessory',
              branches: [
                ConditionalBranch(
                  name: 'nightcap',
                  tagGroupIds: const ['nightcap'],
                  conditions: {typeKey: 'pajamas'},
                ),
              ],
            ),
          ),
          testGroup(id: 'nightcap', tags: ['nightcap']),
        ],
      ),
    ]);

    Future<void> expectChainedBranches(RandomPreset preset) async {
      final tags = _promptTags(
        (await generator.generateFromPreset(preset: preset, seed: 1))
            .mainPrompt,
      );

      expect(tags, containsAll(['pajamas', 'nightcap']));
      expect(tags, isNot(contains('t-shirt')));
    }

    test('分支条件可引用先生成的类别标签和其他词组选中的分支', () async {
      await expectChainedBranches(chainedConditionPreset());
    });

    test('按类别名称与词组名称保存的存量条件在生成时同样生效', () async {
      await expectChainedBranches(
        chainedConditionPreset(moodKey: '心情', typeKey: '类型'),
      );
    });

    test('复制预设后分支条件引用的类别与词组指向副本，被分支输出的词组不会消失', () async {
      await expectChainedBranches(
        RandomPreset.copyFrom(chainedConditionPreset(), name: 'copy'),
      );
    });
  });

  test('disabled conditional branch config falls back to normal group tags',
      () async {
    final preset = testPreset([
      testCategory(
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
              testGroup(id: 'uniform_child', tags: ['school uniform']),
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
    }) => testPreset([
      testCategory(
        id: 'cat-pose',
        key: 'pose',
        name: '姿势',
        groups: [
          testGroup(id: 'pose_group', tags: [pose]),
        ],
      ),
      testCategory(
        id: 'cat-lower',
        key: 'lower',
        name: '下装',
        groups: [
          testGroup(id: 'shoes', tags: ['boots'], visibilityRules: shoesRules),
          testGroup(id: 'pants', tags: ['jeans']),
        ],
      ),
      testCategory(
        id: 'cat-extra',
        key: 'extra',
        groups: [
          testGroup(
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
      final preset = testPreset([
        testCategory(
          id: 'cat-pose',
          key: 'pose',
          groups: [
            testGroup(
              id: 'pose_group',
              tags: ['full body'],
              emphasisProbability: 1,
            ),
          ],
        ),
        testCategory(
          id: 'cat-lower',
          key: 'lower',
          groups: [
            testGroup(id: 'shoes', tags: ['boots']),
          ],
        ),
        testCategory(
          id: 'cat-extra',
          key: 'extra',
          groups: [
            testGroup(
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
    }) => testPreset([
      testCategory(
        id: 'cat-eyes',
        key: 'eyeColor',
        name: '眼睛',
        groups: [
          testGroup(id: 'eye_color', tags: ['blue eyes']),
          testGroup(id: 'eye_feature', tags: eyeFeatureTags),
        ],
      ),
      testCategory(
        id: 'cat-pose',
        key: 'pose',
        groups: [
          testGroup(
            id: 'pose_group',
            tags: poseTags,
            enabled: ownerEnabled,
            postProcessRules: [rule],
          ),
          testGroup(id: 'pose_extra', tags: ['arms up']),
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
      final preset = testPreset([
        testCategory(
          id: 'cat-species',
          key: 'species',
          groups: [
            testGroup(
              id: 'species_group',
              tags: ['mermaid'],
              postProcessRules: [
                PostProcessRule.mermaidRule(targetCategoryIds: ['cat-legwear']),
              ],
            ),
          ],
        ),
        testCategory(
          id: 'cat-legwear',
          key: 'custom3',
          groups: [
            testGroup(id: 'legwear', tags: ['thighhighs']),
          ],
        ),
        testCategory(
          id: 'cat-top',
          key: 'custom4',
          groups: [
            testGroup(id: 'top', tags: ['seashell bra']),
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
        testPreset(
          [
            testCategory(
              id: 'cat-scene',
              key: 'scene',
              groups: [
                testGroup(
                  id: 'with_people',
                  tags: ['crowd'],
                  dependencyConfig: const DependencyConfig(
                    type: DependencyType.exists,
                    sourceCategoryId: characterCountReference,
                  ),
                ),
                testGroup(
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
        preset: characterCountPreset(noHumanCountConfig),
        seed: 1,
      );

      expect(_promptTags(solo.mainPrompt), contains('crowd'));
      expect(_promptTags(solo.mainPrompt), isNot(contains('scenery')));
      expect(_promptTags(noHumans.mainPrompt), contains('scenery'));
      expect(_promptTags(noHumans.mainPrompt), isNot(contains('crowd')));
    });

    test('存在依赖满足时保留词组自己的多选数量', () async {
      final preset = testPreset([
        testCategory(
          id: 'cat-pose',
          key: 'pose',
          groups: [
            testGroup(id: 'pose_group', tags: ['standing']),
          ],
        ),
        testCategory(
          id: 'cat-accessory',
          key: 'accessory',
          groups: [
            testGroup(
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
    }) => testPreset([
      testCategory(
        id: 'cat-expression',
        key: 'expression',
        groups: [testGroup(id: 'expression_group', tags: expressionTags)],
      ),
      testCategory(
        id: 'cat-accessory',
        key: 'accessory',
        groups: [
          testGroup(
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

    test('指定的变量源与类别源一样按标签比较键匹配映射', () async {
      final result = await generator.generateFromPreset(
        preset: dependentAccessoryPreset(
          expressionTags: ['{Smile}'],
          dependency: const DependencyConfig(
            type: DependencyType.value,
            sourceCategoryId: 'cat-missing',
            sourceVariable: 'expression',
            mappingRules: {'smile': '2'},
          ),
        ),
        seed: 1,
      );

      expect(accessoryCount(result), 2);
    });

    test('指定的变量本轮没有取值时按源类别求值', () async {
      final result = await generator.generateFromPreset(
        preset: dependentAccessoryPreset(
          expressionTags: ['smile'],
          dependency: const DependencyConfig(
            type: DependencyType.value,
            sourceCategoryId: 'cat-expression',
            sourceVariable: 'unset',
            mappingRules: {'smile': '2'},
          ),
        ),
        seed: 1,
      );

      expect(accessoryCount(result), 2);
    });
  });
}

List<String> _promptTags(String prompt) =>
    prompt.split(',').map((tag) => tag.trim()).toList();

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
