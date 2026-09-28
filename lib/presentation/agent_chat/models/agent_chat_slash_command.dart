import 'package:flutter/foundation.dart';

import '../../../core/agent/harness/harness_types.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/agent_chat_panel_view_data.dart';
import 'agent_chat_slash_syntax.dart';

export 'agent_chat_slash_syntax.dart';

enum AgentChatSlashCommandKind { skill, session }

/// 输入框开头 `/` 菜单里的一条：引用技能，或执行一个会话动作。
@immutable
class AgentChatSlashCommand {
  const AgentChatSlashCommand.skill({
    required this.name,
    required this.description,
  }) : kind = AgentChatSlashCommandKind.skill,
       sessionAction = null;

  const AgentChatSlashCommand.session({
    required this.name,
    required this.description,
    required AgentChatMoreAction action,
  }) : kind = AgentChatSlashCommandKind.session,
       sessionAction = action;

  final String name;
  final String description;
  final AgentChatSlashCommandKind kind;
  final AgentChatMoreAction? sessionAction;
}

/// 会话命令名与动作的唯一映射：菜单渲染与发送时的兜底解析共用这一份。
const Map<String, AgentChatMoreAction> agentChatSessionCommands = {
  'new': AgentChatMoreAction.newSession,
  'compact': AgentChatMoreAction.compact,
  'rename': AgentChatMoreAction.rename,
  'delete': AgentChatMoreAction.delete,
};

/// 已启用技能与可用会话动作组成的菜单条目。
List<AgentChatSlashCommand> buildSlashCommands({
  required List<HarnessSkill> skills,
  required AppLocalizations l10n,
  required bool sessionActionsEnabled,
}) {
  final sortedSkills = [...skills]..sort((a, b) => a.name.compareTo(b.name));
  return [
    for (final skill in sortedSkills)
      AgentChatSlashCommand.skill(
        name: skill.name,
        description: skill.description,
      ),
    if (sessionActionsEnabled)
      for (final entry in agentChatSessionCommands.entries)
        AgentChatSlashCommand.session(
          name: entry.key,
          description: sessionCommandDescription(l10n, entry.value),
          action: entry.value,
        ),
  ];
}

String sessionCommandDescription(
  AppLocalizations l10n,
  AgentChatMoreAction action,
) => switch (action) {
  AgentChatMoreAction.newSession => l10n.agentChat_newChat,
  AgentChatMoreAction.compact => l10n.agentChat_compact,
  AgentChatMoreAction.rename => l10n.common_rename,
  AgentChatMoreAction.delete => l10n.common_delete,
};

/// 发送时兜底：整条输入只是一个会话命令时返回对应动作。
AgentChatMoreAction? resolveSessionCommand(String text) {
  final token = parseLeadingSlashToken(text);
  if (token == null || token.trailingText.isNotEmpty) return null;
  return agentChatSessionCommands[token.name.toLowerCase()];
}

/// 名称前缀、名称包含、描述包含三档排序，同档保持原顺序。
List<AgentChatSlashCommand> filterSlashCommands(
  Iterable<AgentChatSlashCommand> commands,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return commands.toList(growable: false);
  final byPrefix = <AgentChatSlashCommand>[];
  final byName = <AgentChatSlashCommand>[];
  final byDescription = <AgentChatSlashCommand>[];
  for (final command in commands) {
    final name = command.name.toLowerCase();
    if (name.startsWith(normalized)) {
      byPrefix.add(command);
    } else if (name.contains(normalized)) {
      byName.add(command);
    } else if (command.description.toLowerCase().contains(normalized)) {
      byDescription.add(command);
    }
  }
  return [...byPrefix, ...byName, ...byDescription];
}
