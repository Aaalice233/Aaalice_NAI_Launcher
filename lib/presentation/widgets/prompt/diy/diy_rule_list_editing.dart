import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 规则或分支列表面板的增删与选中
///
/// 弹出的表单路由不随父级重建，面板自己持有正在编辑的列表；父级传入的
/// 列表变化时采用新列表，选中项仍在范围内就保留。
mixin DiyRuleListEditing<W extends StatefulWidget, T> on State<W> {
  late List<T> rules;
  int? selectedIndex;

  /// 父级传入的列表
  @protected
  List<T> rulesOf(W widget);

  /// 列表编辑后通知父级
  @protected
  void onRulesEdited(List<T> rules);

  @override
  void initState() {
    super.initState();
    rules = rulesOf(widget);
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = rulesOf(widget);
    if (listEquals(rulesOf(oldWidget), next)) return;
    rules = next;
    if ((selectedIndex ?? 0) >= next.length) selectedIndex = null;
  }

  void selectRule(int? index) => setState(() => selectedIndex = index);

  void addRule(T rule, {bool select = true}) => _setRules([
    ...rules,
    rule,
  ], selectedIndex: select ? rules.length : selectedIndex);

  void removeRule(int index) {
    final selected = selectedIndex;
    _setRules(
      [...rules]..removeAt(index),
      selectedIndex: selected == null || selected == index
          ? null
          : selected > index
          ? selected - 1
          : selected,
    );
  }

  void replaceRule(int index, T rule) =>
      _setRules([...rules]..[index] = rule, selectedIndex: selectedIndex);

  /// 选中条目的编辑区；输入框只在创建时读取初始值，切换条目时整体重建
  Widget? buildSelectedEditor(Widget Function(int index, T rule) builder) {
    final index = selectedIndex;
    if (index == null || index >= rules.length) return null;
    return KeyedSubtree(
      key: ValueKey(index),
      child: builder(index, rules[index]),
    );
  }

  void _setRules(List<T> next, {required int? selectedIndex}) {
    setState(() {
      rules = next;
      this.selectedIndex = selectedIndex;
    });
    onRulesEdited(next);
  }
}
