import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/windowing/workspace_side_panel_contract.dart';
import '../../../agent_chat/widgets/agent_chat_panel.dart';
import '../../../providers/layout_state_provider.dart';
import 'collapsed_panel.dart';
import 'history_panel.dart';

/// 右侧面板组件
///
/// 聊天与历史是两个独立页面：折叠态为竖排双入口，点击展开对应页面；
/// 展开态顶部仅保留折叠按钮，页面内不再混合 Tab。当前视图持久化。
class RightPanel extends ConsumerStatefulWidget {
  final bool isResizing;
  final double? width;
  final bool? expanded;

  const RightPanel({
    super.key,
    this.isResizing = false,
    this.width,
    this.expanded,
  });

  @override
  ConsumerState<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends ConsumerState<RightPanel> {
  int _activeView = 1;

  @override
  void initState() {
    super.initState();
    final saved = ref
        .read(localStorageServiceProvider)
        .getSetting<int>(StorageKeys.rightPanelTab);
    if (saved != null && saved >= 0 && saved < 2) {
      _activeView = saved;
    }
  }

  void _persistView(int index) {
    ref
        .read(localStorageServiceProvider)
        .setSetting(StorageKeys.rightPanelTab, index);
  }

  /// 展开面板并显示指定页面（0=聊天，1=历史）。
  void _expandTo(int index) {
    setState(() => _activeView = index);
    _persistView(index);
    ref.read(layoutStateNotifierProvider.notifier).setRightPanelExpanded(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final layoutState = ref.watch(layoutStateNotifierProvider);
    final expanded = widget.expanded ?? layoutState.rightPanelExpanded;

    final width =
        widget.width ??
        (expanded
            ? WorkspaceSidePanelContract.constrainedWorkspaceWidth(
                workspaceWidth: MediaQuery.sizeOf(context).width,
                preferredWidth: layoutState.rightPanelWidth,
              )
            : 40.0);
    final decoration = BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(left: BorderSide(color: theme.dividerColor, width: 1)),
    );

    final Widget child;
    if (expanded) {
      // 每页唯一一行 header：聊天页的会话行内含折叠按钮与标题
      // （见 AgentChatPanel），历史页用 HistoryPanel 自带 header。
      child = _activeView == 0
          ? const AgentChatPanel()
          : const HistoryPanel(embedded: false);
    } else {
      // 折叠态：竖排两个独立入口（聊天 / 历史），点击展开对应页面。
      child = Column(
        children: [
          Expanded(
            child: CollapsedPanel(
              icon: Icons.smart_toy_outlined,
              label: l10n.agentChat_tab,
              active: _activeView == 0,
              onTap: () => _expandTo(0),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CollapsedPanel(
              icon: Icons.history,
              label: l10n.generation_history,
              active: _activeView == 1,
              onTap: () => _expandTo(1),
            ),
          ),
        ],
      );
    }

    return Container(
      key: const ValueKey('generation-right-panel'),
      width: width,
      decoration: decoration,
      child: child,
    );
  }
}
