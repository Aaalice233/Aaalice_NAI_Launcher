import 'package:flutter/material.dart';

import '../../../../../data/models/prompt/dependency_config.dart';
import '../panels/dependency_config_panel.dart';

/// 依赖配置编辑弹窗
///
/// 用于编辑依赖配置的完整弹窗
class DependencyConfigDialog extends StatefulWidget {
  /// 初始配置
  final DependencyConfig? initialConfig;

  /// 可用的类别列表
  final List<String> availableCategories;

  /// 标题
  final String title;

  const DependencyConfigDialog({
    super.key,
    this.initialConfig,
    this.availableCategories = const [],
    this.title = '编辑依赖配置',
  });

  /// 显示弹窗
  static Future<DependencyConfig?> show(
    BuildContext context, {
    DependencyConfig? initialConfig,
    List<String> availableCategories = const [],
    String title = '编辑依赖配置',
  }) {
    return showDialog<DependencyConfig>(
      context: context,
      builder: (context) => DependencyConfigDialog(
        initialConfig: initialConfig,
        availableCategories: availableCategories,
        title: title,
      ),
    );
  }

  @override
  State<DependencyConfigDialog> createState() => _DependencyConfigDialogState();
}

class _DependencyConfigDialogState extends State<DependencyConfigDialog> {
  late DependencyConfig? _config;
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
          const Icon(Icons.link),
          const SizedBox(width: 8),
          Text(widget.title),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: DependencyConfigPanel(
            config: _config,
            availableCategories: widget.availableCategories,
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
