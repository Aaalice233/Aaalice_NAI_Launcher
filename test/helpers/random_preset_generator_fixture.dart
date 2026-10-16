import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/local/pool_cache_service.dart';
import 'package:nai_launcher/data/datasources/local/tag_group_cache_service.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/character_count_config.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/tag_scope.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/data/services/random_prompt_generator.dart';
import 'package:nai_launcher/data/services/sequential_state_service.dart';
import 'package:nai_launcher/data/services/tag_library_service.dart';

class MockTagLibraryService extends Mock implements TagLibraryService {}

class MockTagGroupCacheService extends Mock implements TagGroupCacheService {}

class MockPoolCacheService extends Mock implements PoolCacheService {}

/// 顺序轮替的游标按调用次数推进，不读写持久化存储
class CountingSequentialStateService extends Mock
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

RandomPromptGenerator createTestGenerator({
  TagLibraryService? libraryService,
  PoolCacheService? poolCacheService,
}) {
  return RandomPromptGenerator(
    libraryService ?? MockTagLibraryService(),
    CountingSequentialStateService(),
    MockTagGroupCacheService(),
    poolCacheService ?? MockPoolCacheService(),
  );
}

const noHumanCountConfig = CharacterCountConfig(
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

/// 未指定人数配置时固定为无人场景，结果只含主提示词
RandomPreset testPreset(
  List<RandomCategory> categories, {
  AlgorithmConfig algorithmConfig = const AlgorithmConfig(),
  bool forceNoHumanConfig = true,
}) {
  return RandomPreset(
    id: 'preset',
    name: 'Preset',
    algorithmConfig:
        forceNoHumanConfig && algorithmConfig.characterCountConfig == null
        ? algorithmConfig.copyWith(characterCountConfig: noHumanCountConfig)
        : algorithmConfig,
    categories: categories,
  );
}

RandomCategory testCategory({
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

RandomTagGroup testGroup({
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
