import 'dart:convert';

import 'package:flutter/material.dart';

import '../agent/agent_tool_presentation.dart';
import 'agent_chat_shared_widgets.dart';
import '../../l10n/app_localizations.dart';

class AgentWindowHeaderAction extends StatelessWidget {
  const AgentWindowHeaderAction({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.showLabel,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final bool showLabel;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: showLabel ? 8 : 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            if (showLabel) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 78),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final decorated = Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.36)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: onPressed == null
          ? content
          : InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(10),
              child: content,
            ),
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        child: decorated,
      ),
    );
  }
}

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
      'askBeforeSensitiveActions' => l10n.agentChat_permissionAsk,
      _ => l10n.agentChat_permissionSafe,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: PopupMenuButton<String>(
        key: const ValueKey('agent-window-permission-mode'),
        enabled:
            payload['running'] != true &&
            payload['sessionTransitioning'] != true,
        tooltip: label,
        onSelected: (value) =>
            sendCommand('setPermissionMode', {'value': value}),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'safe',
            child: Text(l10n.agentChat_permissionSafe),
          ),
          PopupMenuItem(
            value: 'askBeforeSensitiveActions',
            child: Text(l10n.agentChat_permissionAsk),
          ),
          PopupMenuItem(
            value: 'fullAccess',
            child: Text(l10n.agentChat_permissionFull),
          ),
        ],
        child: Chip(
          avatar: const Icon(Icons.shield_outlined, size: 16),
          label: Text(label),
        ),
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
    final summary = failed
        ? _agentWindowFailureSummary(context, content)
        : AgentToolPresentation.summary(content, fallback: toolName);
    final args = activity['args'];
    final detailSections = <String>[
      if (!(args is Map && args.isEmpty))
        AgentToolPresentation.formattedValue(args),
      if (content.trim().isNotEmpty)
        AgentToolPresentation.formattedDetails(content),
    ].where((value) => value.isNotEmpty).toSet();
    final detailText = detailSections.join('\n\n');
    final statusRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toolName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (summary.isNotEmpty && summary != toolName)
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return Semantics(
      liveRegion: running,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
        child: Material(
          key: ValueKey('agent-window-tool-activity-${activity['toolCallId']}'),
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
                    key: PageStorageKey(
                      'agent-window-tool-activity-expansion-${activity['toolCallId']}',
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

String _agentWindowFailureSummary(BuildContext context, String raw) {
  final status = RegExp(
    r'(?:http|status(?:\s+code)?)\D{0,12}([45]\d\d)',
    caseSensitive: false,
  ).firstMatch(raw)?.group(1);
  final error = AppLocalizations.of(context)!.common_error;
  return status == null ? error : '$error · HTTP $status';
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
    final activeModel = payload['activeModel'] as String? ?? '';
    final activeProvider = payload['activeProviderId'] as String? ?? '';
    final displayModel = _shortModelLabel(activeModel);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: PopupMenuButton<Map>(
        key: const ValueKey('agent-window-model'),
        enabled:
            models.isNotEmpty &&
            payload['running'] != true &&
            payload['sessionTransitioning'] != true,
        tooltip: l10n.agentChat_model,
        onSelected: (value) {
          sendCommand('selectModel', {
            'providerId': value['providerId'],
            'model': value['model'],
          });
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
        ],
        child: Chip(
          avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 128),
            child: Text(
              activeModel.isEmpty ? l10n.agentChat_noModel : displayModel,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }

  String _shortModelLabel(String label) {
    final routeName = label.trim().split('/').last;
    final words = routeName
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return label.trim();
    final selected = <String>[];
    for (final word in words) {
      final normalized = word.toLowerCase() == 'deepseek' ? 'DeepSeek' : word;
      final candidate = [...selected, normalized].join(' ');
      if (selected.isNotEmpty && candidate.length > 20) break;
      selected.add(normalized);
      if (selected.length == 3) break;
    }
    return selected.join(' ');
  }
}

class AgentWindowThinkingButton extends StatelessWidget {
  const AgentWindowThinkingButton({
    required this.payload,
    required this.sendCommand,
    super.key,
  });

  final Map<String, Object?> payload;
  final Future<Object?> Function(String, Map<String, Object?>) sendCommand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final levels = payload['thinkingLevels'] is List
        ? payload['thinkingLevels'] as List
        : const [];
    final activeLevel = payload['thinkingLevel'] as String? ?? 'off';
    final enabled =
        levels.isNotEmpty &&
        payload['running'] != true &&
        payload['sessionTransitioning'] != true;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: PopupMenuButton<String>(
        key: const ValueKey('agent-window-thinking'),
        enabled: enabled,
        tooltip: l10n.agentChat_reasoningLevel,
        onSelected: (value) =>
            sendCommand('setThinkingLevel', {'value': value}),
        itemBuilder: (context) => [
          for (final level in levels)
            PopupMenuItem<String>(
              value: level.toString(),
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
          avatar: const Icon(Icons.psychology_alt_outlined, size: 16),
          label: Text(_thinkingLabel(l10n, activeLevel)),
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
    final args = approval['args'];
    var details = '';
    if (args != null) {
      try {
        details = const JsonEncoder.withIndent('  ').convert(args);
      } on JsonUnsupportedObjectError {
        details = args.toString();
      }
    }
    final cost = approval['estimatedAnlas'];
    return LayoutBuilder(
      builder: (context, constraints) => AgentChatApprovalSurface(
        title: l10n.agentChat_approvalTitle(
          approval['toolName'] as String? ?? '',
        ),
        description: l10n.agentChat_approvalDescription,
        details: details,
        costLabel: cost is int
            ? l10n.agentChat_approvalEstimatedAnlas(cost)
            : null,
        denyLabel: l10n.agentChat_approvalDeny,
        allowLabel: l10n.agentChat_approvalAllow,
        touchOptimized: constraints.maxWidth < 600,
        onDeny: () => resolve(false),
        onAllow: () => resolve(true),
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
      key: const ValueKey('agent-window-resource-list'),
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
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
          final resourceLabel =
              label ?? resource['resourceId']?.toString() ?? '';
          return Material(
            color: unavailable
                ? Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.38)
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      unavailable ? Icons.link_off_rounded : Icons.link_rounded,
                      size: 17,
                      color: unavailable
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resourceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          if (unavailable)
                            Text(
                              l10n.agentChat_resourceUnavailable,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => remove(resource['encoded']),
                      icon: const Icon(Icons.close_rounded, size: 17),
                    ),
                  ],
                ),
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Material(
        key: const ValueKey('agent-window-queue-panel'),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const PageStorageKey('agent-window-queue-expansion'),
            minTileHeight: 38,
            tilePadding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 4, 6),
            leading: Icon(
              Icons.queue_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            title: Text('${l10n.agentChat_queued} · ${queue.length}'),
            trailing: TextButton(
              onPressed: clear,
              child: Text(l10n.common_clear),
            ),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  key: const PageStorageKey('agent-window-queue-list'),
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
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
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
        ),
      ),
    );
  }
}
