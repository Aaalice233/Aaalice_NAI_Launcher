import 'package:flutter/material.dart';

import '../../../../../data/models/prompt/conditional_branch.dart';
import '../panels/conditional_branch_panel.dart';

/// 条件分支编辑弹窗
///
/// 用于编辑条件分支配置的完整弹窗
class ConditionalBranchDialog extends StatefulWidget {
  /// 初始配置
  final ConditionalBranchConfig? initialConfig;

  /// 标题
  final String title;

  const ConditionalBranchDialog({
    super.key,
    this.initialConfig,
    this.title = '编辑条件分支',
  });

  /// 显示弹窗
  static Future<ConditionalBranchConfig?> show(
    BuildContext context, {
    ConditionalBranchConfig? initialConfig,
    String title = '编辑条件分支',
  }) {
    return showDialog<ConditionalBranchConfig>(
      context: context,
      builder: (context) => ConditionalBranchDialog(
        initialConfig: initialConfig,
        title: title,
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
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.call_split),
          const SizedBox(width: 8),
          Text(widget.title),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: ConditionalBranchPanel(
            config: _config,
            onConfigChanged: (config) {
              setState(() {
                _config = config;
                _hasChanges = true;
              });
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        if (_config != null)
          TextButton(
            onPressed: () {
              setState(() {
                _config = null;
                _hasChanges = true;
              });
            },
            child: const Text('清除'),
          ),
        FilledButton(
          onPressed: _hasChanges ? () => Navigator.pop(context, _config) : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
