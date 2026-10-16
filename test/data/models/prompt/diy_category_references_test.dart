import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/diy_category_references.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';

const _hair = RandomCategory(id: 'cat-hair', name: '发色', key: 'hairColor');
const _outfit = RandomCategory(id: 'cat-outfit', name: '服装', key: 'clothing');

void main() {
  group('DiyCategoryReferenceResolver', () {
    final resolver = DiyCategoryReferenceResolver(const [_hair, _outfit]);

    test('按 ID、键名、名称的顺序定位类别并统一返回 ID', () {
      expect(resolver.canonicalId('cat-hair'), 'cat-hair');
      expect(resolver.canonicalId('clothing'), 'cat-outfit');
      expect(resolver.canonicalId('发色'), 'cat-hair');
    });

    test('找不到或为空的引用原样保留', () {
      expect(resolver.canonicalId('gone'), 'gone');
      expect(resolver.canonicalId(''), '');
      expect(resolver.resolve(''), isNull);
    });

    test('重名的名称或键名无法确定指向时不解析', () {
      final ambiguous = DiyCategoryReferenceResolver(const [
        _hair,
        RandomCategory(id: 'cat-hair-2', name: '发色', key: 'hairColor'),
        RandomCategory(id: 'cat-hair-3', name: '发色', key: 'hairColor'),
      ]);

      expect(ambiguous.canonicalId('发色'), '发色');
      expect(ambiguous.canonicalId('hairColor'), 'hairColor');
      expect(ambiguous.canonicalId('cat-hair-2'), 'cat-hair-2');
    });
  });

  test('词组的依赖、可见性与后处理引用连同子词组一起映射，角色人数保持不变', () {
    const group = RandomTagGroup(
      id: 'group',
      name: 'group',
      dependencyConfig: DependencyConfig(sourceCategoryId: 'old-hair'),
      visibilityRules: [
        VisibilityRule(
          id: 'rule',
          name: 'rule',
          sourceCategoryId: 'old-hair',
          targetCategoryId: 'old-outfit',
          conditionValue: 'portrait',
        ),
      ],
      postProcessRules: [
        PostProcessRule(
          id: 'post',
          name: 'post',
          triggerCategoryIds: ['old-hair'],
          targetCategoryIds: ['old-outfit', 'kept'],
        ),
      ],
      children: [
        RandomTagGroup(
          id: 'child',
          name: 'child',
          dependencyConfig: DependencyConfig(
            sourceCategoryId: characterCountReference,
          ),
        ),
        RandomTagGroup(
          id: 'child-2',
          name: 'child-2',
          dependencyConfig: DependencyConfig(sourceCategoryId: 'old-outfit'),
        ),
      ],
    );
    const ids = {'old-hair': 'new-hair', 'old-outfit': 'new-outfit'};

    final mapped = group.mapCategoryReferences((ref) => ids[ref] ?? ref);

    expect(mapped.dependencyConfig?.sourceCategoryId, 'new-hair');
    expect(mapped.visibilityRules.single.sourceCategoryId, 'new-hair');
    expect(mapped.visibilityRules.single.targetCategoryId, 'new-outfit');
    expect(mapped.postProcessRules.single.triggerCategoryIds, ['new-hair']);
    expect(mapped.postProcessRules.single.targetCategoryIds, [
      'new-outfit',
      'kept',
    ]);
    expect(
      mapped.children.first.dependencyConfig?.sourceCategoryId,
      characterCountReference,
    );
    expect(
      mapped.children.last.dependencyConfig?.sourceCategoryId,
      'new-outfit',
    );
  });
}
