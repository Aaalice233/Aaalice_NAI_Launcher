import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/time_condition.dart';
import '../panels/time_condition_panel.dart';
import 'rule_condition_dialog_scaffold.dart';

/// 时间条件编辑弹窗。
class TimeConditionDialog extends StatelessWidget {
  const TimeConditionDialog({
    super.key,
    this.initialCondition,
    this.title,
    this.scrollController,
  });

  final TimeCondition? initialCondition;
  final String? title;
  final ScrollController? scrollController;

  static Future<TimeCondition?> show(
    BuildContext context, {
    TimeCondition? initialCondition,
    String? title,
  }) {
    return RuleConditionDialogScaffold.show<TimeCondition>(
      context: context,
      icon: Icons.calendar_month,
      titleBuilder: (context) =>
          title ?? context.l10n.diy_editTimeConditionTitle,
      dialogWidth: 600,
      builder: (context, scrollController) => TimeConditionDialog(
        initialCondition: initialCondition,
        title: title,
        scrollController: scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RuleConditionDialogScaffold<TimeCondition>(
      keyPrefix: 'time-condition',
      initialValue: initialCondition,
      scrollController: scrollController,
      panelBuilder: (context, condition, onChanged) => TimeConditionPanel(
        condition: condition,
        onConditionChanged: onChanged,
      ),
    );
  }
}
