import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';

Map<String, dynamic> _viaJsonText(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  test('当前版本导出的预设可以原样导入', () {
    final source = RandomPreset.create(
      name: '带规则的预设',
      description: '往返',
      algorithmConfig: const AlgorithmConfig(globalEmphasisProbability: 0.05),
      categories: const [
        RandomCategory(
          id: 'cat-pose',
          name: '姿势',
          key: 'pose',
          groups: [
            RandomTagGroup(
              id: 'pose-group',
              name: '姿势',
              tags: [WeightedTag(tag: 'portrait', weight: 3)],
              visibilityRules: [
                VisibilityRule(
                  id: 'self',
                  name: 'self',
                  sourceCategoryId: 'cat-pose',
                  targetCategoryId: 'pose-group',
                  conditionValue: 'portrait',
                ),
              ],
              dependencyConfig: DependencyConfig(
                type: DependencyType.exists,
                sourceCategoryId: 'character_count',
              ),
              postProcessRules: [
                PostProcessRule(
                  id: 'sleep',
                  name: 'sleep',
                  triggerTags: ['sleeping'],
                  action: PostProcessAction.removeCategory,
                  targetCategoryIds: ['cat-pose'],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final imported = RandomPreset.fromExportJson(
      _viaJsonText(source.toExportJson()),
    );

    expect(imported.version, RandomPreset.currentVersion);
    expect(imported.id, isNot(source.id));
    expect(imported.name, source.name);
    expect(imported.description, source.description);
    expect(imported.algorithmConfig, source.algorithmConfig);
    expect(imported.categories, source.categories);
    expect(imported.isDefault, isFalse);
  });

  test('没有版本号的 v2 旧文件按 v2 导入，缺少的字段取默认值', () {
    final imported = RandomPreset.fromExportJson({
      'name': '旧版预设',
      'categories': [
        {
          'id': 'hair',
          'name': '发色',
          'key': 'hairColor',
          'groups': [
            {
              'id': 'hair-group',
              'name': '发色',
              'tags': [
                {'tag': 'blonde hair', 'weight': 5},
              ],
            },
          ],
        },
      ],
    });

    expect(imported.version, 2);
    expect(imported.name, '旧版预设');
    final group = imported.categories.single.groups.single;
    expect(group.tags.single.tag, 'blonde hair');
    expect(group.visibilityRules, isEmpty);
    expect(imported.algorithmConfig, const AlgorithmConfig());
  });

  test('v3 文件保留版本号导入，按名称保存的旧规则引用原样保留', () {
    final imported = RandomPreset.fromExportJson({
      'name': 'v3 预设',
      'version': 3,
      'algorithmConfig': {'globalEmphasisProbability': 0.1},
      'categories': [
        {
          'id': 'outfit',
          'name': '服装',
          'key': 'clothing',
          'groups': [
            {
              'id': 'shoes',
              'name': '鞋',
              'visibilityRules': [
                {
                  'id': 'legacy',
                  'name': 'legacy',
                  'sourceCategoryId': '姿势',
                  'targetCategoryId': '服装',
                  'conditionValue': 'portrait',
                },
              ],
            },
          ],
        },
      ],
      'tagGroupMappings': [],
      'poolMappings': [],
    });

    expect(imported.version, 3);
    expect(imported.algorithmConfig.globalEmphasisProbability, 0.1);
    final rule =
        imported.categories.single.groups.single.visibilityRules.single;
    expect(rule.sourceCategoryId, '姿势');
    expect(rule.targetCategoryId, '服装');
  });

  test('高于当前版本的文件提示先更新应用', () {
    expect(
      () => RandomPreset.fromExportJson({
        'name': '未来的预设',
        'version': RandomPreset.currentVersion + 1,
      }),
      throwsA(
        isA<RandomPresetVersionException>().having(
          (error) => error.version,
          'version',
          RandomPreset.currentVersion + 1,
        ),
      ),
    );
  });
}
