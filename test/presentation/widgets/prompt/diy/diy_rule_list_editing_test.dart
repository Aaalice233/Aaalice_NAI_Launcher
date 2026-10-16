import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/diy_rule_list_editing.dart';

void main() {
  late List<List<String>> emitted;
  late GlobalKey<_RuleListState> list;

  Future<void> pumpRules(WidgetTester tester, List<String> rules) =>
      tester.pumpWidget(
        _RuleList(key: list, rules: rules, onRulesChanged: emitted.add),
      );

  setUp(() {
    emitted = [];
    list = GlobalKey();
  });

  testWidgets('添加时默认选中新条目，可以选择不选中', (tester) async {
    await pumpRules(tester, const ['a']);

    list.currentState!.addRule('b');
    await tester.pump();
    expect(list.currentState!.selectedIndex, 1);

    list.currentState!.addRule('c', select: false);
    await tester.pump();
    expect(list.currentState!.selectedIndex, 1);
    expect(emitted.last, ['a', 'b', 'c']);
  });

  testWidgets('删除选中项之前的条目后选中项跟随原条目，删除选中项则取消选中', (tester) async {
    await pumpRules(tester, const ['a', 'b', 'c']);
    list.currentState!.selectRule(2);

    list.currentState!.removeRule(0);
    await tester.pump();
    expect(list.currentState!.selectedIndex, 1);
    expect(find.text('editing b'), findsNothing);
    expect(find.text('editing c'), findsOneWidget);

    list.currentState!.removeRule(1);
    await tester.pump();
    expect(list.currentState!.selectedIndex, isNull);
    expect(find.textContaining('editing'), findsNothing);
    expect(emitted.last, ['b']);
  });

  testWidgets('父级沿用旧列表重建时保留本地编辑', (tester) async {
    await pumpRules(tester, const ['a']);
    list.currentState!.addRule('b');
    await tester.pump();

    await pumpRules(tester, const ['a']);
    expect(list.currentState!.rules, ['a', 'b']);
    expect(list.currentState!.selectedIndex, 1);
  });

  testWidgets('父级传入新列表时采用它，选中项仍在范围内就保留', (tester) async {
    await pumpRules(tester, const ['a', 'b', 'c']);
    list.currentState!.selectRule(1);

    await pumpRules(tester, const ['x', 'y']);
    expect(list.currentState!.rules, ['x', 'y']);
    expect(find.text('editing y'), findsOneWidget);

    await pumpRules(tester, const ['z']);
    expect(list.currentState!.selectedIndex, isNull);
    expect(emitted, isEmpty);
  });
}

class _RuleList extends StatefulWidget {
  const _RuleList({
    super.key,
    required this.rules,
    required this.onRulesChanged,
  });

  final List<String> rules;
  final ValueChanged<List<String>> onRulesChanged;

  @override
  State<_RuleList> createState() => _RuleListState();
}

class _RuleListState extends State<_RuleList>
    with DiyRuleListEditing<_RuleList, String> {
  @override
  List<String> rulesOf(_RuleList widget) => widget.rules;

  @override
  void onRulesEdited(List<String> rules) => widget.onRulesChanged(rules);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child:
          buildSelectedEditor((index, rule) => Text('editing $rule')) ??
          const SizedBox.shrink(),
    );
  }
}
