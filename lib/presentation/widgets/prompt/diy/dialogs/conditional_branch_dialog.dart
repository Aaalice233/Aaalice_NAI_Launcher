import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/conditional_branch.dart';
import '../panels/conditional_branch_panel.dart';
import 'rule_condition_dialog_scaffold.dart';

/// 条件分支编辑弹窗。
class ConditionalBranchDialog extends StatelessWidget {
  const ConditionalBranchDialog({
    super.key,
    this.initialConfig,
    this.title,
    this.scrollController,
  });

  final ConditionalBranchConfig? initialConfig;
  final String? title;
  final ScrollController? scrollController;

  static Future<ConditionalBranchConfig?> show(
    BuildContext context, {
    ConditionalBranchConfig? initialConfig,
    String? title,
  }) {
    return RuleConditionDialogScaffold.show<ConditionalBranchConfig>(
      context: context,
      icon: Icons.call_split,
      titleBuilder: (context) => title ?? context.l10n.diy_editConditionalTitle,
      dialogWidth: 600,
      builder: (context, scrollController) => ConditionalBranchDialog(
        initialConfig: initialConfig,
        title: title,
        scrollController: scrollController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RuleConditionDialogScaffold<ConditionalBranchConfig>(
      keyPrefix: 'conditional-branch',
      initialValue: initialConfig,
      scrollController: scrollController,
      panelBuilder: (context, config, onChanged) =>
          ConditionalBranchPanel(config: config, onConfigChanged: onChanged),
    );
  }
}
