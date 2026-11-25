import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../widgets/common/image_card_action.dart';
import '../../../../widgets/common/image_card_inline_actions.dart';

class PreciseReferenceCardHeader extends StatelessWidget {
  const PreciseReferenceCardHeader({
    super.key,
    required this.index,
    required this.enabled,
    required this.onEnabledChanged,
    required this.thumbnail,
    required this.editor,
    required this.actions,
  });

  final int index;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final Widget thumbnail;
  final Widget editor;
  final List<ImageCardAction> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stackEditor =
          constraints.maxWidth < MediaQuery.textScalerOf(context).scale(340);
      final toggle = _buildEnabledToggle(context);
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          thumbnail,
          const SizedBox(width: 12),
          Expanded(
            child: stackEditor
                ? toggle
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [toggle, const SizedBox(height: 8), editor],
                  ),
          ),
          ImageCardInlineActions(direction: Axis.vertical, actions: actions),
        ],
      );
      if (!stackEditor) return row;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [row, const SizedBox(height: 8), editor],
      );
    },
  );

  Widget _buildEnabledToggle(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.reference_enabled,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Tooltip(
          message: enabled
              ? context.l10n.reference_disable
              : context.l10n.reference_enable,
          child: Switch(
            key: ValueKey('precise-reference-enabled-switch-$index'),
            value: enabled,
            onChanged: onEnabledChanged,
          ),
        ),
      ],
    );
  }
}
