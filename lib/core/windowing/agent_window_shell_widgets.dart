import 'package:flutter/material.dart';

import '../agent/agent_tool_presentation.dart';
import 'agent_chat_shared_widgets.dart';
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
  const AgentWindowToolActivityTile({
    required this.activity,
    required this.copyText,
    super.key,
  });

  final Map activity;
  final ValueChanged<String> copyText;

  @override
  Widget build(BuildContext context) {
    final toolName = activity['toolName']?.toString() ?? '';
    final running = activity['status'] == 'running';
    final failed = activity['status'] == 'failed';
    final content = activity['content']?.toString() ?? '';
    final summary = AgentToolPresentation.summary(content, fallback: toolName);
    final args = activity['args'];
    final detailSections = <String>[
      if (!(args is Map && args.isEmpty))
        AgentToolPresentation.formattedValue(args),
      if (content.trim().isNotEmpty)
        AgentToolPresentation.formattedDetails(content),
    ].where((value) => value.isNotEmpty).toSet();
    final detailText = detailSections.join('\n\n');
    final statusRow = Row(
      children: [
        if (running)
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          )
        else
          Icon(
            failed ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: failed ? Theme.of(context).colorScheme.error : null,
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
    return Semantics(
      liveRegion: running,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
        child: Material(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(9),
          clipBehavior: Clip.antiAlias,
          child: detailText.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: statusRow,
                )
              : Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: ValueKey(
                      'agent-window-tool-activity-${activity['toolCallId']}',
                    ),
                    initiallyExpanded: false,
                    minTileHeight: 38,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                    childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    title: statusRow,
                    children: [
                      AgentToolDetailSurface(
                        text: detailText,
                        copyTooltip: AppLocalizations.of(context)!.common_copy,
                        onCopy: () => copyText(detailText),
                        maxHeight: 180,
                        margin: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class AgentWindowModelButton extends StatelessWidget {
  const AgentWindowModelButton({
    required this.payload,
    required this.sendCommand,
    super.key,
  });

  final Map<String, Object?> payload;
  final Future<Object?> Function(String, Map<String, Object?>) sendCommand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final models = payload['modelOptions'] is List
        ? payload['modelOptions'] as List
        : const [];
    final levels = payload['thinkingLevels'] is List
        ? payload['thinkingLevels'] as List
        : const [];
    final activeModel = payload['activeModel'] as String? ?? '';
    final activeProvider = payload['activeProviderId'] as String? ?? '';
    final activeLevel = payload['thinkingLevel'] as String? ?? 'off';
    return PopupMenuButton<Map>(
      enabled: models.isNotEmpty && payload['running'] != true,
      tooltip: l10n.agentChat_model,
      onSelected: (value) {
        if (value['type'] == 'thinking') {
          sendCommand('setThinkingLevel', {'value': value['value']});
        } else {
          sendCommand('selectModel', {
            'providerId': value['providerId'],
            'model': value['model'],
          });
        }
      },
      itemBuilder: (context) => [
        for (final raw in models)
          if (raw is Map)
            PopupMenuItem(
              value: raw,
              child: Row(
                children: [
                  if (raw['providerId'] == activeProvider &&
                      raw['model'] == activeModel)
                    Icon(
                      Icons.check,
                      size: 15,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 15),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${raw['providerName']} / ${raw['displayName']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        if (levels.isNotEmpty) const PopupMenuDivider(),
        if (levels.isNotEmpty)
          PopupMenuItem(
            enabled: false,
            child: Text(l10n.agentChat_reasoningLevel),
          ),
        for (final level in levels)
          PopupMenuItem(
            value: {'type': 'thinking', 'value': level},
            child: Row(
              children: [
                if (level == activeLevel)
                  Icon(
                    Icons.check,
                    size: 15,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 15),
                const SizedBox(width: 7),
                Text(_thinkingLabel(l10n, level.toString())),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 128),
          child: Text(
            activeModel.isEmpty ? l10n.agentChat_noModel : activeModel,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _thinkingLabel(AppLocalizations l10n, String value) => switch (value) {
    'minimal' => l10n.agentChat_reasoningMinimal,
    'low' => l10n.agentChat_reasoningLow,
    'medium' => l10n.agentChat_reasoningMedium,
    'high' => l10n.agentChat_reasoningHigh,
    'xhigh' => l10n.agentChat_reasoningXHigh,
    'max' => l10n.agentChat_reasoningMax,
    _ => l10n.agentChat_reasoningOff,
  };
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

class AgentWindowQueuePanel extends StatelessWidget {
  const AgentWindowQueuePanel({
    required this.queue,
    required this.edit,
    required this.remove,
    required this.clear,
    super.key,
  });

  final List queue;
  final Future<void> Function(Map item) edit;
  final Future<Object?> Function(Map item) remove;
  final Future<Object?> Function() clear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        minTileHeight: 38,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 8, 6),
        leading: Icon(
          Icons.queue_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        title: Text('${l10n.agentChat_queued} · ${queue.length}'),
        trailing: TextButton(onPressed: clear, child: Text(l10n.common_clear)),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              primary: false,
              shrinkWrap: true,
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final raw = queue[index];
                if (raw is! Map) return const SizedBox.shrink();
                return Row(
                  children: [
                    Text(
                      raw['kind'] == 'steering'
                          ? l10n.agentChat_queueSteering
                          : l10n.agentChat_queueFollowUp,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        raw['text']?.toString().trim().isNotEmpty == true
                            ? raw['text'].toString().trim()
                            : l10n.agentChat_queued,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.common_edit,
                      onPressed: raw['editable'] == false
                          ? null
                          : () => edit(raw),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                    ),
                    IconButton(
                      tooltip: l10n.common_delete,
                      onPressed: () => remove(raw),
                      icon: const Icon(Icons.close_rounded, size: 17),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
