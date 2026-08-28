import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../l10n/app_localizations.dart';
import '../utils/app_logger.dart';
import '../agent/resources/agent_chat_resource_drag_format.dart';
import '../agent/resources/agent_chat_resource_reference_codec.dart';
import 'agent_window_protocol.dart';
import 'agent_window_shell_widgets.dart';

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

  AgentWindowShellBridge get bridge => widget.bridge;

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    _composerSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    _composerFocus.requestFocus();
    if (_localError.isNotEmpty) setState(() => _localError = '');
    try {
      final result = await bridge.sendCommand('sendText', {'text': text});
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
    final messages = payload['messages'] is List
        ? payload['messages'] as List
        : const [];
    final sessions = payload['sessions'] is List
        ? payload['sessions'] as List
        : const [];
    final resources = payload['resources'] is List
        ? payload['resources'] as List
        : const [];
    final hasUnavailableResources = resources.any(
      (resource) => resource is Map && resource['unavailable'] == true,
    );
    final activeSessionId = payload['activeSessionId'] as String? ?? '';
    final running = payload['running'] == true;
    final initialized = payload['initialized'] == true;
    final routeReady = payload['routeReady'] == true;
    final compacting = payload['compacting'] == true;
    final routeLabel = payload['routeLabel'] as String? ?? '';
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
        appBar: _buildAppBar(context, l10n, running),
        body: Column(
          children: [
            if (sessions.isNotEmpty)
              _buildSessionPicker(l10n, sessions, activeSessionId, running),
            Expanded(
              child: AgentWindowMessageList(
                messages: messages,
                controller: _scrollController,
              ),
            ),
            ..._buildStatusPanels(
              context,
              payload,
              compacting,
              approval,
              resources,
            ),
            _buildComposer(
              context,
              l10n,
              payload,
              routeLabel,
              initialized,
              routeReady,
              running,
              hasUnavailableResources,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
    bool running,
  ) => AppBar(
    title: Text(l10n.agentChat_heroTitle),
    actions: [
      IconButton(
        tooltip: l10n.agentChat_newChat,
        onPressed: running ? null : () => bridge.sendCommand('newSession'),
        icon: const Icon(Icons.add_comment_outlined),
      ),
      PopupMenuButton<String>(
        tooltip: l10n.agentChat_moreActions,
        enabled: !running,
        onSelected: (value) => _sessionAction(context, value),
        itemBuilder: (_) => [
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
      ),
      IconButton(
        tooltip: l10n.agentChat_alwaysOnTop,
        onPressed: () => bridge.setAlwaysOnTop(!bridge.alwaysOnTop),
        icon: Icon(
          bridge.alwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
        ),
      ),
      IconButton(
        tooltip: l10n.agentChat_dockWindow,
        onPressed: bridge.dock,
        icon: const Icon(Icons.call_received),
      ),
    ],
  );

  Widget _buildSessionPicker(
    AppLocalizations l10n,
    List sessions,
    String activeSessionId,
    bool running,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: DropdownButtonFormField<String>(
      initialValue:
          sessions.any((item) => item is Map && item['id'] == activeSessionId)
          ? activeSessionId
          : null,
      isExpanded: true,
      items: [
        for (final item in sessions)
          if (item is Map)
            DropdownMenuItem(
              value: item['id'] as String?,
              child: Text(
                item['name'] as String? ?? l10n.agentChat_untitled,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ],
      onChanged: running
          ? null
          : (value) {
              if (value != null) {
                bridge.sendCommand('switchSession', {'id': value});
              }
            },
      decoration: const InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.forum_outlined),
      ),
    ),
  );

  List<Widget> _buildStatusPanels(
    BuildContext context,
    Map<String, Object?> payload,
    bool compacting,
    Map<Object?, Object?>? approval,
    List resources,
  ) => [
    if (payload['activities'] case final List activities)
      for (final activity in activities)
        if (activity is Map) AgentWindowToolActivityTile(activity: activity),
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
          title: Text(error, maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            onPressed: () => bridge.sendCommand('dismissError'),
            icon: const Icon(Icons.close),
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
        resolve: (value) =>
            bridge.sendCommand('resolveApproval', {'value': value}),
      ),
    if (resources.isNotEmpty)
      AgentWindowResourceList(
        resources: resources,
        remove: (encoded) =>
            bridge.sendCommand('removeResource', {'reference': encoded}),
      ),
  ];

  Widget _buildComposer(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, Object?> payload,
    String routeLabel,
    bool initialized,
    bool routeReady,
    bool running,
    bool hasUnavailableResources,
  ) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _composer,
            focusNode: _composerFocus,
            enabled: initialized,
            minLines: 2,
            maxLines: 7,
            onChanged: _composerChanged,
            onSubmitted: (_) {
              if (!hasUnavailableResources) unawaited(_send());
            },
            decoration: InputDecoration(
              hintText: l10n.agentChat_inputHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              AgentWindowPermissionModeButton(
                sendCommand: (name, payload) =>
                    bridge.sendCommand(name, payload),
                payload: payload,
              ),
              const SizedBox(width: 4),
              FilterChip(
                selected: payload['webAccessEnabled'] == true,
                avatar: const Icon(Icons.public, size: 16),
                label: Text(l10n.agentChat_webAccess),
                onSelected: running
                    ? null
                    : (value) =>
                          bridge.sendCommand('setWebAccess', {'value': value}),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  routeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              IconButton.filled(
                tooltip: running
                    ? l10n.agentChat_stop
                    : hasUnavailableResources
                    ? l10n.agentChat_resourceUnavailable
                    : l10n.agentChat_send,
                onPressed: initialized && routeReady
                    ? running
                          ? () => bridge.sendCommand('stop')
                          : hasUnavailableResources
                          ? null
                          : _send
                    : null,
                icon: Icon(running ? Icons.stop : Icons.send),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _sessionAction(BuildContext context, String value) async {
    final payload = bridge.snapshot.payload;
    final sessionId = payload['activeSessionId'] as String? ?? '';
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
      controller.dispose();
      if (name != null && name.isNotEmpty) {
        await bridge.sendCommand('renameSession', {
          'id': sessionId,
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
        await bridge.sendCommand('deleteSession', {'id': sessionId});
      }
    }
  }
}

final class _LocalizedWindowCommandException implements Exception {
  const _LocalizedWindowCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
