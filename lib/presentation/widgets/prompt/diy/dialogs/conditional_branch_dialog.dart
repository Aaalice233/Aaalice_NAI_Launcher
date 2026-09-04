import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/conditional_branch.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/window_size_class.dart';
import '../panels/conditional_branch_panel.dart';

/// 条件分支编辑弹窗。
class ConditionalBranchDialog extends StatefulWidget {
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
    return AdaptivePresenter.showForm<ConditionalBranchConfig>(
      context: context,
      width: 600,
      titleBuilder: (context) => Row(
        children: [
          const Icon(Icons.call_split),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title ?? context.l10n.diy_editConditionalTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      builder: (context, scrollController) => ConditionalBranchDialog(
        initialConfig: initialConfig,
        title: title,
        scrollController: scrollController,
      ),
    );
  }

  @override
  State<ConditionalBranchDialog> createState() =>
      _ConditionalBranchDialogState();
}

class _ConditionalBranchDialogState extends State<ConditionalBranchDialog> {
  late ConditionalBranchConfig? _config;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.adaptiveWindow.isCompact;
    return Column(
      key: const ValueKey('conditional-branch-dialog'),
      children: [
        Expanded(
          child: ListView(
            key: ValueKey(
              compact
                  ? 'conditional-branch-compact-scroll'
                  : 'conditional-branch-expanded-content',
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
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: _buildActions(),
            ),
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
    return ConditionalBranchPanel(
      config: _config,
      onConfigChanged: (config) {
        setState(() {
          _config = config;
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
      if (_config != null)
        TextButton(onPressed: _clear, child: Text(context.l10n.common_clear)),
      FilledButton(
        onPressed: _hasChanges ? _save : null,
        child: Text(context.l10n.common_save),
      ),
    ];
  }

  void _clear() {
    setState(() {
      _config = null;
      _hasChanges = true;
    });
  }

  void _save() => Navigator.pop(context, _config);
}
