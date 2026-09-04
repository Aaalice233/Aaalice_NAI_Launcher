import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/dependency_config.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/window_size_class.dart';
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
  final String? title;

  /// 由自适应容器持有的滚动控制器
  final ScrollController? scrollController;

  const DependencyConfigDialog({
    super.key,
    this.initialConfig,
    this.availableCategories = const [],
    this.title,
    this.scrollController,
  });

  /// 显示弹窗
  static Future<DependencyConfig?> show(
    BuildContext context, {
    DependencyConfig? initialConfig,
    List<String> availableCategories = const [],
    String? title,
  }) {
    return AdaptivePresenter.showForm<DependencyConfig>(
      context: context,
      titleBuilder: (context) => Row(
        children: [
          const Icon(Icons.link),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title ?? context.l10n.diy_editDependencyTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      sideSheetWidth: 560,
      builder: (context, scrollController) => DependencyConfigDialog(
        initialConfig: initialConfig,
        availableCategories: availableCategories,
        title: title,
        scrollController: scrollController,
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
    final compact = context.adaptiveWindow.isCompact;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 2;

    return Column(
      key: const ValueKey('dependency-config-dialog'),
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('dependency-config-scroll'),
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(compact ? 12 : 16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = largeText && compact
                      ? 600.0
                      : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentWidth,
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
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cancel = TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.common_cancel),
                );
                final clear = _config == null
                    ? null
                    : TextButton(
                        onPressed: () {
                          setState(() {
                            _config = null;
                            _hasChanges = true;
                          });
                        },
                        child: Text(context.l10n.common_clear),
                      );
                final save = FilledButton(
                  onPressed: _hasChanges
                      ? () => Navigator.pop(context, _config)
                      : null,
                  child: Text(context.l10n.common_save),
                );
                final stacked = constraints.maxWidth < 240;
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [save, if (clear != null) clear, cancel],
                  );
                }
                return Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [cancel, if (clear != null) clear, save],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
