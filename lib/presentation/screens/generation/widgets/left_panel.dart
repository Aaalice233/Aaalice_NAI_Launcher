import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/layout_state_provider.dart';
import 'collapsed_panel.dart';
import 'generation_workspace_header.dart';
import 'parameter_panel.dart';

/// 左侧面板组件
///
/// 显示参数面板，支持展开/折叠状态和拖拽时禁用动画。
class LeftPanel extends ConsumerWidget {
  final bool isResizing;

  const LeftPanel({super.key, this.isResizing = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layoutState = ref.watch(layoutStateNotifierProvider);

    final width = layoutState.leftPanelExpanded
        ? layoutState.leftPanelWidth
        : 40.0;
    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
    );

    final child = layoutState.leftPanelExpanded
        ? Column(
            children: [
              GenerationWorkspaceHeader(
                key: const ValueKey('classic-generation-workspace-header'),
                onCollapse: () => ref
                    .read(layoutStateNotifierProvider.notifier)
                    .setLeftPanelExpanded(false),
              ),
              const Expanded(child: ParameterPanel(showCharacterEditor: true)),
            ],
          )
        : CollapsedPanel(
            icon: Icons.tune,
            label: context.l10n.generation_params,
            onTap: () => ref
                .read(layoutStateNotifierProvider.notifier)
                .setLeftPanelExpanded(true),
          );

    // 拖拽时不使用动画，避免粘滞感
    if (isResizing) {
      return Container(width: width, decoration: decoration, child: child);
    }

    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      width: width,
      decoration: decoration,
      child: child,
    );
  }
}
