import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';

DependencyConfig _config(DependencyType type) => DependencyConfig(
  type: type,
  sourceCategoryId: 'source',
  mappingRules: const {'portrait': '2', '1': '0-3'},
  defaultValue: '1',
);

void main() {
  test('存在依赖要求源有结果，排斥依赖要求源为空，数量与值依赖总是满足', () {
    for (final count in [0, 1, 3]) {
      expect(_config(DependencyType.exists).isSatisfiedBy(count), count > 0);
      expect(_config(DependencyType.excludes).isSatisfiedBy(count), count == 0);
      expect(_config(DependencyType.count).isSatisfiedBy(count), isTrue);
      expect(_config(DependencyType.value).isSatisfiedBy(count), isTrue);
    }
  });

  test('只有数量与值依赖控制选取数量', () {
    expect(_config(DependencyType.count).controlsSelectionCount, isTrue);
    expect(_config(DependencyType.value).controlsSelectionCount, isTrue);
    expect(_config(DependencyType.exists).controlsSelectionCount, isFalse);
    expect(_config(DependencyType.excludes).controlsSelectionCount, isFalse);
  });

  test('值依赖取第一个有映射的已选值，没有时回落到默认值', () {
    final config = _config(DependencyType.value);

    String? result(List<String> values) =>
        config.getResultForSource(sourceCount: 1, sourceValues: values);

    expect(result(['smile', 'portrait']), '2');
    expect(result(['smile']), '1');
    expect(result(const []), '1');
  });

  test('数量依赖先按结果数匹配，再按已选值匹配，最后用默认值', () {
    final config = _config(DependencyType.count).copyWith(
      mappingRules: const {'2': '0', '3-4': '1', 'portrait': '2'},
      defaultValue: '3',
    );

    String? result(int count, List<String> values) =>
        config.getResultForSource(sourceCount: count, sourceValues: values);

    expect(result(2, ['portrait', 'smile']), '0');
    expect(result(4, const []), '1');
    expect(result(1, ['portrait']), '2');
    expect(result(1, ['smile']), '3');
  });

  test('映射结果换算为数量，范围内随机，无结果为 0', () {
    final config = _config(DependencyType.count);

    expect(config.getCountForResult('2', () => 0), 2);
    expect(config.getCountForResult('0-3', () => 5), 1);
    expect(config.getCountForResult(null, () => 0), 0);
  });
}
