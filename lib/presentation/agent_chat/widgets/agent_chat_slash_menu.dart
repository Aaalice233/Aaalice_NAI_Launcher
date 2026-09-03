import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../l10n/app_localizations.dart';
import '../models/agent_chat_slash_command.dart';
import 'agent_chat_panel_view_data.dart';

/// 输入框开头敲 `/` 后列出的技能与会话动作。
///
/// 贴在编辑区上方而不是浮在消息流之上：面板宽度受限、移动端软键盘会顶起布局，
/// 内联可以复用排队消息与附件卡片同一条纵向节奏，也不会遮住刚发出的消息。
class AgentChatSlashMenu extends StatefulWidget {
  const AgentChatSlashMenu({
    super.key,
    required this.commands,
    required this.highlightIndex,
    required this.onSelected,
    required this.onHighlightChanged,
  });

  final List<AgentChatSlashCommand> commands;
  final int highlightIndex;
  final ValueChanged<AgentChatSlashCommand> onSelected;
  final ValueChanged<int> onHighlightChanged;

  @override
  State<AgentChatSlashMenu> createState() => _AgentChatSlashMenuState();
}

class _AgentChatSlashMenuState extends State<AgentChatSlashMenu> {
  static const double _headerExtent = 28;
  static const double _dividerExtent = 1;

  final ScrollController _scrollController = ScrollController();

  double get _itemExtent => context.interactionPolicy.touchAvailable ? 58 : 48;
  double get _maxHeight => context.interactionPolicy.touchAvailable ? 208 : 244;

  @override
  void didUpdateWidget(AgentChatSlashMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightIndex != widget.highlightIndex ||
        oldWidget.commands.length != widget.commands.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealHighlight());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 键盘上下移动时把选中项拉进可视区；行高固定，偏移可直接算出。
  void _revealHighlight() {
    if (!_scrollController.hasClients) return;
    final rows = _rows();
    final rowIndex = rows.indexWhere(
      (row) => row.commandIndex == widget.highlightIndex,
    );
    if (rowIndex < 0) return;
    var top = 0.0;
    for (var i = 0; i < rowIndex; i++) {
      top += _extentOf(rows[i]);
    }
    final bottom = top + _extentOf(rows[rowIndex]);
    final position = _scrollController.position;
    final viewportTop = position.pixels;
    final viewportBottom = viewportTop + position.viewportDimension;
    final double target;
    if (top < viewportTop) {
      target = top;
    } else if (bottom > viewportBottom) {
      target = bottom - position.viewportDimension;
    } else {
      return;
    }
    _scrollController.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  double _extentOf(_SlashRow row) => switch (row.kind) {
    _SlashRowKind.header => _headerExtent,
    _SlashRowKind.divider => _dividerExtent,
    _SlashRowKind.item => _itemExtent,
  };

  List<_SlashRow> _rows() {
    final rows = <_SlashRow>[];
    AgentChatSlashCommandKind? previousKind;
    for (var index = 0; index < widget.commands.length; index++) {
      final command = widget.commands[index];
      if (command.kind != previousKind) {
        if (previousKind != null) {
          rows.add(const _SlashRow(kind: _SlashRowKind.divider));
        }
        rows.add(
          _SlashRow(kind: _SlashRowKind.header, groupKind: command.kind),
        );
        previousKind = command.kind;
      }
      rows.add(_SlashRow(kind: _SlashRowKind.item, commandIndex: index));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final rows = _rows();
    final contentHeight = rows.fold<double>(
      0,
      (total, row) => total + _extentOf(row),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      // 归属输入框：点击菜单不触发 TextField 的 tap-outside 失焦，安卓软键盘
      // 也不会在选技能时收起。
      child: TextFieldTapRegion(
        child: Semantics(
          container: true,
          label: l10n.agentChat_slashMenu,
          child: Material(
            key: const ValueKey('agent-chat-slash-menu'),
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: contentHeight.clamp(0, _maxHeight),
              ),
              // 条目不进入焦点树：Tab 仍归输入框，用于确认当前选中项。
              child: ExcludeFocus(
                child: ListView.builder(
                  controller: _scrollController,
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  itemBuilder: (context, index) =>
                      _buildRow(theme, l10n, rows[index]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(ThemeData theme, AppLocalizations l10n, _SlashRow row) {
    switch (row.kind) {
      case _SlashRowKind.divider:
        return Divider(
          height: _dividerExtent,
          thickness: _dividerExtent,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        );
      case _SlashRowKind.header:
        return SizedBox(
          height: _headerExtent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                row.groupKind == AgentChatSlashCommandKind.skill
                    ? l10n.agentChat_slashSkills
                    : l10n.agentChat_slashSession,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      case _SlashRowKind.item:
        return _item(theme, row.commandIndex);
    }
  }

  Widget _item(ThemeData theme, int index) {
    final command = widget.commands[index];
    final highlighted = index == widget.highlightIndex;
    final destructive = command.sessionAction == AgentChatMoreAction.delete;
    final accent = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final nameColor = highlighted ? accent : theme.colorScheme.onSurface;

    return SizedBox(
      height: _itemExtent,
      child: Semantics(
        button: true,
        selected: highlighted,
        label: '/${command.name} · ${command.description}',
        child: MouseRegion(
          onEnter: (_) => widget.onHighlightChanged(index),
          child: Material(
            color: highlighted
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            child: InkWell(
              onTap: () => widget.onSelected(command),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(command),
                      size: 17,
                      color: destructive
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '/${command.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: nameColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            command.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AgentChatSlashCommand command) =>
      switch (command.sessionAction) {
        AgentChatMoreAction.newSession => Icons.add_comment_outlined,
        AgentChatMoreAction.compact => Icons.compress_rounded,
        AgentChatMoreAction.rename => Icons.edit_outlined,
        AgentChatMoreAction.delete => Icons.delete_outline_rounded,
        null => Icons.auto_awesome_outlined,
      };
}

enum _SlashRowKind { header, item, divider }

@immutable
class _SlashRow {
  const _SlashRow({required this.kind, this.groupKind, this.commandIndex = -1});

  final _SlashRowKind kind;
  final AgentChatSlashCommandKind? groupKind;
  final int commandIndex;
}
