import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../agent/agent_tool_presentation.dart';
import 'agent_chat_layout_contract.dart';
import 'agent_chat_shared_widgets.dart';

class AgentWindowMessageList extends StatefulWidget {
  const AgentWindowMessageList({
    required this.messages,
    required this.controller,
    required this.copyText,
    required this.retryLastMessage,
    required this.running,
    super.key,
  });

  final List messages;
  final ScrollController controller;
  final ValueChanged<String> copyText;
  final VoidCallback retryLastMessage;
  final bool running;

  @override
  State<AgentWindowMessageList> createState() => _AgentWindowMessageListState();
}

class _AgentWindowMessageListState extends State<AgentWindowMessageList> {
  bool _followLatest = true;
  String _lastSignature = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrollChanged);
    _lastSignature = widget.messages.isEmpty
        ? ''
        : '${widget.messages.length}:${widget.messages.last.hashCode}';
    if (widget.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToLatest(animate: false);
      });
    }
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToLatest(animate: false);
        });
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
    if (!mounted || !widget.controller.hasClients) return;
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
    final lastAssistantItemIndex = items.lastIndexWhere(
      (item) =>
          item is Map<Object?, Object?> &&
          item['role'] == 'assistant' &&
          (item['text']?.toString().trim().isNotEmpty ?? false),
    );
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => ListView.builder(
            controller: widget.controller,
            padding: EdgeInsets.fromLTRB(
              AgentChatLayoutContract.transcriptHorizontalPadding(
                constraints.maxWidth,
              ),
              16,
              AgentChatLayoutContract.transcriptHorizontalPadding(
                constraints.maxWidth,
              ),
              24,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AgentChatLayoutContract.transcriptMaxWidth(
                    constraints.maxWidth,
                  ),
                ),
                child: _buildItem(
                  context,
                  items[index],
                  isLastAssistant: index == lastAssistantItemIndex,
                ),
              ),
            ),
          ),
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

  Widget _buildItem(
    BuildContext context,
    Object item, {
    required bool isLastAssistant,
  }) {
    if (item is List<Map<Object?, Object?>>) {
      if (item.length == 1) {
        return _AgentWindowToolResult(
          result: item.single,
          copyText: widget.copyText,
        );
      }
      return _AgentWindowToolGroup(results: item, copyText: widget.copyText);
    }
    final message = item as Map<Object?, Object?>;
    final role = message['role'];
    final text = message['text'] as String? ?? '';
    if (role == 'user') {
      final images = message['images'] is List
          ? message['images'] as List
          : const [];
      return LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.centerRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                key: ValueKey('agent-window-user-bubble-${text.hashCode}'),
                constraints: BoxConstraints(
                  minWidth: text.isEmpty ? 0 : 44,
                  maxWidth: AgentChatLayoutContract.userBubbleMaxWidth(
                    constraints.maxWidth,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.58),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(4),
                  ),
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
    final thinking = message['thinking'] as String? ?? '';
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AgentChatLayoutContract.assistantMaxWidth(
              constraints.maxWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thinking.trim().isNotEmpty)
                  _AgentWindowReasoning(thinking: thinking),
                if (text.trim().isNotEmpty)
                  AgentChatMarkdownContent(
                    text: text,
                    touchOptimized: false,
                    imageBuilder: (uri, _, alt) =>
                        AgentChatMarkdownImage(uri: uri, alt: alt),
                  ),
                if (text.trim().isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _copyButton(context, text),
                      if (isLastAssistant && !widget.running)
                        IconButton(
                          key: const ValueKey(
                            'agent-window-retry-last-message',
                          ),
                          tooltip: AppLocalizations.of(context)!.common_retry,
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.retryLastMessage,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
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
  const _AgentWindowToolGroup({required this.results, required this.copyText});

  final List<Map<Object?, Object?>> results;
  final ValueChanged<String> copyText;

  @override
  Widget build(BuildContext context) {
    final hasError = results.any((result) => result['isError'] == true);
    String? failureSummary;
    for (final result in results) {
      if (result['isError'] == true) {
        failureSummary = AgentToolPresentation.summary(
          result['text']?.toString() ?? '',
          fallback: AppLocalizations.of(context)!.common_error,
        );
        break;
      }
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
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
        subtitle: failureSummary == null
            ? null
            : Text(
                '${AppLocalizations.of(context)!.common_error} · $failureSummary',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
        children: [
          for (final result in results)
            _AgentWindowToolResult(result: result, copyText: copyText),
        ],
      ),
    );
  }
}

class _AgentWindowToolResult extends StatelessWidget {
  const _AgentWindowToolResult({required this.result, required this.copyText});

  final Map<Object?, Object?> result;
  final ValueChanged<String> copyText;

  @override
  Widget build(BuildContext context) {
    final images = result['images'] is List
        ? result['images'] as List
        : const [];
    final files = result['files'] is List ? result['files'] as List : const [];
    final text = result['text'] as String? ?? '';
    final toolName = result['toolName']?.toString() ?? '';
    final failed = result['isError'] == true;
    final summary = AgentToolPresentation.summary(text, fallback: toolName);
    final detailSections = <String>[
      AgentToolPresentation.formattedDetails(text),
      if (result['details'] != null)
        AgentToolPresentation.formattedValue(result['details']),
    ].where((value) => value.isNotEmpty).toSet();
    final details = detailSections.join('\n\n');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('agent-window-tool-${result['toolCallId'] ?? toolName}'),
        initiallyExpanded: false,
        minTileHeight: 38,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(28, 0, 4, 8),
        leading: Icon(
          failed ? Icons.error_outline : Icons.check_circle_outline,
          size: 17,
          color: failed
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(
          toolName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        subtitle: Text(
          summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: failed
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          if (details.isNotEmpty)
            AgentToolDetailSurface(
              text: details,
              copyTooltip: AppLocalizations.of(context)!.common_copy,
              onCopy: () => copyText(details),
              maxHeight: 220,
              margin: EdgeInsets.zero,
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
