import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/time_condition.dart';
import '../panels/time_condition_panel.dart';

/// 时间条件编辑弹窗
///
/// 用于编辑时间条件的完整弹窗
class TimeConditionDialog extends StatefulWidget {
  /// 初始条件
  final TimeCondition? initialCondition;

  /// 标题
  final String? title;

  const TimeConditionDialog({super.key, this.initialCondition, this.title});

  /// 显示弹窗
  static Future<TimeCondition?> show(
    BuildContext context, {
    TimeCondition? initialCondition,
    String? title,
  }) {
    return showDialog<TimeCondition>(
      context: context,
      builder: (context) =>
          TimeConditionDialog(initialCondition: initialCondition, title: title),
    );
  }

  @override
  State<TimeConditionDialog> createState() => _TimeConditionDialogState();
}

class _TimeConditionDialogState extends State<TimeConditionDialog> {
  late TimeCondition? _condition;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _condition = widget.initialCondition;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.calendar_month),
          const SizedBox(width: 8),
          Text(widget.title ?? context.l10n.diy_editTimeConditionTitle),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: TimeConditionPanel(
            condition: _condition,
            onConditionChanged: (condition) {
              setState(() {
                _condition = condition;
                _hasChanges = true;
              });
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
        if (_condition != null)
          TextButton(
            onPressed: () {
              setState(() {
                _condition = null;
                _hasChanges = true;
              });
            },
            child: Text(context.l10n.common_clear),
          ),
        FilledButton(
          onPressed: _hasChanges
              ? () => Navigator.pop(context, _condition)
              : null,
          child: Text(context.l10n.common_save),
        ),
      ],
    );
  }
}
