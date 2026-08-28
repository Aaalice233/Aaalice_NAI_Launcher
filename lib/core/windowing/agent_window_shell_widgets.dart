import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class AgentWindowPermissionModeButton extends StatelessWidget {
  const AgentWindowPermissionModeButton({
    required this.sendCommand,
    required this.payload,
    super.key,
  });

  final Future<Object?> Function(String, Map<String, Object?>) sendCommand;
  final Map<String, Object?> payload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = payload['permissionMode'] as String? ?? 'safe';
    final label = switch (current) {
      'fullAccess' => l10n.agentChat_permissionFull,
      'ask' => l10n.agentChat_permissionAsk,
      _ => l10n.agentChat_permissionSafe,
    };
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: (value) => sendCommand('setPermissionMode', {'value': value}),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'safe',
          child: Text(l10n.agentChat_permissionSafe),
        ),
        PopupMenuItem(value: 'ask', child: Text(l10n.agentChat_permissionAsk)),
        PopupMenuItem(
          value: 'fullAccess',
          child: Text(l10n.agentChat_permissionFull),
        ),
      ],
      child: Chip(
        avatar: const Icon(Icons.shield_outlined, size: 16),
        label: Text(label),
      ),
    );
  }
}

class AgentWindowToolActivityTile extends StatelessWidget {
  const AgentWindowToolActivityTile({required this.activity, super.key});

  final Map activity;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: activity['status'] == 'running'
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            activity['status'] == 'failed'
                ? Icons.error_outline
                : Icons.check_circle_outline,
            size: 18,
          ),
    title: Text(activity['toolName']?.toString() ?? ''),
    subtitle: activity['content']?.toString().isNotEmpty == true
        ? Text(
            activity['content'].toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        : null,
  );
}

class AgentWindowMessageList extends StatelessWidget {
  const AgentWindowMessageList({
    required this.messages,
    required this.controller,
    super.key,
  });

  final List messages;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (messages.isEmpty) {
      return Center(child: Text(l10n.agentChat_heroSubtitle));
    }
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = Map<Object?, Object?>.from(messages[index] as Map);
        final user = message['role'] == 'user';
        return Align(
          alignment: user ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: user
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(message['text'] as String? ?? ''),
          ),
        );
      },
    );
  }
}

class AgentWindowApprovalBar extends StatelessWidget {
  const AgentWindowApprovalBar({
    required this.approval,
    required this.resolve,
    super.key,
  });

  final Map<Object?, Object?> approval;
  final void Function(bool) resolve;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.gpp_maybe_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.agentChat_approvalTitle(
                      approval['toolName'] as String? ?? '',
                    ),
                  ),
                  if (approval['estimatedAnlas'] case final int cost)
                    Text(
                      l10n.agentChat_approvalEstimatedAnlas(cost),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => resolve(false),
              child: Text(l10n.agentChat_approvalDeny),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () => resolve(true),
              child: Text(l10n.agentChat_approvalAllow),
            ),
          ],
        ),
      ),
    );
  }
}

class AgentWindowResourceList extends StatelessWidget {
  const AgentWindowResourceList({
    required this.resources,
    required this.remove,
    super.key,
  });

  final List resources;
  final void Function(Object? encoded) remove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
        scrollDirection: Axis.horizontal,
        itemCount: resources.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final resource = Map<Object?, Object?>.from(resources[index] as Map);
          final display = resource['display'];
          final label = display is Map
              ? (display['name'] ?? display['title'])?.toString()
              : null;
          final unavailable = resource['unavailable'] == true;
          return Chip(
            avatar: Icon(unavailable ? Icons.link_off : Icons.link, size: 16),
            label: Text(
              unavailable
                  ? '${label ?? resource['resourceId']} · ${l10n.agentChat_resourceUnavailable}'
                  : label ?? resource['resourceId']?.toString() ?? '',
            ),
            onDeleted: () => remove(resource['encoded']),
          );
        },
      ),
    );
  }
}
