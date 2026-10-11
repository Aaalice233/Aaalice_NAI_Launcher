import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';

import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/window_size_class.dart';

/// 条件编辑区插槽：渲染具体面板并回传新值。
typedef RuleConditionPanelBuilder<T> =
    Widget Function(BuildContext context, T? value, ValueChanged<T?> onChanged);

/// DIY 条件弹窗骨架：滚动内容区加取消/清除/保存操作条。
class RuleConditionDialogScaffold<T> extends StatefulWidget {
  const RuleConditionDialogScaffold({
    super.key,
    required this.keyPrefix,
    required this.panelBuilder,
    this.initialValue,
    this.scrollController,
  });

  /// 内容与滚动容器的 `ValueKey` 前缀。
  final String keyPrefix;
  final RuleConditionPanelBuilder<T> panelBuilder;
  final T? initialValue;
  final ScrollController? scrollController;

  /// 以统一的图标标题头承载条件弹窗。
  static Future<T?> show<T>({
    required BuildContext context,
    required IconData icon,
    required String Function(BuildContext context) titleBuilder,
    required AdaptivePanelBuilder builder,
    required double dialogWidth,
  }) {
    return AdaptivePresenter.showForm<T>(
      context: context,
      dialogWidth: dialogWidth,
      titleBuilder: (context) => Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titleBuilder(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      builder: builder,
    );
  }

  @override
  State<RuleConditionDialogScaffold<T>> createState() =>
      _RuleConditionDialogScaffoldState<T>();
}

class _RuleConditionDialogScaffoldState<T>
    extends State<RuleConditionDialogScaffold<T>> {
  late T? _value;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final compact = context.adaptiveWindow.isCompact;
    return Column(
      key: ValueKey('${widget.keyPrefix}-dialog'),
      children: [
        Expanded(
          child: ListView(
            key: ValueKey(
              compact
                  ? '${widget.keyPrefix}-compact-scroll'
                  : '${widget.keyPrefix}-expanded-content',
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
          return _buildPanel(context);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: scaledFormWidth, child: _buildPanel(context)),
        );
      },
    );
  }

  Widget _buildPanel(BuildContext context) {
    return widget.panelBuilder(context, _value, (value) {
      setState(() {
        _value = value;
        _hasChanges = true;
      });
    });
  }

  List<Widget> _buildActions() {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.common_cancel),
      ),
      if (_value != null)
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
    return HorizontalActionStrip(
      reverse: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }

  void _clear() {
    setState(() {
      _value = null;
      _hasChanges = true;
    });
  }

  void _save() => Navigator.pop(context, _value);
}
