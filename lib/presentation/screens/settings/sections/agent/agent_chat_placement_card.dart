import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../agent_chat/providers/agent_chat_dock_provider.dart';
import '../../../../widgets/common/horizontal_segmented_control.dart';
import '../../widgets/settings_card.dart';

/// 聊天在宽屏工作区的位置：右栏停靠方式与应用内浮窗。
///
/// 两项都是本机布局偏好，不随智能体配置导出，也不参与云同步。
class AgentChatPlacementCard extends ConsumerWidget {
  const AgentChatPlacementCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final placement = ref.watch(
      agentChatDockProvider.select(
        (dock) => (mode: dock.mode, floating: dock.floatingEnabled),
      ),
    );
    final dock = ref.read(agentChatDockProvider.notifier);
    return SettingsCard(
      key: const ValueKey('agent-chat-placement-card'),
      title: l10n.agentSettings_chatPlacement,
      description: l10n.agentSettings_chatPlacementDescription,
      icon: Icons.vertical_split_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.agentSettings_dockLayout,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.agentSettings_dockLayoutDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          HorizontalSegmentedControl(
            child: SegmentedButton<AgentChatDockMode>(
              key: const ValueKey('agent-chat-dock-mode'),
              segments: [
                ButtonSegment(
                  value: AgentChatDockMode.exclusive,
                  label: Text(l10n.agentSettings_dockExclusive),
                ),
                ButtonSegment(
                  value: AgentChatDockMode.stacked,
                  label: Text(l10n.agentSettings_dockStacked),
                ),
                ButtonSegment(
                  value: AgentChatDockMode.sideBySide,
                  label: Text(l10n.agentSettings_dockSideBySide),
                ),
              ],
              selected: {placement.mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  unawaited(dock.setMode(selection.single)),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const ValueKey('agent-chat-floating-switch'),
            contentPadding: EdgeInsets.zero,
            value: placement.floating,
            title: Text(l10n.agentSettings_floatingWindow),
            subtitle: Text(l10n.agentSettings_floatingWindowDescription),
            onChanged: (enabled) => unawaited(dock.setFloatingEnabled(enabled)),
          ),
        ],
      ),
    );
  }
}
