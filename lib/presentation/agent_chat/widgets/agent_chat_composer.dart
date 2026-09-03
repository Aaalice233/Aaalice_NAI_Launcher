import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../core/utils/token_count_format.dart';
import '../../../core/windowing/agent_chat_layout_contract.dart';
import '../../../core/windowing/agent_chat_shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../themes/core/input_surface_style.dart';
import '../models/agent_chat_slash_command.dart';
import '../providers/agent_chat_state.dart';
import 'agent_chat_header.dart';
import 'agent_chat_model_picker.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_view_data.dart';
import 'agent_chat_resource_widgets.dart';
import 'agent_chat_slash_menu.dart';

class AgentChatComposer extends StatefulWidget {
  const AgentChatComposer({
    super.key,
    required this.viewData,
    required this.commands,
    required this.controller,
  });

  final AgentChatPanelViewData viewData;
  final AgentChatPanelCommands commands;
  final AgentChatPanelController controller;

  @override
  State<AgentChatComposer> createState() => _AgentChatComposerState();
}

class _AgentChatComposerState extends State<AgentChatComposer> {
  static const _controlsHorizontalPadding = 16.0;
  static const _controlGap = 4.0;
  static const _minimumModelControlWidth = 104.0;

  bool _editorExpanded = false;
  int _slashHighlight = 0;
  String? _observedSlashQuery;
  String? _dismissedSlashQuery;

  AgentChatPanelViewData get viewData => widget.viewData;
  AgentChatPanelCommands get commands => widget.commands;
  AgentChatPanelController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.inputController.addListener(_handleSlashQueryChanged);
  }

  @override
  void didUpdateWidget(AgentChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.inputController.removeListener(
        _handleSlashQueryChanged,
      );
      controller.inputController.addListener(_handleSlashQueryChanged);
    }
  }

  @override
  void dispose() {
    controller.inputController.removeListener(_handleSlashQueryChanged);
    super.dispose();
  }

  /// 只负责请求重建，派生状态一律在 build 里同步。
  ///
  /// 纯文本改动会经由草稿状态让面板重建，但只移动光标不会——而光标进出片段
  /// 决定菜单开合，所以这里补一次。面板 build 期间的 syncComposerText 也会
  /// 触发本回调，那时本帧重建已在进行，再标脏就是构建期 setState。
  void _handleSlashQueryChanged() {
    if (!mounted) return;
    final query = parseSlashQuery(controller.inputController.value)?.query;
    if (query == _observedSlashQuery) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return;
    }
    setState(() {});
  }

  void _dismissSlashMenu() {
    setState(() => _dismissedSlashQuery = _observedSlashQuery ?? '');
  }

  void _toggleEditorExpanded() {
    setState(() => _editorExpanded = !_editorExpanded);
    controller.inputFocus.requestFocus();
  }

  void _moveSlashHighlight(int delta, int count) {
    setState(() => _slashHighlight = (_slashHighlight + delta + count) % count);
  }

  /// 技能插入到输入框继续编辑；会话命令没有后续正文，选中即执行。
  ///
  /// 用构建菜单时的 [queryEnd] 而不是重新读实时 selection：鼠标点击会让输入框
  /// 先失焦，此刻 selection 已经失效，再解析必然拿不到片段。
  void _acceptSlashCommand(AgentChatSlashCommand command, int queryEnd) {
    final action = command.sessionAction;
    if (action == null) {
      controller.applySlashCommand(command.name, queryEnd);
      return;
    }
    controller.removeLeadingSlashToken(queryEnd);
    commands.moreAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final slashCommands = buildSlashCommands(
      skills: viewData.state.skills,
      l10n: l10n,
      sessionActionsEnabled: viewData.sessionActionsEnabled,
    );
    controller.inputController.slashCommandNames = {
      for (final command in slashCommands) command.name.toLowerCase(),
    };
    final slashQuery = viewData.state.initialized
        ? parseSlashQuery(controller.inputController.value)
        : null;
    // 片段变化才重排：光标在片段内平移不该重置选中项，也不该撤销 Esc 之外的
    // 关闭状态。
    if (slashQuery?.query != _observedSlashQuery) {
      _observedSlashQuery = slashQuery?.query;
      _dismissedSlashQuery = null;
      _slashHighlight = 0;
    }
    final slashMatches =
        slashQuery == null || slashQuery.query == _dismissedSlashQuery
        ? const <AgentChatSlashCommand>[]
        : filterSlashCommands(slashCommands, slashQuery.query);
    final slashHighlight = slashMatches.isEmpty
        ? 0
        : _slashHighlight.clamp(0, slashMatches.length - 1);

    return Padding(
      key: const ValueKey('agent-chat-input-container'),
      padding: AgentChatLayoutContract.composerOuterPadding(viewData.width),
      child: SingleChildScrollView(
        primary: false,
        child: Container(
          key: const ValueKey('agent-chat-composer-surface'),
          decoration: BoxDecoration(
            color: inputSurfaceFillColor(theme.colorScheme, prominent: true),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!viewData.compactWidth &&
                  viewData.state.queuedMessages.isNotEmpty)
                _queuedMessages(theme, l10n),
              if (controller.isEditingUserMessage)
                _messageEditHeader(theme, l10n),
              if (slashMatches.isNotEmpty)
                AgentChatSlashMenu(
                  commands: slashMatches,
                  highlightIndex: slashHighlight,
                  onSelected: (command) =>
                      _acceptSlashCommand(command, slashQuery!.end),
                  onHighlightChanged: (index) =>
                      setState(() => _slashHighlight = index),
                ),
              if (viewData.state.pendingResources.isNotEmpty ||
                  controller.pendingImages.isNotEmpty)
                _attachmentCards(),
              _editor(
                context,
                theme,
                l10n,
                slashMatches,
                slashHighlight,
                slashQuery?.end ?? 0,
              ),
              if (viewData.compactWidth &&
                  viewData.state.queuedMessages.isNotEmpty)
                _queuedMessages(theme, l10n),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                child: _composerControls(theme, l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageEditHeader(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      key: const ValueKey('agent-chat-message-edit-header'),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 0),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.common_edit,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('agent-chat-cancel-message-edit'),
            onPressed: commands.cancelUserMessageEdit,
            child: Text(l10n.common_cancel),
          ),
        ],
      ),
    );
  }

  Widget _editor(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<AgentChatSlashCommand> slashMatches,
    int slashHighlight,
    int slashQueryEnd,
  ) {
    final target = context.interactionPolicy.minimumControlExtent;
    final composerPadding = AgentChatLayoutContract.composerOuterPadding(
      viewData.width,
    );
    final controlsWidth = math.max(
      0.0,
      viewData.width - composerPadding.horizontal - _controlsHorizontalPadding,
    );
    final showInlineContext = !_contextFitsInControls(
      availableWidth: controlsWidth,
      controlExtent: target,
    );
    final trailingControls = showInlineContext ? 2 : 1;
    final availableHeight = viewData.height
        .clamp(0, AgentChatComposerLayout.availableViewportHeight(context))
        .toDouble();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final editor = TextField(
      key: const ValueKey('agent-chat-input'),
      controller: controller.inputController,
      focusNode: controller.inputFocus,
      enabled: viewData.state.initialized,
      expands: _editorExpanded,
      minLines: _editorExpanded
          ? null
          : AgentChatComposerLayout.collapsedEditorMinLines(
              availableHeight: availableHeight,
              textScale: textScale,
              touchOptimized:
                  context.interactionPolicy.shouldExposeTouchAlternatives,
            ),
      maxLines: _editorExpanded
          ? null
          : AgentChatComposerLayout.collapsedEditorMaxLines(
              availableHeight: availableHeight,
              textScale: textScale,
              touchOptimized:
                  context.interactionPolicy.shouldExposeTouchAlternatives,
            ),
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        isDense: true,
        hintText: viewData.state.skills.isEmpty
            ? l10n.agentChat_inputHint
            : l10n.agentChat_inputHintWithSlash,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
        ),
        contentPadding: EdgeInsets.fromLTRB(
          viewData.compactWidth ? 14 : 13,
          14,
          target * trailingControls + 6,
          10,
        ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
      ),
    );

    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        final composing =
            controller.inputController.value.composing.isValid &&
            !controller.inputController.value.composing.isCollapsed;
        // 菜单开着时先于停止运行、队列编辑和发送处理，否则同一个键有两个归属。
        if (slashMatches.isNotEmpty && !composing) {
          if (key == LogicalKeyboardKey.escape) {
            _dismissSlashMenu();
            return KeyEventResult.handled;
          }
          if (!HardwareKeyboard.instance.isAltPressed &&
              (key == LogicalKeyboardKey.arrowDown ||
                  key == LogicalKeyboardKey.arrowUp)) {
            _moveSlashHighlight(
              key == LogicalKeyboardKey.arrowDown ? 1 : -1,
              slashMatches.length,
            );
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.tab ||
              ((key == LogicalKeyboardKey.enter ||
                      key == LogicalKeyboardKey.numpadEnter) &&
                  !HardwareKeyboard.instance.isShiftPressed &&
                  !HardwareKeyboard.instance.isControlPressed &&
                  !HardwareKeyboard.instance.isMetaPressed)) {
            _acceptSlashCommand(slashMatches[slashHighlight], slashQueryEnd);
            return KeyEventResult.handled;
          }
        }
        if (key == LogicalKeyboardKey.escape && viewData.running) {
          commands.stop();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp &&
            HardwareKeyboard.instance.isAltPressed &&
            viewData.state.queuedMessages.isNotEmpty) {
          commands.editQueuedMessage(viewData.state.queuedMessages.last);
          return KeyEventResult.handled;
        }
        if (key != LogicalKeyboardKey.enter &&
            key != LogicalKeyboardKey.numpadEnter) {
          return KeyEventResult.ignored;
        }
        if (controller.inputController.value.composing.isValid &&
            !controller.inputController.value.composing.isCollapsed) {
          return KeyEventResult.ignored;
        }
        if (HardwareKeyboard.instance.isShiftPressed ||
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed) {
          controller.insertNewline();
          return KeyEventResult.handled;
        }
        if (viewData.canSend &&
            (controller.inputController.text.trim().isNotEmpty ||
                controller.pendingImages.isNotEmpty)) {
          commands.send();
        }
        return KeyEventResult.handled;
      },
      child: Stack(
        children: [
          SizedBox(
            key: const ValueKey('agent-chat-composer-editor'),
            height: _editorExpanded
                ? AgentChatComposerLayout.expandedEditorHeight(
                    availableHeight: availableHeight,
                    touchOptimized:
                        context.interactionPolicy.shouldExposeTouchAlternatives,
                  )
                : null,
            child: editor,
          ),
          Positioned(
            top: 6,
            right: 6,
            child: AgentChatComposerExpandButton(
              key: const ValueKey('agent-chat-composer-expand'),
              expanded: _editorExpanded,
              touchOptimized:
                  context.interactionPolicy.shouldExposeTouchAlternatives,
              expandLabel:
                  '${l10n.common_expand} · ${l10n.agentChat_inputHint}',
              collapseLabel:
                  '${l10n.common_collapse} · ${l10n.agentChat_inputHint}',
              onPressed: _toggleEditorExpanded,
            ),
          ),
          if (showInlineContext)
            Positioned(
              top: 6,
              right: target + 8,
              width: target,
              child: _contextIndicator(theme, l10n),
            ),
        ],
      ),
    );
  }

  Widget _composerControls(ThemeData theme, AppLocalizations l10n) {
    return LayoutBuilder(
      key: const ValueKey('agent-chat-composer-controls'),
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final showAccessLabels = constraints.maxWidth >= 760 && textScale < 2;
        final controlExtent = context.interactionPolicy.minimumControlExtent;
        final showContext = _contextFitsInControls(
          availableWidth: constraints.maxWidth,
          controlExtent: controlExtent,
        );
        final showContextLabel = constraints.maxWidth >= 900 && textScale < 2;
        final showModelName = constraints.maxWidth >= 340 && textScale < 2;
        final hasDraft =
            controller.inputController.text.trim().isNotEmpty ||
            controller.pendingImages.isNotEmpty;
        final sendButton = _SendButton(
          running: viewData.running,
          enabled: viewData.running || (viewData.canSend && hasDraft),
          disabledReason: hasDraft
              ? l10n.agentChat_sendUnavailableHint
              : l10n.agentChat_sendEmptyHint,
          onSend: commands.send,
          onStop: commands.stop,
        );
        final permissionWidth = showAccessLabels
            ? 116.0
            : context.interactionPolicy.minimumControlExtent;
        final webAccessWidth = showAccessLabels
            ? 124.0
            : context.interactionPolicy.minimumControlExtent;
        final contextWidth = showContextLabel ? 116.0 : controlExtent;
        final fixedControlsWidth =
            controlExtent +
            permissionWidth +
            webAccessWidth +
            controlExtent +
            (showContext ? contextWidth : 0) +
            _controlGap * (showContext ? 5 : 4);
        final modelControlWidth = math.min(
          showModelName ? 340.0 : 104.0,
          math.max(0.0, constraints.maxWidth - fixedControlsWidth),
        );

        final controls = Row(
          key: const ValueKey('agent-chat-composer-status-row'),
          children: [
            _attachmentSourceButton(theme, l10n),
            const SizedBox(width: _controlGap),
            SizedBox(
              width: permissionWidth,
              child: _permissionModeButton(
                theme,
                l10n,
                showLabel: showAccessLabels,
              ),
            ),
            const SizedBox(width: _controlGap),
            SizedBox(
              width: webAccessWidth,
              child: _webAccessToggle(theme, l10n, showLabel: showAccessLabels),
            ),
            const SizedBox(width: _controlGap),
            const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: modelControlWidth),
              child: _configurationSelector(showModelName: showModelName),
            ),
            if (showContext) ...[
              const SizedBox(width: _controlGap),
              SizedBox(
                width: contextWidth,
                child: _contextIndicator(
                  theme,
                  l10n,
                  showLabel: showContextLabel,
                ),
              ),
            ],
            const SizedBox(width: _controlGap),
            sendButton,
          ],
        );

        return SizedBox(
          key: const ValueKey('agent-chat-session-controls'),
          width: double.infinity,
          child: KeyedSubtree(
            key: const ValueKey('agent-chat-message-actions'),
            child: controls,
          ),
        );
      },
    );
  }

  bool _contextFitsInControls({
    required double availableWidth,
    required double controlExtent,
  }) {
    const compactControlCount = 5;
    const gapCount = 5;
    final compactControlsWidth =
        controlExtent * compactControlCount + _controlGap * gapCount;
    return availableWidth >= compactControlsWidth + _minimumModelControlWidth;
  }

  Widget _contextIndicator(
    ThemeData theme,
    AppLocalizations l10n, {
    bool showLabel = false,
  }) {
    final usage = viewData.state.contextUsage;
    final tokens = usage.tokens;
    final window = usage.contextWindow;
    final available = usage.available;
    final loading =
        viewData.state.compacting ||
        viewData.state.sessionContentLoading ||
        (!viewData.state.routeReady && viewData.state.routeError.isEmpty);
    final percent = usage.percent?.clamp(0, 999).round();
    final label = loading
        ? viewData.state.compacting
              ? l10n.agentChat_compacting
              : l10n.common_loading
        : available
        ? '$percent% · ${usage.estimated ? '~' : ''}${formatTokenCount(tokens!)} / ${formatTokenCount(window!)}'
        : l10n.agentChat_contextUnavailable;
    final onPressed = available && !loading && viewData.sessionActionsEnabled
        ? () => commands.moreAction(AgentChatMoreAction.compact)
        : null;
    final target = context.interactionPolicy.minimumControlExtent;
    final meterColor = available && percent != null && percent >= 100
        ? theme.colorScheme.error
        : available && percent != null && percent >= 80
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return Semantics(
      button: onPressed != null,
      label: label,
      value: percent == null ? null : '$percent%',
      child: Tooltip(
        message: label,
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: onPressed == null ? 0.42 : 0.62,
          ),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              key: const ValueKey('agent-chat-context-target'),
              constraints: BoxConstraints(minHeight: target),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: showLabel ? 10 : 0),
                child: Row(
                  mainAxisSize: showLabel ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      key: const ValueKey('agent-chat-context-ring'),
                      dimension: 30,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: loading
                                ? CircularProgressIndicator(
                                    key: const ValueKey(
                                      'agent-chat-context-loading',
                                    ),
                                    strokeWidth: 3,
                                    value:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? 0.75
                                        : null,
                                    color: meterColor,
                                    backgroundColor: theme
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.3),
                                  )
                                : CircularProgressIndicator(
                                    strokeWidth: 3,
                                    value: available
                                        ? (tokens! / window!).clamp(0.0, 1.0)
                                        : 0,
                                    color: meterColor,
                                    backgroundColor: theme
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.3),
                                  ),
                          ),
                          ExcludeSemantics(
                            child: MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.2,
                              child: Text(
                                loading
                                    ? '…'
                                    : available
                                    ? '$percent%'
                                    : '—',
                                key: loading
                                    ? const ValueKey(
                                        'agent-chat-context-loading-label',
                                      )
                                    : available
                                    ? const ValueKey(
                                        'agent-chat-context-token-label',
                                      )
                                    : const ValueKey(
                                        'agent-chat-context-unavailable',
                                      ),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: available
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontSize: 9,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showLabel) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loading
                              ? (viewData.state.compacting
                                    ? l10n.agentChat_compacting
                                    : l10n.common_loading)
                              : '${l10n.agentChat_contextUsageLabel} · ${available ? '$percent%' : '—'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: available
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _queuedMessages(ThemeData theme, AppLocalizations l10n) {
    final queued = viewData.state.queuedMessages;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.48,
          ),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: KeyedSubtree(
            key: const ValueKey('agent-chat-queue'),
            child: ExpansionTile(
              key: const PageStorageKey('agent-chat-queue-expansion'),
              minTileHeight: context.interactionPolicy.minimumControlExtent,
              tilePadding: const EdgeInsets.symmetric(horizontal: 10),
              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 6, 6),
              leading: Icon(
                Icons.queue_outlined,
                size: 17,
                color: theme.colorScheme.tertiary,
              ),
              title: Text(
                '${l10n.agentChat_queued} · ${queued.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.expand_more_rounded, size: 18),
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: viewData.compactHeight
                        ? 64
                        : viewData.compactWidth
                        ? 96
                        : 160,
                  ),
                  child: ListView.builder(
                    key: const PageStorageKey('agent-chat-queue-list'),
                    primary: false,
                    shrinkWrap: true,
                    itemCount: queued.length,
                    itemBuilder: (context, index) {
                      final item = queued[index];
                      return Row(
                        children: [
                          if (viewData.compactWidth)
                            Tooltip(
                              message:
                                  item.kind == AgentQueuedMessageKind.steering
                                  ? l10n.agentChat_queueSteering
                                  : l10n.agentChat_queueFollowUp,
                              child: Icon(
                                item.kind == AgentQueuedMessageKind.steering
                                    ? Icons.turn_right_rounded
                                    : Icons.playlist_add_rounded,
                                size: 16,
                                color: theme.colorScheme.tertiary,
                              ),
                            )
                          else
                            Text(
                              item.kind == AgentQueuedMessageKind.steering
                                  ? l10n.agentChat_queueSteering
                                  : l10n.agentChat_queueFollowUp,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.text.trim().isEmpty
                                  ? l10n.agentChat_queued
                                  : item.text.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.common_edit,
                            onPressed: () => commands.editQueuedMessage(item),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            constraints: BoxConstraints.tightFor(
                              width: context
                                  .interactionPolicy
                                  .minimumControlExtent,
                              height: context
                                  .interactionPolicy
                                  .minimumControlExtent,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.common_delete,
                            onPressed: () async {
                              await commands.removeQueuedMessage(item);
                            },
                            icon: const Icon(Icons.close, size: 16),
                            constraints: BoxConstraints.tightFor(
                              width: context
                                  .interactionPolicy
                                  .minimumControlExtent,
                              height: context
                                  .interactionPolicy
                                  .minimumControlExtent,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('agent-chat-follow-up'),
                      onPressed: commands.sendFollowUp,
                      icon: const Icon(Icons.playlist_add_rounded, size: 17),
                      label: Text(l10n.agentChat_queueFollowUp),
                    ),
                    TextButton(
                      onPressed: () async {
                        await commands.clearQueuedMessages();
                      },
                      child: Text(l10n.common_clear),
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

  Widget _attachmentCards() {
    final imageCount = controller.pendingImages.length;
    return SizedBox(
      key: const ValueKey('agent-chat-attachment-strip'),
      height: viewData.compactWidth ? 66 : 58,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        scrollDirection: Axis.horizontal,
        itemCount: imageCount + viewData.state.pendingResources.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index < imageCount) {
            return AgentChatPendingImageCard(
              image: controller.pendingImages[index],
              compactLayout: viewData.compactWidth,
              onRemove: () => controller.removePendingImage(index),
            );
          }
          final resourceIndex = index - imageCount;
          final reference = viewData.state.pendingResources[resourceIndex];
          final unavailable = viewData.state.unavailableResourceKeys.contains(
            AgentChatResourceReferenceCodec.encodeJson(reference),
          );
          return AgentChatPendingResourceCard(
            reference: reference,
            loadPreview: () => commands.resolveResourcePreview(reference),
            unavailable: unavailable,
            compactLayout: viewData.compactWidth,
            onRemove: () => commands.removePendingResource(resourceIndex),
          );
        },
      ),
    );
  }

  Widget _attachmentSourceButton(ThemeData theme, AppLocalizations l10n) {
    final child = Container(
      width: context.interactionPolicy.minimumControlExtent,
      height: context.interactionPolicy.minimumControlExtent,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        Icons.add,
        size: 18,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
      ),
    );
    if (context.interactionPolicy.prefersTouchPresentation) {
      return Semantics(
        key: const ValueKey('agent-chat-more-actions'),
        button: true,
        label: l10n.agentChat_addAttachment,
        child: InkWell(
          onTap: viewData.state.initialized
              ? () => _showMobileAttachmentSources(l10n)
              : null,
          borderRadius: BorderRadius.circular(9),
          child: child,
        ),
      );
    }
    return PopupMenuButton<AgentChatAttachmentAction>(
      key: const ValueKey('agent-chat-more-actions'),
      tooltip: l10n.agentChat_addAttachment,
      padding: EdgeInsets.zero,
      enabled: viewData.state.initialized,
      onSelected: _handleAttachmentAction,
      itemBuilder: (_) => [
        _attachmentItem(
          AgentChatAttachmentAction.images,
          Icons.photo_library_outlined,
          l10n.agentChat_photoLibrary,
        ),
        _attachmentItem(
          AgentChatAttachmentAction.currentCanvas,
          Icons.crop_free_rounded,
          l10n.agentChat_currentCanvas,
          enabled: viewData.currentCanvasReference != null,
        ),
        _attachmentItem(
          AgentChatAttachmentAction.referenceGallery,
          Icons.collections_outlined,
          l10n.agentChat_referenceGallery,
        ),
        _attachmentItem(
          AgentChatAttachmentAction.resourceLibrary,
          Icons.bookmarks_outlined,
          l10n.agentChat_resourceLibrary,
        ),
      ],
      child: child,
    );
  }

  PopupMenuItem<AgentChatAttachmentAction> _attachmentItem(
    AgentChatAttachmentAction action,
    IconData icon,
    String label, {
    bool enabled = true,
  }) => PopupMenuItem(
    value: action,
    enabled: enabled,
    height: 44,
    child: Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 10),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );

  Future<void> _showMobileAttachmentSources(AppLocalizations l10n) async {
    final context = controller.inputFocus.context;
    if (context == null) return;
    controller.inputFocus.unfocus();
    final action = await showModalBottomSheet<AgentChatAttachmentAction>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _mobileAttachmentTile(
              sheetContext,
              AgentChatAttachmentAction.images,
              Icons.photo_library_outlined,
              l10n.agentChat_photoLibrary,
            ),
            _mobileAttachmentTile(
              sheetContext,
              AgentChatAttachmentAction.currentCanvas,
              Icons.crop_free_rounded,
              l10n.agentChat_currentCanvas,
              enabled: viewData.currentCanvasReference != null,
            ),
            _mobileAttachmentTile(
              sheetContext,
              AgentChatAttachmentAction.referenceGallery,
              Icons.collections_outlined,
              l10n.agentChat_referenceGallery,
            ),
            _mobileAttachmentTile(
              sheetContext,
              AgentChatAttachmentAction.resourceLibrary,
              Icons.bookmarks_outlined,
              l10n.agentChat_resourceLibrary,
            ),
          ],
        ),
      ),
    );
    if (action != null) await _handleAttachmentAction(action);
  }

  Widget _mobileAttachmentTile(
    BuildContext context,
    AgentChatAttachmentAction action,
    IconData icon,
    String label, {
    bool enabled = true,
  }) => ListTile(
    minTileHeight: 48,
    enabled: enabled,
    leading: Icon(icon),
    title: Text(label),
    onTap: enabled ? () => Navigator.pop(context, action) : null,
  );

  Future<void> _handleAttachmentAction(AgentChatAttachmentAction action) {
    return switch (action) {
      AgentChatAttachmentAction.images => commands.pickImages(),
      AgentChatAttachmentAction.currentCanvas => commands.attachCurrentCanvas(),
      AgentChatAttachmentAction.referenceGallery =>
        commands.openReferenceGallery(),
      AgentChatAttachmentAction.resourceLibrary =>
        commands.openResourceLibrary(),
    };
  }

  Widget _permissionModeButton(
    ThemeData theme,
    AppLocalizations l10n, {
    bool showLabel = false,
  }) {
    final mode = viewData.agentSettings.settings.chat.permissionMode;
    final modeLabel = agentPermissionModeLabel(l10n, mode);
    final icon = switch (mode) {
      AgentPermissionMode.safe => Icons.shield_outlined,
      AgentPermissionMode.askBeforeSensitiveActions => Icons.gpp_maybe_outlined,
      AgentPermissionMode.fullAccess => Icons.lock_open_outlined,
    };
    return PopupMenuButton<AgentPermissionMode>(
      key: const ValueKey('agent-chat-permission-mode'),
      enabled: _agentSettingsInteractive,
      tooltip: '${l10n.agentChat_permissionMode}: $modeLabel',
      onSelected: commands.selectPermissionMode,
      itemBuilder: (context) => [
        for (final value in AgentPermissionMode.values)
          PopupMenuItem(
            value: value,
            height: 52,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: value == mode
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agentPermissionModeLabel(l10n, value),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        agentPermissionModeDescription(l10n, value),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: showLabel
            ? double.infinity
            : context.interactionPolicy.minimumControlExtent,
        height: context.interactionPolicy.minimumControlExtent,
        padding: EdgeInsets.symmetric(horizontal: showLabel ? 10 : 0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: _agentSettingsInteractive ? 0.5 : 0.28,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(
                alpha: _agentSettingsInteractive ? 0.7 : 0.25,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  modeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _agentSettingsInteractive
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _webAccessToggle(
    ThemeData theme,
    AppLocalizations l10n, {
    bool showLabel = false,
  }) {
    final state = viewData.webAccess;
    final enabled = viewData.agentSettings.settings.chat.webAccessEnabled;
    final interactive = state.initialized && _agentSettingsInteractive;
    final tooltip = enabled
        ? l10n.agentChat_disableWebAccess
        : l10n.agentChat_enableWebAccess;
    final iconColor = enabled
        ? theme.colorScheme.primary.withValues(alpha: 0.82)
        : theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Semantics(
      button: true,
      toggled: enabled,
      label: tooltip,
      child: Container(
        width: showLabel
            ? double.infinity
            : context.interactionPolicy.minimumControlExtent,
        height: context.interactionPolicy.minimumControlExtent,
        decoration: BoxDecoration(
          color: enabled
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.42)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('agent-chat-web-access-toggle'),
              tooltip: tooltip,
              onPressed: interactive
                  ? () => commands.setWebAccessEnabled(!enabled)
                  : null,
              isSelected: enabled,
              icon: const Icon(Icons.public_off_outlined),
              selectedIcon: const Icon(Icons.public),
              iconSize: 18,
              alignment: Alignment.center,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: context.interactionPolicy.minimumControlExtent,
                height: context.interactionPolicy.minimumControlExtent,
              ),
              style: ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                splashFactory: NoSplash.splashFactory,
                shape: const WidgetStatePropertyAll(CircleBorder()),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return theme.colorScheme.onSurface.withValues(alpha: 0.25);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.72);
                  }
                  return iconColor;
                }),
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused)) {
                    return iconColor.withValues(alpha: 0.12);
                  }
                  if (states.contains(WidgetState.pressed)) {
                    return iconColor.withValues(alpha: 0.08);
                  }
                  return Colors.transparent;
                }),
              ),
            ),
            if (showLabel)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    l10n.agentChat_webAccessLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: interactive
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _configurationSelector({required bool showModelName}) =>
      AgentChatConfigurationControl(
        config: viewData.config,
        agentSettings: viewData.agentSettings,
        routeLabel: viewData.state.routeLabel,
        routeError: viewData.state.routeError,
        thinkingLevel: viewData.state.thinkingLevel,
        availableThinkingLevels: viewData.state.availableThinkingLevels,
        enabled: viewData.sessionActionsEnabled && _agentSettingsInteractive,
        onModelSelected: commands.selectModel,
        onThinkingSelected: commands.selectThinkingLevel,
        restoreFocusNode: controller.inputFocus,
        showModelName: showModelName,
      );

  bool get _agentSettingsInteractive =>
      viewData.agentSettings.initialized &&
      viewData.agentSettings.error.isEmpty &&
      !viewData.controlsLocked;
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.running,
    required this.enabled,
    required this.disabledReason,
    required this.onSend,
    required this.onStop,
  });

  final bool running;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final touchOptimized =
        context.interactionPolicy.shouldExposeTouchAlternatives;
    final controlExtent = context.interactionPolicy.minimumControlExtent;
    final backgroundColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final foregroundColor = enabled
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface.withValues(alpha: 0.34);
    final label = running ? l10n.agentChat_stop : l10n.agentChat_send;
    final tooltip = enabled ? label : disabledReason;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: enabled ? null : disabledReason,
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: SizedBox(
          key: const ValueKey('agent-chat-send'),
          width: controlExtent,
          height: controlExtent,
          child: Center(
            child: Material(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(touchOptimized ? 14 : 10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? (running ? onStop : onSend) : null,
                child: SizedBox(
                  width: touchOptimized ? 40 : 36,
                  height: touchOptimized ? 40 : 36,
                  child: Icon(
                    running ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                    size: touchOptimized ? 20 : 18,
                    color: foregroundColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
