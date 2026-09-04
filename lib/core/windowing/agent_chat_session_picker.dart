import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../presentation/themes/theme_extension.dart';

class AgentChatSessionOption {
  const AgentChatSessionOption({
    required this.id,
    required this.name,
    this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime? updatedAt;
}

class AgentChatSessionPicker extends StatefulWidget {
  const AgentChatSessionPicker({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.enabled,
    required this.onSelect,
    required this.onNew,
    required this.onRename,
    required this.onDelete,
    this.touchOptimized = false,
    this.compactTitle = false,
  });

  final List<AgentChatSessionOption> sessions;
  final String activeSessionId;
  final bool enabled;
  final bool touchOptimized;
  final bool compactTitle;
  final Future<void> Function(String id) onSelect;
  final Future<void> Function() onNew;
  final Future<void> Function(String id) onRename;
  final Future<void> Function(String id) onDelete;

  @override
  State<AgentChatSessionPicker> createState() => _AgentChatSessionPickerState();
}

class _AgentChatSessionPickerState extends State<AgentChatSessionPicker> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final active = widget.sessions
        .where((item) => item.id == widget.activeSessionId)
        .firstOrNull;
    final title = active == null || active.name.isEmpty
        ? l10n.agentChat_untitled
        : active.name;
    final radius = BorderRadius.circular(theme.appTheme.controlRadius);
    final trigger = SizedBox(
      height: 48,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: title,
        child: Material(
          color: widget.compactTitle
              ? Colors.transparent
              : theme.colorScheme.surfaceContainer,
          borderRadius: radius,
          child: InkWell(
            onTap: widget.enabled ? () => _open(context) : null,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compactTitle ? 8 : 12,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showLeading =
                      !widget.compactTitle && constraints.maxWidth >= 64;
                  final showChevron = constraints.maxWidth >= 28;
                  return Row(
                    children: [
                      if (showLeading) ...[
                        const Icon(Icons.forum_outlined, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (showChevron) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.touchOptimized) return trigger;

    final viewport = MediaQuery.sizeOf(context);
    final menuWidth = math.min(340.0, math.max(240.0, viewport.width - 24));
    final desiredMenuHeight = 112.0 + math.min(widget.sessions.length, 4) * 56;
    final availableMenuHeight = math.max(220.0, viewport.height - 96);
    final menuHeight = math.min(
      desiredMenuHeight.clamp(220.0, 360.0),
      availableMenuHeight,
    );
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          theme.colorScheme.surfaceContainerHigh,
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.appTheme.menuRadius),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          key: const ValueKey('agent-chat-session-menu'),
          width: menuWidth,
          height: menuHeight,
          child: _pickerBody(onClose: _menuController.close, dense: true),
        ),
      ],
      builder: (_, _, _) => trigger,
    );
  }

  Future<void> _open(BuildContext context) async {
    if (widget.touchOptimized) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        builder: (sheetContext) => FractionallySizedBox(
          heightFactor: 0.78,
          child: _pickerBody(
            onClose: () => Navigator.of(sheetContext).pop(),
            showClose: true,
            dense: false,
          ),
        ),
      );
      return;
    }
    _menuController.open();
  }

  Widget _pickerBody({
    required VoidCallback onClose,
    required bool dense,
    bool showClose = false,
  }) => _AgentChatSessionPickerBody(
    sessions: widget.sessions,
    activeSessionId: widget.activeSessionId,
    onSelect: widget.onSelect,
    onNew: widget.onNew,
    onRename: widget.onRename,
    onDelete: widget.onDelete,
    onClose: onClose,
    showClose: showClose,
    dense: dense,
  );
}

class _AgentChatSessionPickerBody extends StatefulWidget {
  const _AgentChatSessionPickerBody({
    required this.sessions,
    required this.activeSessionId,
    required this.onSelect,
    required this.onNew,
    required this.onRename,
    required this.onDelete,
    required this.onClose,
    required this.showClose,
    required this.dense,
  });

  final List<AgentChatSessionOption> sessions;
  final String activeSessionId;
  final Future<void> Function(String id) onSelect;
  final Future<void> Function() onNew;
  final Future<void> Function(String id) onRename;
  final Future<void> Function(String id) onDelete;
  final VoidCallback onClose;
  final bool showClose;
  final bool dense;

  @override
  State<_AgentChatSessionPickerBody> createState() =>
      _AgentChatSessionPickerBodyState();
}

class _AgentChatSessionPickerBodyState
    extends State<_AgentChatSessionPickerBody> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.sessions
        : widget.sessions
              .where((item) => item.name.toLowerCase().contains(query))
              .toList(growable: false);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: widget.dense
                ? const EdgeInsets.fromLTRB(12, 8, 8, 4)
                : EdgeInsets.fromLTRB(12, widget.showClose ? 0 : 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('agent-chat-session-search'),
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      isDense: widget.dense,
                      contentPadding: widget.dense
                          ? const EdgeInsets.symmetric(vertical: 10)
                          : null,
                      hintText: l10n.agentChat_searchSessions,
                      prefixIcon: const Icon(Icons.search_rounded),
                      prefixIconConstraints: widget.dense
                          ? const BoxConstraints(minWidth: 40, minHeight: 40)
                          : null,
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                if (widget.showClose) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      l10n.agentChat_untitled,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    primary: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final session = filtered[index];
                      final active = session.id == widget.activeSessionId;
                      return Material(
                        key: ValueKey(
                          'agent-chat-session-material-${session.id}',
                        ),
                        type: MaterialType.transparency,
                        child: ListTile(
                          dense: widget.dense,
                          visualDensity: widget.dense
                              ? const VisualDensity(vertical: -2)
                              : null,
                          minVerticalPadding: widget.dense ? 4 : null,
                          selected: active,
                          selectedTileColor: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              theme.appTheme.controlRadius,
                            ),
                          ),
                          leading: Icon(
                            active
                                ? Icons.chat_bubble_rounded
                                : Icons.chat_bubble_outline_rounded,
                            size: 19,
                          ),
                          title: Text(
                            session.name.isEmpty
                                ? l10n.agentChat_untitled
                                : session.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: session.updatedAt == null
                              ? null
                              : Text(_formatTime(session.updatedAt!)),
                          trailing: PopupMenuButton<String>(
                            tooltip: l10n.agentChat_moreActions,
                            onSelected: (value) async {
                              widget.onClose();
                              if (value == 'rename') {
                                await widget.onRename(session.id);
                              } else {
                                await widget.onDelete(session.id);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.edit_outlined),
                                  title: Text(l10n.common_rename),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: theme.colorScheme.error,
                                  ),
                                  title: Text(l10n.common_delete),
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            widget.onClose();
                            if (!active) await widget.onSelect(session.id);
                          },
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.all(widget.dense ? 12 : 16),
            child: FilledButton.icon(
              onPressed: () async {
                widget.onClose();
                await widget.onNew();
              },
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(widget.dense ? 40 : 48),
                tapTargetSize: widget.dense
                    ? MaterialTapTargetSize.shrinkWrap
                    : MaterialTapTargetSize.padded,
              ),
              icon: const Icon(Icons.add_comment_outlined),
              label: Text(l10n.agentChat_newChat),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
