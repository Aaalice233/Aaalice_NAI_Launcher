import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';

void main() {
  final christmas = TimeCondition.christmas();
  final outside = DateTime(2026, 6, 1);
  final inside = DateTime(2026, 12, 24);

  test('停用的时间条件等同于没有时间条件，不限制词组', () {
    final group = RandomTagGroup(
      id: 'group',
      name: 'group',
      timeCondition: christmas.copyWith(enabled: false),
    );

    expect(group.hasTimeCondition, isFalse);
    expect(group.isTimeConditionActive(outside), isTrue);
    expect(
      group.copyWith(timeCondition: christmas).isTimeConditionActive(outside),
      isFalse,
    );
    expect(
      group.copyWith(timeCondition: christmas).isTimeConditionActive(inside),
      isTrue,
    );
  });

  test('关闭每年重复后只在所选年份生效，未选年份的旧数据仍每年生效', () {
    final only2026 = christmas.copyWith(recurring: false, specificYear: 2026);
    final legacy = christmas.copyWith(recurring: false);

    expect(only2026.isActive(inside), isTrue);
    expect(only2026.isActive(DateTime(2027, 12, 24)), isFalse);
    expect(legacy.isActive(DateTime(2031, 12, 24)), isTrue);
  });

  test('条件组忽略停用的条件', () {
    final disabled = christmas.copyWith(id: 'off', enabled: false);

    expect(
      TimeConditionGroup(conditions: [disabled]).isActive(outside),
      isTrue,
    );
    expect(
      TimeConditionGroup(
        conditions: [disabled, christmas],
        matchAny: false,
      ).isActive(inside),
      isTrue,
    );
    expect(
      TimeConditionGroup(conditions: [disabled, christmas]).isActive(outside),
      isFalse,
    );
  });
}
