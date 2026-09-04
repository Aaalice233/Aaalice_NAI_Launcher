import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/time_condition.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/window_size_class.dart';
import '../panels/time_condition_panel.dart';

/// 时间条件编辑弹窗。
class TimeConditionDialog extends StatefulWidget {
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
    return AdaptivePresenter.showForm<TimeCondition>(
      context: context,
      dialogWidth: 600,
      titleBuilder: (context) => Row(
        children: [
          const Icon(Icons.calendar_month),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title ?? context.l10n.diy_editTimeConditionTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      builder: (context, scrollController) => TimeConditionDialog(
        initialCondition: initialCondition,
        title: title,
        scrollController: scrollController,
      ),
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
    final compact = context.adaptiveWindow.isCompact;
    return Column(
      key: const ValueKey('time-condition-dialog'),
      children: [
        Expanded(
          child: ListView(
            key: ValueKey(
              compact
                  ? 'time-condition-compact-scroll'
                  : 'time-condition-expanded-content',
            ),
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(compact ? 12 : 16),
            children: [_buildResponsivePanel(compact)],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: _buildActionBar(),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsivePanel(bool compact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledFormWidth = MediaQuery.textScalerOf(context).scale(280);
        if (!compact || scaledFormWidth <= constraints.maxWidth) {
          return _buildPanel();
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: scaledFormWidth, child: _buildPanel()),
        );
      },
    );
  }

  Widget _buildPanel() {
    return TimeConditionPanel(
      condition: _condition,
      onConditionChanged: (condition) {
        setState(() {
          _condition = condition;
          _hasChanges = true;
        });
      },
    );
  }

  List<Widget> _buildActions() {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.common_cancel),
      ),
      if (_condition != null)
        TextButton(onPressed: _clear, child: Text(context.l10n.common_clear)),
      FilledButton(
        onPressed: _hasChanges ? _save : null,
        child: Text(context.l10n.common_save),
      ),
    ];
  }

  Widget _buildActionBar() {
    final actions = _buildActions();
    if (MediaQuery.textScalerOf(context).scale(1) < 2) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: actions,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }

  void _clear() {
    setState(() {
      _condition = null;
      _hasChanges = true;
    });
  }

  void _save() => Navigator.pop(context, _condition);
}
