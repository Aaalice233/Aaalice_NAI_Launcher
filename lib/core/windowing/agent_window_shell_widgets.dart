import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' as md;

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

class AgentWindowMessageList extends StatefulWidget {
  const AgentWindowMessageList({
    required this.messages,
    required this.controller,
    required this.copyText,
    super.key,
  });

  final List messages;
  final ScrollController controller;
  final ValueChanged<String> copyText;

  @override
  State<AgentWindowMessageList> createState() => _AgentWindowMessageListState();
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

class _AgentWindowMessageListState extends State<AgentWindowMessageList> {
  bool _followLatest = true;
  String _lastSignature = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrollChanged);
  }

  @override
  void didUpdateWidget(covariant AgentWindowMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scrollChanged);
      widget.controller.addListener(_scrollChanged);
    }
    final signature = widget.messages.isEmpty
        ? ''
        : '${widget.messages.length}:${widget.messages.last.hashCode}';
    if (signature != _lastSignature) {
      _lastSignature = signature;
      if (_followLatest) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToLatest(animate: false),
        );
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrollChanged);
    super.dispose();
  }

  void _scrollChanged() {
    if (!widget.controller.hasClients) return;
    final next =
        widget.controller.position.maxScrollExtent - widget.controller.offset <
        96;
    if (next != _followLatest && mounted) setState(() => _followLatest = next);
  }

  void _scrollToLatest({bool animate = true}) {
    if (!widget.controller.hasClients) return;
    final target = widget.controller.position.maxScrollExtent;
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      widget.controller.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.controller.jumpTo(target);
    }
    if (!_followLatest) setState(() => _followLatest = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.messages.isEmpty) {
      return Center(child: Text(l10n.agentChat_heroSubtitle));
    }
    final items = _groupMessages(widget.messages);
    return Stack(
      children: [
        ListView.builder(
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildItem(context, items[index]),
        ),
        if (!_followLatest)
          Positioned(
            right: 16,
            bottom: 12,
            child: FilledButton.tonalIcon(
              onPressed: _scrollToLatest,
              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
              label: Text(l10n.agentChat_jumpToLatest),
            ),
          ),
      ],
    );
  }

  List<Object> _groupMessages(List messages) {
    final items = <Object>[];
    var index = 0;
    while (index < messages.length) {
      final message = Map<Object?, Object?>.from(messages[index] as Map);
      if (_isInvisibleToolAssistant(message) &&
          index + 1 < messages.length &&
          (messages[index + 1] as Map)['role'] == 'tool') {
        index++;
        continue;
      }
      if (message['role'] == 'tool') {
        final group = <Map<Object?, Object?>>[];
        while (index < messages.length) {
          final current = Map<Object?, Object?>.from(messages[index] as Map);
          if (current['role'] == 'tool') {
            group.add(current);
            index++;
            continue;
          }
          if (_isInvisibleToolAssistant(current) &&
              index + 1 < messages.length &&
              (messages[index + 1] as Map)['role'] == 'tool') {
            index++;
            continue;
          }
          break;
        }
        items.add(group);
      } else {
        items.add(message);
        index++;
      }
    }
    return items;
  }

  bool _isInvisibleToolAssistant(Map<Object?, Object?> message) =>
      message['role'] == 'assistant' &&
      (message['text']?.toString().trim().isEmpty ?? true) &&
      (message['thinking']?.toString().trim().isEmpty ?? true) &&
      message['stopReason'] == 'toolUse';

  Widget _buildItem(BuildContext context, Object item) {
    if (item is List<Map<Object?, Object?>>) {
      return _AgentWindowToolGroup(results: item);
    }
    final message = item as Map<Object?, Object?>;
    final role = message['role'];
    final text = message['text'] as String? ?? '';
    if (role == 'user') {
      final images = message['images'] is List
          ? message['images'] as List
          : const [];
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 620),
              margin: const EdgeInsets.only(left: 48),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (text.isNotEmpty) SelectableText(text),
                  for (final image in images)
                    if (image is Map) _AgentWindowImageCard(image: image),
                ],
              ),
            ),
            _copyButton(context, text),
            const SizedBox(height: 6),
          ],
        ),
      );
    }
    final thinking = message['thinking'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(right: 24, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (thinking.trim().isNotEmpty)
            _AgentWindowReasoning(thinking: thinking),
          if (text.trim().isNotEmpty)
            md.MarkdownBody(
              data: text,
              selectable: true,
              styleSheet: md.MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.55),
                  ),
            ),
          if (text.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: _copyButton(context, text),
            ),
        ],
      ),
    );
  }

  Widget _copyButton(BuildContext context, String text) => IconButton(
    tooltip: AppLocalizations.of(context)!.common_copy,
    visualDensity: VisualDensity.compact,
    onPressed: () => widget.copyText(text),
    icon: const Icon(Icons.copy_all_outlined, size: 15),
  );
}

class _AgentWindowReasoning extends StatelessWidget {
  const _AgentWindowReasoning({required this.thinking});

  final String thinking;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      minTileHeight: 34,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: Icon(
        Icons.psychology_alt_outlined,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        AppLocalizations.of(context)!.agentChat_reasoning,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            thinking,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AgentWindowToolGroup extends StatelessWidget {
  const _AgentWindowToolGroup({required this.results});

  final List<Map<Object?, Object?>> results;

  @override
  Widget build(BuildContext context) {
    final hasError = results.any((result) => result['isError'] == true);
    final hasImages = results.any(
      (result) =>
          (result['images'] is List && (result['images'] as List).isNotEmpty) ||
          (result['files'] is List && (result['files'] as List).isNotEmpty),
    );
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: hasError || hasImages,
        minTileHeight: 38,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        leading: Icon(
          hasError ? Icons.error_outline : Icons.terminal_rounded,
          size: 17,
          color: hasError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(
          AppLocalizations.of(
            context,
          )!.agentChat_toolGroupCount(results.length),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        children: [
          for (final result in results) _AgentWindowToolResult(result: result),
        ],
      ),
    );
  }
}

class _AgentWindowToolResult extends StatelessWidget {
  const _AgentWindowToolResult({required this.result});

  final Map<Object?, Object?> result;

  @override
  Widget build(BuildContext context) {
    final images = result['images'] is List
        ? result['images'] as List
        : const [];
    final files = result['files'] is List ? result['files'] as List : const [];
    return Padding(
      padding: const EdgeInsets.only(left: 25, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                result['isError'] == true
                    ? Icons.close_rounded
                    : Icons.check_rounded,
                size: 14,
                color: result['isError'] == true
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result['toolName']?.toString() ?? '',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          if ((result['text'] as String? ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: SelectableText(
                result['text'] as String,
                maxLines: 8,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final image in images)
            if (image is Map) _AgentWindowImageCard(image: image),
          for (final path in files)
            if (path is String) _AgentWindowFileImageCard(path: path),
        ],
      ),
    );
  }
}

class _AgentWindowFileImageCard extends StatelessWidget {
  const _AgentWindowFileImageCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return _AgentWindowBrokenImage(label: path);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        button: true,
        label: AppLocalizations.of(context)!.agentChat_toolGenerateImage,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => _showAgentWindowImagePreview(
            context,
            imageBuilder: () => Image.file(file, fit: BoxFit.contain),
            path: path,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Image.file(
                file,
                alignment: Alignment.centerLeft,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _AgentWindowBrokenImage(label: path),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentWindowImageCard extends StatelessWidget {
  const _AgentWindowImageCard({required this.image});

  final Map image;

  @override
  Widget build(BuildContext context) {
    Widget Function() imageBuilder;
    if (image['base64'] case final String data) {
      try {
        final bytes = base64Decode(data);
        imageBuilder = () => Image.memory(bytes, fit: BoxFit.contain);
      } on FormatException {
        return const _AgentWindowBrokenImage();
      }
    } else if (image['url'] case final String url) {
      imageBuilder = () => Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _AgentWindowBrokenImage(),
      );
    } else {
      return const _AgentWindowBrokenImage();
    }
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.agentChat_toolGenerateImage,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            _showAgentWindowImagePreview(context, imageBuilder: imageBuilder),
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 420),
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: imageBuilder(),
        ),
      ),
    );
  }
}

class _AgentWindowBrokenImage extends StatelessWidget {
  const _AgentWindowBrokenImage({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_outlined, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label ??
                AppLocalizations.of(context)!.agentChat_resourceUnavailable,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Future<void> _showAgentWindowImagePreview(
  BuildContext context, {
  required Widget Function() imageBuilder,
  String? path,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => Dialog(
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 800),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(dialogContext).colorScheme.surfaceContainerLowest,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 8,
                child: Center(child: imageBuilder()),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                if (path != null)
                  IconButton.filledTonal(
                    tooltip: AppLocalizations.of(
                      dialogContext,
                    )!.localGallery_showInFolder,
                    onPressed: () => Process.start('explorer.exe', [
                      '/select,',
                      path,
                    ], mode: ProcessStartMode.detached),
                    icon: const Icon(Icons.folder_open_outlined),
                  ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: MaterialLocalizations.of(
                    dialogContext,
                  ).closeButtonTooltip,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

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
