import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../providers/layout_state_provider.dart';
import 'collapsed_panel.dart';
import 'history_panel.dart';

/// 右侧面板组件
///
/// 显示历史面板，支持展开/折叠状态和拖拽时禁用动画。
class RightPanel extends ConsumerWidget {
  final bool isResizing;

  const RightPanel({
    super.key,
    this.isResizing = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layoutState = ref.watch(layoutStateNotifierProvider);

    final width =
        layoutState.rightPanelExpanded ? layoutState.rightPanelWidth : 40.0;
    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(
        left: BorderSide(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
    );

    final child = layoutState.rightPanelExpanded
        ? const HistoryPanel()
        : CollapsedPanel(
            icon: Icons.history,
            label: context.l10n.generation_history,
            onTap: () => ref
                .read(layoutStateNotifierProvider.notifier)
                .setRightPanelExpanded(true),
          );

    // 拖拽时不使用动画，避免粘滞感
    if (isResizing) {
      return Container(
        width: width,
        decoration: decoration,
        child: child,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: decoration,
      child: child,
    );
  }
}
