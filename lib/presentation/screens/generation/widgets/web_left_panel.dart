import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/layout_state_provider.dart';
import 'character_panel.dart';
import 'collapsed_panel.dart';
import 'generation_controls/generation_controls.dart';
import 'parameter_panel.dart';
import 'prompt_input.dart';
import 'size_selector.dart';

/// 官网式布局左栏
///
/// 一体式滚动列：尺寸设置置顶，提示词编辑器随内容自由增高（官网式），
/// 角色卡片与其余参数依次排列在同一滚动域中；
/// 生成控制条常驻钉底，不随内容滚动。
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
        ? _buildExpanded(context, ref, theme)
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

  Widget _buildExpanded(BuildContext context, WidgetRef ref, ThemeData theme) {
    final size = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => (width: params.width, height: params.height),
      ),
    );

    return Column(
      children: [
        // 头部条：折叠按钮不悬浮，避免遮挡提示词工具栏
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

        // 一体式滚动列
        // 用 SingleChildScrollView 而非 ListView：列内容有限，且需要
        // 保持子项 State（撤销历史、角色卡展开态）不随滚动销毁
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 尺寸设置置顶：位于提示词上方，不会被长提示词推走
                Text(
                  context.l10n.generation_imageSize,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SizeSelector(
                  width: size.width,
                  height: size.height,
                  onChanged: (width, height) => ref
                      .read(generationParamsNotifierProvider.notifier)
                      .updateSize(width, height),
                ),
                const SizedBox(height: 10),

                // 提示词：随内容自由增高（官网式）
                PromptInputWidget(
                  autoGrow: true,
                  showMaximizeButton: false,
                  negativeModeNotifier: negativeModeNotifier,
                ),
                const SizedBox(height: 8),

                // 角色卡片：内嵌堆叠，跟随提示词之下
                const CharacterPanel(),
                const SizedBox(height: 8),

                // 其余参数（尺寸已置顶不再重复；紧凑嵌入，模型收进抽屉）
                const ParameterPanel(
                  embedded: true,
                  compact: true,
                  showSizeSection: false,
                  collapsibleModelSelector: true,
                ),
              ],
            ),
          ),
        ),

        // 钉底生成控制条（压扁）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.5),
            border: Border(
              top: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: const GenerationControls(compact: true),
        ),
      ],
    );
  }
}
