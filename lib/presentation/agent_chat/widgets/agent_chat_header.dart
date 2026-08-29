import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nai_launcher/presentation/router/app_routes.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/windowing/agent_window_runtime.dart';
import '../../../l10n/app_localizations.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../providers/agent_chat_session_view.dart';
import 'agent_chat_panel_view_data.dart';

class AgentChatHeader extends StatelessWidget {
  const AgentChatHeader({
    super.key,
    required this.viewData,
    required this.commands,
  });

  static const String _menuNewSession = '__new_session__';
  static const String _menuRenamePrefix = 'rename:';
  static const String _menuDeletePrefix = 'delete:';

  final AgentChatPanelViewData viewData;
  final AgentChatPanelCommands commands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    if (viewData.mobile) return _mobile(context, theme, l10n);
    if (viewData.compactWidth) return _compact(context, theme, l10n);
    Widget iconButton({
      Key? key,
      required IconData icon,
      required String tooltip,
      required VoidCallback? onTap,
    }) => SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        key: key,
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
    return Padding(
      key: const ValueKey('agent-chat-desktop-header'),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Row(
        children: [
          iconButton(
            key: const ValueKey('agent-chat-collapse'),
            icon: Icons.chevron_right_rounded,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onTap: commands.collapse,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              l10n.agentChat_tab,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          iconButton(
            icon: Icons.add_comment_outlined,
            tooltip: l10n.agentChat_newChat,
            onTap: viewData.sessionActionsEnabled ? commands.newSession : null,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: viewData.width >= 760 ? 260 : 180,
                ),
                child: SizedBox(
                  height: 30,
                  child: _sessionSelector(context, theme, l10n),
                ),
              ),
            ),
          ),
          if (AgentWindowRuntime.isDesktop)
            iconButton(
              key: const ValueKey('agent-chat-detach-window'),
              icon: Icons.open_in_new_rounded,
              tooltip: l10n.agentChat_detachWindow,
              onTap: commands.detach,
            ),
          if (viewData.state.skills.isNotEmpty)
            SizedBox(
              width: 32,
              height: 32,
              child: Tooltip(
                message: viewData.state.skills
                    .map((skill) => skill.name)
                    .take(6)
                    .join(', '),
                child: Center(
                  child: Icon(
                    Icons.extension_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          iconButton(
            icon: Icons.settings_outlined,
            tooltip: l10n.settings_agent,
            onTap: () => _openAgentSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _compact(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    Widget action({
      required Key key,
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
    }) => IconButton(
      key: key,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
    );
    return Padding(
      key: const ValueKey('agent-chat-compact-header'),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          action(
            key: const ValueKey('agent-chat-collapse'),
            icon: Icons.chevron_right_rounded,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: commands.collapse,
          ),
          Expanded(
            child: SizedBox(
              height: 40,
              child: _sessionSelector(context, theme, l10n),
            ),
          ),
          action(
            key: const ValueKey('agent-chat-compact-new-session'),
            icon: Icons.add_comment_outlined,
            tooltip: l10n.agentChat_newChat,
            onPressed: viewData.sessionActionsEnabled
                ? commands.newSession
                : null,
          ),
          PopupMenuButton<String>(
            key: const ValueKey('agent-chat-compact-more'),
            tooltip: l10n.agentChat_moreActions,
            onSelected: (value) {
              if (value == 'detach') commands.detach();
              if (value == 'settings') _openAgentSettings(context);
            },
            itemBuilder: (_) => [
              if (AgentWindowRuntime.isDesktop)
                PopupMenuItem(
                  value: 'detach',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.open_in_new_rounded),
                    title: Text(l10n.agentChat_detachWindow),
                  ),
                ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n.settings_agent),
                ),
              ),
            ],
            child: const SizedBox.square(
              dimension: 40,
              child: Icon(Icons.more_horiz_rounded, size: 19),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final headerHeight = MediaQuery.textScalerOf(
      context,
    ).scale(48).clamp(48.0, 72.0);
    final header = Padding(
      key: const ValueKey('agent-chat-mobile-header'),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('agent-chat-mobile-close'),
            onPressed: viewData.onClose ?? commands.collapse,
            icon: Icon(
              viewData.fullScreen
                  ? Icons.arrow_back_rounded
                  : Icons.chevron_right_rounded,
            ),
            tooltip: viewData.fullScreen
                ? MaterialLocalizations.of(context).backButtonTooltip
                : MaterialLocalizations.of(context).closeButtonTooltip,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          ),
          IconButton(
            key: const ValueKey('agent-chat-mobile-settings'),
            onPressed: () => _openAgentSettings(context),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings_agent,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SizedBox(
              height: headerHeight,
              child: _sessionSelector(context, theme, l10n, mobileHeader: true),
            ),
          ),
          IconButton(
            key: const ValueKey('agent-chat-mobile-new-session'),
            onPressed: viewData.sessionActionsEnabled
                ? commands.newSession
                : null,
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: l10n.agentChat_newChat,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          ),
        ],
      ),
    );
    return viewData.mobileHeaderWrapper?.call(header) ?? header;
  }

  void _openAgentSettings(BuildContext context) {
    final callback = viewData.onOpenSettings;
    if (callback != null) {
      callback();
      return;
    }
    context.go('${AppRoutes.settings}?section=agent');
  }

  Widget _sessionSelector(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n, {
    bool mobileHeader = false,
  }) {
    final state = viewData.state;
    final current = state.sessions
        .where((session) => session.id == state.activeSessionId)
        .firstOrNull;
    final label = current == null || current.name.isEmpty
        ? l10n.agentChat_untitled
        : current.name;
    return PopupMenuButton<String>(
      key: const ValueKey('agent-chat-session-selector'),
      enabled: viewData.sessionActionsEnabled,
      tooltip: label,
      onSelected: (value) => _onSelected(value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _menuNewSession,
          height: viewData.mobile ? 48 : 36,
          child: Row(
            children: [
              Icon(
                Icons.add_comment_outlined,
                size: 15,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.agentChat_newChat,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (state.sessions.isEmpty)
          PopupMenuItem(
            enabled: false,
            height: viewData.mobile ? 48 : 36,
            child: Text(
              l10n.agentChat_untitled,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        for (final session in state.sessions)
          PopupMenuItem(
            value: session.id,
            height: viewData.mobile ? 56 : 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _SessionMenuRow(
              session: session,
              label: session.name.isEmpty
                  ? l10n.agentChat_untitled
                  : session.name,
              active: session.id == state.activeSessionId,
              alwaysShowActions: viewData.mobile,
              touchOptimized: viewData.mobile,
              onRename: () =>
                  Navigator.of(context).pop('$_menuRenamePrefix${session.id}'),
              onDelete: () =>
                  Navigator.of(context).pop('$_menuDeletePrefix${session.id}'),
            ),
          ),
      ],
      child: Container(
        width: viewData.mobile ? double.infinity : null,
        constraints: viewData.mobile
            ? const BoxConstraints(minHeight: 48)
            : const BoxConstraints(),
        padding: EdgeInsets.symmetric(
          horizontal: mobileHeader ? 4 : (viewData.mobile ? 12 : 8),
          vertical: mobileHeader ? 2 : 6,
        ),
        margin: EdgeInsets.symmetric(horizontal: viewData.mobile ? 0 : 4),
        decoration: BoxDecoration(
          color: mobileHeader
              ? Colors.transparent
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: mobileHeader
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settings_promptAssistant,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onSelected(String value) async {
    if (value == _menuNewSession) return commands.newSession();
    if (value.startsWith(_menuRenamePrefix)) {
      return commands.renameSession(value.substring(_menuRenamePrefix.length));
    }
    if (value.startsWith(_menuDeletePrefix)) {
      return commands.deleteSession(value.substring(_menuDeletePrefix.length));
    }
    if (value.isNotEmpty) await commands.selectSession(value);
  }
}

class _SessionMenuRow extends StatefulWidget {
  const _SessionMenuRow({
    required this.session,
    required this.label,
    required this.active,
    required this.alwaysShowActions,
    required this.touchOptimized,
    required this.onRename,
    required this.onDelete,
  });

  final AgentChatSessionSummary session;
  final String label;
  final bool active;
  final bool alwaysShowActions;
  final bool touchOptimized;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_SessionMenuRow> createState() => _SessionMenuRowState();
}

class _SessionMenuRowState extends State<_SessionMenuRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Row(
        children: [
          if (widget.active)
            Icon(Icons.check, size: 14, color: theme.colorScheme.primary)
          else
            const SizedBox(width: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          if (_hovering || widget.alwaysShowActions) ...[
            _MenuIconAction(
              icon: Icons.edit_outlined,
              tooltip: context.l10n.common_rename,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              touchOptimized: widget.touchOptimized,
              onTap: widget.onRename,
            ),
            if (!widget.touchOptimized) const SizedBox(width: 2),
            _MenuIconAction(
              icon: Icons.delete_outline,
              tooltip: context.l10n.common_delete,
              color: theme.colorScheme.error.withValues(alpha: 0.8),
              touchOptimized: widget.touchOptimized,
              onTap: widget.onDelete,
            ),
          ] else
            Text(
              _formatTime(widget.session.updatedAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.month}/${local.day}';
  }
}

class _MenuIconAction extends StatelessWidget {
  const _MenuIconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.touchOptimized,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final bool touchOptimized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    waitDuration: const Duration(milliseconds: 400),
    child: SizedBox(
      width: touchOptimized ? 48 : 20,
      height: touchOptimized ? 48 : 20,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Icon(icon, size: touchOptimized ? 18 : 14, color: color),
      ),
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
