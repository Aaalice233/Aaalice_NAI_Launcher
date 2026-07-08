import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import '../../../providers/layout_state_provider.dart';
import 'character_panel.dart';
import 'collapsed_panel.dart';
import 'generation_controls/generation_controls.dart';
import 'parameter_panel.dart';
import 'prompt_input.dart';
import 'web_panel_split.dart';

/// 官网式布局左栏
///
/// 上分区：编辑器填充角色卡片未占用的剩余高度、内容超出时编辑器内部滚动；
/// 角色卡片收起占一行、展开最多占上分区一半并独立滚动；
/// 下分区：参数设置（独立滚动，模型收进抽屉）；
/// 底部：生成控制条常驻钉底。
class WebLeftPanel extends ConsumerWidget {
  final ValueNotifier<bool> negativeModeNotifier;
  final bool isResizing;

  const WebLeftPanel({
    super.key,
    required this.negativeModeNotifier,
    this.isResizing = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final layoutState = ref.watch(layoutStateNotifierProvider);

    final width = layoutState.webLeftPanelExpanded
        ? layoutState.webLeftPanelWidth
        : 40.0;
    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(
        right: BorderSide(color: theme.dividerColor, width: 1),
      ),
    );

    final child = layoutState.webLeftPanelExpanded
        ? _buildExpanded(context, ref, layoutState, theme)
        : CollapsedPanel(
            icon: Icons.edit_note,
            label: context.l10n.generation_params,
            onTap: () => ref
                .read(layoutStateNotifierProvider.notifier)
                .setWebLeftPanelExpanded(true),
          );

    // 拖拽时不使用动画，避免粘滞感（与经典布局 LeftPanel 一致）
    if (isResizing) {
      return Container(width: width, decoration: decoration, child: child);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: decoration,
      child: child,
    );
  }

  Widget _buildExpanded(
    BuildContext context,
    WidgetRef ref,
    LayoutState layoutState,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // 头部条：折叠按钮不再悬浮，避免遮挡提示词工具栏
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                Icons.edit_note,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const Spacer(),
              CollapseButton(
                icon: Icons.chevron_left,
                onTap: () => ref
                    .read(layoutStateNotifierProvider.notifier)
                    .setWebLeftPanelExpanded(false),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        Expanded(
          child: WebPanelSplit(
            ratio: layoutState.webPromptSectionRatio,
            onRatioChanged: (ratio) => ref
                .read(layoutStateNotifierProvider.notifier)
                .setWebPromptSectionRatio(ratio),
            onRatioReset: () => ref
                .read(layoutStateNotifierProvider.notifier)
                .setWebPromptSectionRatio(0.5),
            topSection: LayoutBuilder(
              builder: (context, constraints) {
                final maxCardsHeight = constraints.maxHeight * 0.5;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Column(
                    children: [
                      // 编辑器填充角色卡片未占用的全部剩余高度
                      Expanded(
                        child: PromptInputWidget(
                          showMaximizeButton: false,
                          negativeModeNotifier: negativeModeNotifier,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 角色卡片：收起时占一行，展开最多占上分区一半并内部滚动
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxCardsHeight),
                        child: const SingleChildScrollView(
                          child: CharacterPanel(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            bottomSection: const ParameterPanel(collapsibleModelSelector: true),
            footer: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                border: Border(
                  top: BorderSide(color: theme.dividerColor, width: 1),
                ),
              ),
              child: const GenerationControls(),
            ),
          ),
        ),
      ],
    );
  }
}
