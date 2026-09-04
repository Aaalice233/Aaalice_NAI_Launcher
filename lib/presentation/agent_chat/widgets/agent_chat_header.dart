import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nai_launcher/presentation/router/app_routes.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/windowing/agent_chat_session_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../adaptive/interaction_policy.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../widgets/common/workspace_panel_header.dart';
import 'agent_chat_panel_view_data.dart';

class AgentChatHeader extends StatelessWidget {
  const AgentChatHeader({
    super.key,
    required this.viewData,
    required this.commands,
  });

  final AgentChatPanelViewData viewData;
  final AgentChatPanelCommands commands;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fullScreenLayout = viewData.fullScreen;
    final leadingTooltip = viewData.fullScreen
        ? MaterialLocalizations.of(context).backButtonTooltip
        : MaterialLocalizations.of(context).closeButtonTooltip;
    final collapseButton = _HeaderIconButton(
      key: ValueKey(
        fullScreenLayout ? 'agent-chat-mobile-close' : 'agent-chat-collapse',
      ),
      icon: fullScreenLayout
          ? Icons.arrow_back_rounded
          : Icons.chevron_right_rounded,
      tooltip: leadingTooltip,
      onPressed: viewData.onClose ?? commands.collapse,
    );
    final header = WorkspacePanelHeader(
      key: ValueKey(
        fullScreenLayout
            ? 'agent-chat-mobile-header'
            : viewData.compactWidth
            ? 'agent-chat-compact-header'
            : 'agent-chat-desktop-header',
      ),
      leading: collapseButton,
      icon: Icons.auto_awesome_rounded,
      title: SizedBox(height: 48, child: _sessionSelector(context)),
      actions: [
        _HeaderIconButton(
          key: ValueKey(
            fullScreenLayout
                ? 'agent-chat-mobile-new-session'
                : 'agent-chat-new-session',
          ),
          icon: Icons.add_comment_outlined,
          tooltip: l10n.agentChat_newChat,
          onPressed: viewData.sessionActionsEnabled
              ? commands.newSession
              : null,
        ),
        _moreMenu(context, l10n),
      ],
    );
    return viewData.mobileHeaderWrapper?.call(header) ?? header;
  }

  Widget _moreMenu(BuildContext context, AppLocalizations l10n) {
    final hasActiveSession = viewData.state.sessions.any(
      (session) => session.id == viewData.state.activeSessionId,
    );
    final colors = Theme.of(context).colorScheme;
    final controlExtent = context.interactionPolicy.minimumControlExtent;
    return PopupMenuButton<String>(
      key: ValueKey(
        viewData.fullScreen
            ? 'agent-chat-mobile-more'
            : viewData.compactWidth
            ? 'agent-chat-compact-more'
            : 'agent-chat-desktop-more',
      ),
      tooltip: l10n.agentChat_moreActions,
      useRootNavigator: true,
      constraints: const BoxConstraints(minWidth: 220),
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded, size: 22),
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size.square(controlExtent)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colors.surfaceContainerHighest;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colors.surfaceContainerHigh;
          }
          return Colors.transparent;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      onSelected: (value) async {
        switch (value) {
          case 'rename':
            await commands.moreAction(AgentChatMoreAction.rename);
            return;
          case 'compact':
            await commands.moreAction(AgentChatMoreAction.compact);
            return;
          case 'delete':
            await commands.moreAction(AgentChatMoreAction.delete);
            return;
          case 'settings':
            if (context.mounted) _openAgentSettings(context);
            return;
        }
      },
      itemBuilder: (_) => [
        if (hasActiveSession && viewData.sessionActionsEnabled) ...[
          _menuItem('rename', Icons.edit_outlined, l10n.common_rename),
          _menuItem('compact', Icons.compress_rounded, l10n.agentChat_compact),
          _menuItem(
            'delete',
            Icons.delete_outline_rounded,
            l10n.common_delete,
            color: Theme.of(context).colorScheme.error,
          ),
          const PopupMenuDivider(),
        ],
        _menuItem('settings', Icons.settings_outlined, l10n.settings_agent),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(label, maxLines: 1)),
      ],
    ),
  );

  void _openAgentSettings(BuildContext context) {
    final callback = viewData.onOpenSettings;
    if (callback != null) {
      callback();
      return;
    }
    context.go('${AppRoutes.settings}?section=agent');
  }

  Widget _sessionSelector(BuildContext context) {
    final state = viewData.state;
    return AgentChatSessionPicker(
      key: const ValueKey('agent-chat-session-selector'),
      sessions: [
        for (final session in state.sessions)
          AgentChatSessionOption(
            id: session.id,
            name: session.name,
            updatedAt: session.updatedAt,
          ),
      ],
      activeSessionId: state.activeSessionId,
      enabled: viewData.sessionActionsEnabled,
      touchOptimized: context.interactionPolicy.shouldExposeTouchAlternatives,
      compactTitle: true,
      onSelect: commands.selectSession,
      onNew: commands.newSession,
      onRename: commands.renameSession,
      onDelete: commands.deleteSession,
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 22),
    tooltip: tooltip,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: BoxConstraints.tightFor(
      width: context.interactionPolicy.minimumControlExtent,
      height: context.interactionPolicy.minimumControlExtent,
    ),
  );
}

String agentPermissionModeLabel(
  AppLocalizations l10n,
  AgentPermissionMode mode,
) => switch (mode) {
  AgentPermissionMode.safe => l10n.agentChat_permissionSafe,
  AgentPermissionMode.askBeforeSensitiveActions => l10n.agentChat_permissionAsk,
  AgentPermissionMode.fullAccess => l10n.agentChat_permissionFull,
};

String agentPermissionModeDescription(
  AppLocalizations l10n,
  AgentPermissionMode mode,
) => switch (mode) {
  AgentPermissionMode.safe => l10n.agentChat_permissionSafeDescription,
  AgentPermissionMode.askBeforeSensitiveActions =>
    l10n.agentChat_permissionAskDescription,
  AgentPermissionMode.fullAccess => l10n.agentChat_permissionFullDescription,
};
