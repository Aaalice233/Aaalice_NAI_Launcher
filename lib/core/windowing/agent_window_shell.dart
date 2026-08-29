import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../l10n/app_localizations.dart';
import '../utils/app_logger.dart';
import '../agent/resources/agent_chat_resource_drag_format.dart';
import '../agent/resources/agent_chat_resource_reference_codec.dart';
import 'agent_chat_session_picker.dart';
import 'agent_chat_layout_contract.dart';
import 'agent_chat_shared_widgets.dart';
import 'agent_window_protocol.dart';
import 'agent_window_shell_widgets.dart';
import 'agent_window_transcript_widgets.dart';

abstract interface class AgentWindowShellBridge {
  AgentWindowSnapshot get snapshot;
  bool get alwaysOnTop;
  Future<Object?> sendCommand(
    String name, [
    Map<String, Object?> payload = const {},
  ]);
  Future<void> dock();
  Future<void> setAlwaysOnTop(bool value);
}

Widget buildAgentWindowBridgeShell(
  BuildContext context,
  AgentWindowShellBridge bridge,
) => _AgentWindowBridgeShell(bridge: bridge);

class _AgentWindowBridgeShell extends StatefulWidget {
  const _AgentWindowBridgeShell({required this.bridge});

  final AgentWindowShellBridge bridge;

  @override
  State<_AgentWindowBridgeShell> createState() =>
      _AgentWindowBridgeShellState();
}

class _AgentWindowBridgeShellState extends State<_AgentWindowBridgeShell> {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scrollController = ScrollController();
  Timer? _composerSyncTimer;
  String _localError = '';
  bool _composerExpanded = false;

  AgentWindowShellBridge get bridge => widget.bridge;

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    _composerSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _send({bool followUp = false}) async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    _composerFocus.requestFocus();
    if (_localError.isNotEmpty) setState(() => _localError = '');
    try {
      final result = await bridge.sendCommand('sendText', {
        'text': text,
        'followUp': followUp,
      });
      if (result is Map && result['error'] == 'resource_unavailable') {
        if (!mounted) return;
        throw _LocalizedWindowCommandException(
          AppLocalizations.of(context)!.agentChat_resourceUnavailable,
        );
      }
    } catch (error) {
      if (_composer.text.isEmpty) {
        _composer.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      if (mounted) setState(() => _localError = error.toString());
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.common_copied),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _composerChanged(String value) {
    _composerSyncTimer?.cancel();
    _composerSyncTimer = Timer(const Duration(milliseconds: 120), () async {
      try {
        await bridge.sendCommand('updateComposer', {'text': value});
      } on Object catch (error) {
        AppLogger.w(
          'Detached Agent composer sync stopped: $error',
          'AgentWindow',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final payload = bridge.snapshot.payload;
    final messages = _resolveMessageImageAssets(
      payload['messages'] is List ? payload['messages'] as List : const [],
      payload['imageAssets'] is Map
          ? Map<Object?, Object?>.from(payload['imageAssets'] as Map)
          : const {},
    );
    final sessions = payload['sessions'] is List
        ? payload['sessions'] as List
        : const [];
    final resources = payload['resources'] is List
        ? payload['resources'] as List
        : const [];
    final queue = payload['queue'] is List
        ? payload['queue'] as List
        : const [];
    final hasUnavailableResources = resources.any(
      (resource) => resource is Map && resource['unavailable'] == true,
    );
    final activeSessionId = payload['activeSessionId'] as String? ?? '';
    final running = payload['running'] == true;
    final sessionTransitioning = payload['sessionTransitioning'] == true;
    final sessionContentLoading = payload['sessionContentLoading'] == true;
    final controlsLocked = running || sessionTransitioning;
    final initialized = payload['initialized'] == true;
    final routeReady = payload['routeReady'] == true;
    final compacting = payload['compacting'] == true;
    final remoteComposer = payload['composerText'] as String? ?? '';
    if (_composer.text != remoteComposer && !_composerFocus.hasFocus) {
      _composer.value = TextEditingValue(
        text: remoteComposer,
        selection: TextSelection.collapsed(offset: remoteComposer.length),
      );
    }
    final approval = payload['approval'] is Map
        ? Map<Object?, Object?>.from(payload['approval'] as Map)
        : null;
    return DropRegion(
      formats: [agentChatResourceDragFormat],
      onDropOver: (event) =>
          event.session.items.any(canReadAgentResourceDropItem)
          ? DropOperation.copy
          : DropOperation.none,
      onPerformDrop: (event) async {
        for (final item in event.session.items) {
          final reference = await readAgentResourceDropItem(item);
          if (reference != null) {
            await bridge.sendCommand('addResource', {
              'reference': AgentChatResourceReferenceCodec.encodeJson(
                reference,
              ),
            });
          }
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(
          context,
          l10n,
          controlsLocked,
          sessions,
          activeSessionId,
        ),
        body: Column(
          children: [
            Expanded(
              child: AgentWindowMessageList(
                messages: messages,
                controller: _scrollController,
                copyText: _copyText,
                retryLastMessage: () => bridge.sendCommand('retryLastMessage'),
                running: running,
                timeline: payload['timeline'] is List
                    ? payload['timeline'] as List
                    : const [],
                activities: payload['activities'] is List
                    ? payload['activities'] as List
                    : const [],
                history: payload['history'] is Map
                    ? Map<Object?, Object?>.from(payload['history'] as Map)
                    : const {},
                approvalPending: approval != null,
                loadEarlierHistory: () async {
                  await bridge.sendCommand('loadEarlierHistory');
                },
                loadLatestHistory: () async {
                  await bridge.sendCommand('loadLatestHistory');
                },
              ),
            ),
            ..._buildStatusPanels(
              context,
              payload,
              compacting,
              sessionContentLoading,
              approval,
              queue,
            ),
            _buildComposer(
              context,
              l10n,
              payload,
              initialized,
              routeReady,
              running,
              sessionTransitioning,
              hasUnavailableResources,
              resources,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    bool controlsLocked,
    List sessions,
    String activeSessionId,
  ) => PreferredSize(
    preferredSize: const Size.fromHeight(64),
    child: LayoutBuilder(
      builder: (headerContext, constraints) => _buildHeaderContent(
        headerContext,
        l10n,
        controlsLocked,
        sessions,
        activeSessionId,
        constraints.maxWidth,
      ),
    ),
  );

  Widget _buildHeaderContent(
    BuildContext context,
    AppLocalizations l10n,
    bool controlsLocked,
    List sessions,
    String activeSessionId,
    double width,
  ) {
    final compact = width < 760;
    final showProduct = width >= 980;
    final showActionLabels = width >= 1320;
    final sessionPicker = AgentChatSessionPicker(
      key: const ValueKey('agent-window-session-picker'),
      sessions: [
        for (final item in sessions)
          if (item is Map && item['id'] is String)
            AgentChatSessionOption(
              id: item['id'] as String,
              name: item['name'] as String? ?? '',
              updatedAt: DateTime.tryParse(item['updatedAt'] as String? ?? ''),
            ),
      ],
      activeSessionId: activeSessionId,
      enabled: !controlsLocked,
      compactTitle: true,
      touchOptimized: compact,
      onSelect: (id) async {
        await bridge.sendCommand('switchSession', {'id': id});
      },
      onNew: () async {
        await bridge.sendCommand('newSession');
      },
      onRename: (id) => _sessionAction(context, 'rename', sessionId: id),
      onDelete: (id) => _sessionAction(context, 'delete', sessionId: id),
    );
    final newSession = AgentWindowHeaderAction(
      tooltip: l10n.agentChat_newChat,
      label: l10n.agentChat_newChat,
      icon: Icons.add_comment_outlined,
      showLabel: showActionLabels,
      onPressed: controlsLocked ? null : () => bridge.sendCommand('newSession'),
    );
    final dock = AgentWindowHeaderAction(
      tooltip: l10n.agentChat_dockWindow,
      label: l10n.agentChat_dockWindow,
      icon: Icons.call_received,
      showLabel: showActionLabels,
      onPressed: bridge.dock,
    );
    final actionItems = <Widget>[
      if (!compact) newSession,
      if (width >= 980)
        AgentWindowHeaderAction(
          tooltip: l10n.agentChat_alwaysOnTop,
          label: l10n.agentChat_alwaysOnTop,
          icon: bridge.alwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
          showLabel: showActionLabels,
          selected: bridge.alwaysOnTop,
          onPressed: _toggleAlwaysOnTop,
        ),
      dock,
      _buildMoreMenu(
        context,
        l10n,
        enabled: !controlsLocked,
        includeNewSession: compact,
        includeWindow: width < 980,
        showLabel: showActionLabels,
      ),
    ];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
            child: Row(
              children: [
                if (showProduct) ...[
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.agentChat_heroTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 28,
                    child: VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(flex: 2, child: sessionPicker),
                const SizedBox(width: 4),
                SizedBox(
                  width: compact
                      ? 96
                      : showActionLabels
                      ? 480
                      : 192,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actionItems,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuButton<String> _buildMoreMenu(
    BuildContext context,
    AppLocalizations l10n, {
    required bool enabled,
    bool includeNewSession = false,
    bool includeWindow = false,
    bool showLabel = false,
  }) => PopupMenuButton<String>(
    key: const ValueKey('agent-window-more-actions'),
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    padding: EdgeInsets.zero,
    tooltip: l10n.agentChat_moreActions,
    onSelected: (value) => _headerAction(context, value),
    itemBuilder: (_) => [
      if (enabled) ...[
        if (includeNewSession)
          PopupMenuItem(
            value: 'new',
            child: ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: Text(l10n.agentChat_newChat),
            ),
          ),
        PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.common_rename),
          ),
        ),
        PopupMenuItem(
          value: 'compact',
          child: ListTile(
            leading: const Icon(Icons.compress_outlined),
            title: Text(l10n.agentChat_compact),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.common_delete),
          ),
        ),
      ],
      if (includeWindow) ...[
        PopupMenuItem(
          value: 'pin',
          child: ListTile(
            leading: Icon(
              bridge.alwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            title: Text(l10n.agentChat_alwaysOnTop),
          ),
        ),
        PopupMenuItem(
          value: 'dock',
          child: ListTile(
            leading: const Icon(Icons.call_received),
            title: Text(l10n.agentChat_dockWindow),
          ),
        ),
      ],
    ],
    child: AgentWindowHeaderAction(
      tooltip: l10n.agentChat_moreActions,
      label: l10n.agentChat_moreActions,
      icon: Icons.more_horiz_rounded,
      showLabel: showLabel,
      onPressed: null,
    ),
  );

  Future<void> _headerAction(BuildContext context, String value) async {
    if (value == 'new') {
      await bridge.sendCommand('newSession');
      return;
    }
    if (value == 'pin') {
      await _toggleAlwaysOnTop();
      return;
    }
    if (value == 'dock') {
      await bridge.dock();
      return;
    }
    await _sessionAction(context, value);
  }

  Future<void> _toggleAlwaysOnTop() async {
    await bridge.setAlwaysOnTop(!bridge.alwaysOnTop);
    if (mounted) setState(() {});
  }

  List<Widget> _buildStatusPanels(
    BuildContext context,
    Map<String, Object?> payload,
    bool compacting,
    bool sessionContentLoading,
    Map<Object?, Object?>? approval,
    List queue,
  ) => [
    if (sessionContentLoading)
      const LinearProgressIndicator(
        key: ValueKey('agent-window-session-loading'),
        minHeight: 2,
      ),
    if (!(payload['timeline'] is List &&
        (payload['timeline'] as List).isNotEmpty))
      if (payload['activities'] case final List activities)
        for (final activity in activities)
          if (activity is Map && activity['status'] == 'running')
            AgentWindowToolActivityTile(
              activity: activity,
              copyText: _copyText,
            ),
    if (compacting)
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.agentChat_compacting),
          ],
        ),
      ),
    if (payload['error'] case final String error when error.isNotEmpty)
      Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.error_outline),
          title: Text(
            _presentWindowError(context, error),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (payload['running'] != true)
                TextButton(
                  onPressed: () => bridge.sendCommand('retryLastMessage'),
                  child: Text(AppLocalizations.of(context)!.common_retry),
                ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => bridge.sendCommand('dismissError'),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    if (_localError.isNotEmpty)
      Material(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.error_outline),
          title: Text(
            _localError,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            onPressed: () => setState(() => _localError = ''),
            icon: const Icon(Icons.close),
          ),
        ),
      ),
    if (approval != null)
      AgentWindowApprovalBar(
        approval: approval,
        resolve: (value) => bridge.sendCommand('resolveApproval', {
          'toolCallId': approval['toolCallId'],
          'value': value,
        }),
      ),
    if (queue.isNotEmpty)
      AgentWindowQueuePanel(
        queue: queue,
        edit: _editQueuedMessage,
        remove: (item) => bridge.sendCommand('removeQueuedMessage', {
          'kind': item['kind'],
          'id': item['id'],
        }),
        clear: () => bridge.sendCommand('clearQueuedMessages'),
      ),
  ];

  Future<void> _editQueuedMessage(Map item) async {
    final result = await bridge.sendCommand('editQueuedMessage', {
      'kind': item['kind'],
      'id': item['id'],
    });
    if (!mounted || result is! Map || result['ok'] != true) return;
    final text = result['text'] as String? ?? '';
    _composer.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _composerFocus.requestFocus();
  }

  Widget _buildComposer(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, Object?> payload,
    bool initialized,
    bool routeReady,
    bool running,
    bool sessionTransitioning,
    bool hasUnavailableResources,
    List resources,
  ) {
    final controlsLocked = running || sessionTransitioning;
    final permission = AgentWindowPermissionModeButton(
      sendCommand: (name, payload) => bridge.sendCommand(name, payload),
      payload: payload,
    );
    final webAccess = FilterChip(
      key: const ValueKey('agent-window-web-access'),
      selected: payload['webAccessEnabled'] == true,
      avatar: const Icon(Icons.public, size: 16),
      label: Text(l10n.agentChat_webAccess),
      onSelected: controlsLocked
          ? null
          : (value) => bridge.sendCommand('setWebAccess', {'value': value}),
    );
    final model = AgentWindowModelButton(
      payload: payload,
      sendCommand: (name, payload) => bridge.sendCommand(name, payload),
    );
    final thinking = AgentWindowThinkingButton(
      payload: payload,
      sendCommand: (name, payload) => bridge.sendCommand(name, payload),
    );
    final actions = <Widget>[
      if (running)
        PopupMenuButton<bool>(
          tooltip: l10n.agentChat_queueFollowUp,
          onSelected: (_) => _send(followUp: true),
          itemBuilder: (_) => [
            PopupMenuItem<bool>(
              value: true,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text(l10n.agentChat_queueFollowUp),
              ),
            ),
          ],
          icon: const Icon(Icons.playlist_add_rounded),
        ),
      if (running)
        IconButton(
          tooltip: l10n.agentChat_stop,
          onPressed: () => bridge.sendCommand('stop'),
          color: Theme.of(context).colorScheme.error,
          icon: const Icon(Icons.stop_rounded),
        ),
      IconButton.filled(
        key: const ValueKey('agent-window-send'),
        tooltip: hasUnavailableResources
            ? l10n.agentChat_resourceUnavailable
            : running
            ? l10n.agentChat_queued
            : l10n.agentChat_send,
        onPressed:
            initialized &&
                routeReady &&
                !sessionTransitioning &&
                !hasUnavailableResources
            ? _send
            : null,
        icon: Icon(running ? Icons.queue_rounded : Icons.send_rounded),
      ),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: AgentChatLayoutContract.composerOuterPadding(
          MediaQuery.sizeOf(context).width,
        ),
        child: Container(
          key: const ValueKey('agent-window-composer-surface'),
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Focus(
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.escape &&
                      running) {
                    bridge.sendCommand('stop');
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey != LogicalKeyboardKey.enter &&
                      event.logicalKey != LogicalKeyboardKey.numpadEnter) {
                    return KeyEventResult.ignored;
                  }
                  if (_composer.value.composing.isValid &&
                      !_composer.value.composing.isCollapsed) {
                    return KeyEventResult.ignored;
                  }
                  if (HardwareKeyboard.instance.isShiftPressed ||
                      HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed) {
                    final value = _composer.value;
                    final selection = value.selection;
                    final start = selection.isValid
                        ? selection.start
                        : value.text.length;
                    final end = selection.isValid
                        ? selection.end
                        : value.text.length;
                    _composer.value = value.copyWith(
                      text: value.text.replaceRange(start, end, '\n'),
                      selection: TextSelection.collapsed(offset: start + 1),
                      composing: TextRange.empty,
                    );
                    return KeyEventResult.handled;
                  }
                  if (initialized &&
                      routeReady &&
                      !sessionTransitioning &&
                      !hasUnavailableResources) {
                    unawaited(_send());
                  }
                  return KeyEventResult.handled;
                },
                child: Stack(
                  children: [
                    SizedBox(
                      key: const ValueKey('agent-window-composer-editor'),
                      height: _composerExpanded
                          ? AgentChatComposerLayout.expandedEditorHeight(
                              availableHeight:
                                  AgentChatComposerLayout.availableViewportHeight(
                                    context,
                                  ),
                              touchOptimized:
                                  MediaQuery.sizeOf(context).width < 560,
                            )
                          : null,
                      child: TextField(
                        key: const ValueKey('agent-window-composer-input'),
                        controller: _composer,
                        focusNode: _composerFocus,
                        enabled: initialized,
                        expands: _composerExpanded,
                        minLines: _composerExpanded
                            ? null
                            : AgentChatComposerLayout.defaultMinLines,
                        maxLines: _composerExpanded
                            ? null
                            : AgentChatComposerLayout.defaultDesktopMaxLines,
                        onChanged: _composerChanged,
                        textInputAction: TextInputAction.newline,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: l10n.agentChat_inputHint,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.fromLTRB(
                            8,
                            12,
                            48,
                            8,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: AgentChatComposerExpandButton(
                        key: const ValueKey('agent-window-composer-expand'),
                        expanded: _composerExpanded,
                        touchOptimized: MediaQuery.sizeOf(context).width < 560,
                        expandLabel:
                            '${l10n.common_expand} · ${l10n.agentChat_inputHint}',
                        collapseLabel:
                            '${l10n.common_collapse} · ${l10n.agentChat_inputHint}',
                        onPressed: () {
                          setState(
                            () => _composerExpanded = !_composerExpanded,
                          );
                          _composerFocus.requestFocus();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (resources.isNotEmpty)
                AgentWindowResourceList(
                  resources: resources,
                  remove: (encoded) => bridge.sendCommand('removeResource', {
                    'reference': encoded,
                  }),
                ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final contextUsage = payload['contextUsage'];
                  final contextTokens = _contextTokens(contextUsage);
                  final contextWindow = _contextWindow(contextUsage);
                  final contextEstimated =
                      contextUsage is Map && contextUsage['estimated'] == true;
                  final contextAvailable =
                      contextTokens != null && contextWindow != null;
                  final contextIndicator = AgentChatContextIndicator(
                    usedTokens: contextTokens,
                    contextWindow: contextWindow,
                    usageLabel: contextAvailable
                        ? '${contextEstimated ? '~' : ''}${_compactTokenCount(contextTokens)} / '
                              '${_compactTokenCount(contextWindow)}'
                        : l10n.agentChat_contextUnavailable,
                    unavailableLabel: l10n.agentChat_contextUnavailable,
                    compactingLabel: l10n.agentChat_compacting,
                    compacting: payload['compacting'] == true,
                    touchOptimized: constraints.maxWidth < 560,
                    onPressed: contextAvailable && !running
                        ? () => bridge.sendCommand('compact')
                        : null,
                  );
                  final phaseLabel = _workPhaseLabel(
                    l10n,
                    payload['workPhase'],
                  );
                  final status = Expanded(
                    child: Text(
                      phaseLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(14) > 18;
                  if (largeText ||
                      AgentChatLayoutContract.stackComposerControls(
                        constraints.maxWidth,
                        running: running,
                      )) {
                    return Column(
                      children: [
                        Row(
                          key: const ValueKey('agent-window-composer-actions'),
                          children: [status, ...actions],
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          height: 48,
                          child: SingleChildScrollView(
                            key: const ValueKey(
                              'agent-window-composer-settings',
                            ),
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                model,
                                const SizedBox(width: 4),
                                permission,
                                const SizedBox(width: 4),
                                webAccess,
                                const SizedBox(width: 4),
                                thinking,
                                const SizedBox(width: 4),
                                contextIndicator,
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Flexible(child: model),
                      const SizedBox(width: 4),
                      permission,
                      const SizedBox(width: 4),
                      webAccess,
                      const SizedBox(width: 4),
                      thinking,
                      const SizedBox(width: 10),
                      status,
                      contextIndicator,
                      const SizedBox(width: 4),
                      ...actions,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _workPhaseLabel(AppLocalizations l10n, Object? value) {
    final label = switch (value) {
      'preparing' => l10n.agentChat_phasePreparing,
      'thinking' => l10n.agentChat_thinking,
      'responding' => l10n.agentChat_phaseResponding,
      'usingTools' => l10n.agentChat_toolRunning,
      'awaitingApproval' => l10n.agentChat_phaseAwaitingApproval,
      'compacting' => l10n.agentChat_compacting,
      'stopping' => l10n.agentChat_phaseStopping,
      _ => '',
    };
    return label;
  }

  int? _contextTokens(Object? value) {
    if (value is! Map) return null;
    final tokens = value['tokens'];
    return tokens is num && tokens > 0 ? tokens.toInt() : null;
  }

  int? _contextWindow(Object? value) {
    if (value is! Map) return null;
    final window = value['contextWindow'];
    return window is num && window > 0 ? window.toInt() : null;
  }

  String _compactTokenCount(int value) {
    if (value < 1000) return '$value';
    if (value < 1000000) {
      final compact = value / 1000;
      return '${compact >= 100 ? compact.round() : compact.toStringAsFixed(1)}k';
    }
    final compact = value / 1000000;
    return '${compact >= 100 ? compact.round() : compact.toStringAsFixed(1)}m';
  }

  Future<void> _sessionAction(
    BuildContext context,
    String value, {
    String? sessionId,
  }) async {
    final payload = bridge.snapshot.payload;
    final targetSessionId =
        sessionId ?? payload['activeSessionId'] as String? ?? '';
    if (value == 'compact') {
      await bridge.sendCommand('compact');
      return;
    }
    if (value == 'rename') {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.common_rename),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      controller.dispose();
      if (name != null && name.isNotEmpty) {
        await bridge.sendCommand('renameSession', {
          'id': targetSessionId,
          'name': name,
        });
      }
      return;
    }
    if (value == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.common_delete),
          content: Text(
            AppLocalizations.of(context)!.common_deleteItemConfirm(
              AppLocalizations.of(context)!.agentChat_untitled,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context)!.common_delete),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await bridge.sendCommand('deleteSession', {'id': targetSessionId});
      }
    }
  }
}

List<Object?> _resolveMessageImageAssets(
  List messages,
  Map<Object?, Object?> assets,
) => [
  for (final message in messages)
    if (message is Map)
      {
        ...message,
        if (message['images'] is List)
          'images': [
            for (final image in message['images'] as List)
              if (image is Map && image['assetId'] is String)
                {
                  ...image,
                  if (assets[image['assetId']] is Map)
                    ...Map<Object?, Object?>.from(
                      assets[image['assetId']] as Map,
                    ),
                }
              else
                image,
          ],
      }
    else
      message,
];

String _presentWindowError(BuildContext context, String error) {
  final protocolError = RegExp(
    r'api_error|requestoptions|validatestatus|dioexception|stacktrace',
    caseSensitive: false,
  ).hasMatch(error);
  if (!protocolError) return error;
  final status = RegExp(
    r'(?:http|status(?:\s+code)?)\D{0,12}([45]\d\d)',
    caseSensitive: false,
  ).firstMatch(error)?.group(1);
  final label = AppLocalizations.of(context)!.common_error;
  return status == null ? label : '$label · HTTP $status';
}

final class _LocalizedWindowCommandException implements Exception {
  const _LocalizedWindowCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
