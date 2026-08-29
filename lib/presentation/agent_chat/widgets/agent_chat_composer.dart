import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/windowing/agent_chat_layout_contract.dart';
import '../../../core/windowing/agent_chat_shared_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../providers/agent_chat_state.dart';
import 'agent_chat_header.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_view_data.dart';
import 'agent_chat_resource_widgets.dart';

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
  bool _editorExpanded = false;

  AgentChatPanelViewData get viewData => widget.viewData;
  AgentChatPanelCommands get commands => widget.commands;
  AgentChatPanelController get controller => widget.controller;

  void _toggleEditorExpanded() {
    setState(() => _editorExpanded = !_editorExpanded);
    controller.inputFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      key: const ValueKey('agent-chat-input-container'),
      padding: AgentChatLayoutContract.composerOuterPadding(viewData.width),
      child: Container(
        key: const ValueKey('agent-chat-composer-surface'),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(viewData.mobile ? 18 : 14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!viewData.mobile && viewData.state.queuedMessages.isNotEmpty)
              _queuedMessages(theme, l10n),
            _editor(context, theme, l10n),
            if (viewData.state.pendingResources.isNotEmpty ||
                controller.pendingImages.isNotEmpty)
              _attachmentCards(),
            if (viewData.mobile && viewData.state.queuedMessages.isNotEmpty)
              _queuedMessages(theme, l10n),
            Padding(
              padding: EdgeInsets.fromLTRB(
                6,
                0,
                viewData.mobile ? 6 : 8,
                viewData.mobile ? 6 : 8,
              ),
              child: _composerControls(theme, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editor(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final target = viewData.mobile ? 44.0 : 40.0;
    final trailingControls = viewData.running ? 2 : 1;
    final editor = TextField(
      key: const ValueKey('agent-chat-input'),
      controller: controller.inputController,
      focusNode: controller.inputFocus,
      enabled: viewData.state.initialized,
      expands: _editorExpanded,
      minLines: _editorExpanded
          ? null
          : AgentChatComposerLayout.defaultMinLines,
      maxLines: _editorExpanded
          ? null
          : viewData.mobile
          ? AgentChatComposerLayout.defaultMobileMaxLines
          : AgentChatComposerLayout.defaultDesktopMaxLines,
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        isDense: true,
        hintText: l10n.agentChat_inputHint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.68),
        ),
        contentPadding: EdgeInsets.fromLTRB(
          viewData.mobile ? 14 : 13,
          14,
          target * trailingControls + 6,
          10,
        ),
        border: InputBorder.none,
      ),
    );
    final availableHeight = viewData.height
        .clamp(0, AgentChatComposerLayout.availableViewportHeight(context))
        .toDouble();

    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
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
                    touchOptimized: viewData.mobile,
                  )
                : null,
            child: editor,
          ),
          Positioned(
            top: 2,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (viewData.running)
                  _StopButton(
                    touchOptimized: viewData.mobile,
                    onStop: commands.stop,
                  ),
                AgentChatComposerExpandButton(
                  key: const ValueKey('agent-chat-composer-expand'),
                  expanded: _editorExpanded,
                  touchOptimized: viewData.mobile,
                  expandLabel:
                      '${l10n.common_expand} · ${l10n.agentChat_inputHint}',
                  collapseLabel:
                      '${l10n.common_collapse} · ${l10n.agentChat_inputHint}',
                  onPressed: _toggleEditorExpanded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composerControls(ThemeData theme, AppLocalizations l10n) {
    return LayoutBuilder(
      key: const ValueKey('agent-chat-composer-controls'),
      builder: (context, constraints) {
        final target = viewData.mobile ? 48.0 : 40.0;
        final compactTarget = viewData.mobile ? 44.0 : 40.0;
        const gap = 4.0;
        // The attachment target is larger than the other compact controls on
        // mobile, while the model selector absorbs the remaining width.
        final modelWidth =
            (constraints.maxWidth - target - compactTarget * 4 - gap * 5)
                .clamp(compactTarget, 164.0)
                .toDouble();
        final hasDraft =
            controller.inputController.text.trim().isNotEmpty ||
            controller.pendingImages.isNotEmpty;
        final primaryAction = _SendButton(
          running: viewData.running,
          enabled: viewData.canSend && hasDraft,
          touchOptimized: viewData.mobile,
          onSend: commands.send,
        );

        return SizedBox(
          key: const ValueKey('agent-chat-session-controls'),
          height: target,
          child: Row(
            key: const ValueKey('agent-chat-message-actions'),
            children: [
              _attachmentSourceButton(theme, l10n),
              const SizedBox(width: gap),
              SizedBox(
                width: modelWidth,
                child: _modelSelector(theme, l10n, iconOnly: modelWidth < 76),
              ),
              const Spacer(),
              _permissionModeButton(theme, l10n),
              const SizedBox(width: gap),
              _webAccessToggle(theme, l10n),
              const SizedBox(width: gap),
              _contextIndicator(theme, l10n),
              const SizedBox(width: gap),
              primaryAction,
            ],
          ),
        );
      },
    );
  }

  Widget _contextIndicator(ThemeData theme, AppLocalizations l10n) {
    final usage = viewData.state.contextUsage;
    final tokens = usage.tokens;
    final window = usage.contextWindow;
    final available = usage.available;
    final loading =
        viewData.state.compacting ||
        viewData.state.sessionContentLoading ||
        (!viewData.state.routeReady && viewData.state.routeError.isEmpty);
    final percent = available
        ? (tokens! / window! * 100).clamp(0, 999).round()
        : null;
    final label = loading
        ? viewData.state.compacting
              ? l10n.agentChat_compacting
              : l10n.common_loading
        : available
        ? '$percent% · ${usage.estimated ? '~' : ''}${_compactTokenCount(tokens!)} / ${_compactTokenCount(window!)}'
        : l10n.agentChat_contextUnavailable;
    final onPressed = available && !loading && viewData.sessionActionsEnabled
        ? () => commands.moreAction(AgentChatMoreAction.compact)
        : null;
    final target = viewData.mobile ? 44.0 : 40.0;
    final ringSize = viewData.mobile ? 36.0 : 32.0;

    return Semantics(
      button: onPressed != null,
      label: label,
      value: percent == null ? null : '$percent%',
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              key: const ValueKey('agent-chat-context-target'),
              dimension: target,
              child: Center(
                child: SizedBox.square(
                  key: const ValueKey('agent-chat-context-ring'),
                  dimension: ringSize,
                  child: loading
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            key: const ValueKey('agent-chat-context-loading'),
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2.5,
                              value: available
                                  ? (tokens! / window!).clamp(0.0, 1.0)
                                  : 0,
                              color: theme.colorScheme.primary,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                            Center(
                              child: Text(
                                available ? '$percent%' : '—',
                                key: available
                                    ? const ValueKey(
                                        'agent-chat-context-token-label',
                                      )
                                    : const ValueKey(
                                        'agent-chat-context-unavailable',
                                      ),
                                maxLines: 1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: available && percent! >= 100
                                      ? 8
                                      : 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
              minTileHeight: viewData.mobile ? 44 : 32,
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
                    maxHeight: viewData.compactMobile
                        ? 64
                        : viewData.mobile
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
                          if (viewData.mobile)
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
                              width: viewData.mobile ? 44 : 32,
                              height: viewData.mobile ? 44 : 32,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.common_delete,
                            onPressed: () => commands.removeQueuedMessage(item),
                            icon: const Icon(Icons.close, size: 16),
                            constraints: BoxConstraints.tightFor(
                              width: viewData.mobile ? 44 : 32,
                              height: viewData.mobile ? 44 : 32,
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
                      onPressed: commands.clearQueuedMessages,
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
      height: viewData.mobile ? 58 : 48,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
        scrollDirection: Axis.horizontal,
        itemCount: imageCount + viewData.state.pendingResources.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index < imageCount) {
            return AgentChatPendingImageCard(
              image: controller.pendingImages[index],
              touchOptimized: viewData.mobile,
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
            touchOptimized: viewData.mobile,
            onRemove: () => commands.removePendingResource(resourceIndex),
          );
        },
      ),
    );
  }

  Widget _attachmentSourceButton(ThemeData theme, AppLocalizations l10n) {
    final child = Container(
      width: viewData.mobile ? 48 : 40,
      height: viewData.mobile ? 48 : 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.76,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        Icons.add,
        size: 18,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
      ),
    );
    if (viewData.mobile) {
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

  Widget _permissionModeButton(ThemeData theme, AppLocalizations l10n) {
    final mode = viewData.agentSettings.settings.chat.permissionMode;
    final icon = switch (mode) {
      AgentPermissionMode.safe => Icons.shield_outlined,
      AgentPermissionMode.askBeforeSensitiveActions => Icons.gpp_maybe_outlined,
      AgentPermissionMode.fullAccess => Icons.lock_open_outlined,
    };
    return PopupMenuButton<AgentPermissionMode>(
      key: const ValueKey('agent-chat-permission-mode'),
      enabled: _agentSettingsInteractive,
      tooltip:
          '${l10n.agentChat_permissionMode}: ${agentPermissionModeLabel(l10n, mode)}',
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
        width: viewData.mobile ? 44 : 40,
        height: viewData.mobile ? 44 : 40,
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.56,
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
          ],
        ),
      ),
    );
  }

  Widget _webAccessToggle(ThemeData theme, AppLocalizations l10n) {
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
        width: viewData.mobile ? 44 : 40,
        height: viewData.mobile ? 44 : 40,
        decoration: BoxDecoration(
          color: enabled
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.56,
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
                width: viewData.mobile ? 44 : 40,
                height: viewData.mobile ? 44 : 40,
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
          ],
        ),
      ),
    );
  }

  Widget _modelSelector(
    ThemeData theme,
    AppLocalizations l10n, {
    required bool iconOnly,
  }) {
    final config = viewData.config;
    final enabled = config.providers
        .where((provider) => provider.enabled)
        .toList();
    if (enabled.isEmpty || !viewData.state.routeReady) {
      return Tooltip(
        key: const ValueKey('agent-chat-model-selector'),
        message: viewData.state.routeError.isNotEmpty
            ? viewData.state.routeError
            : l10n.agentChat_noModel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: theme.colorScheme.error.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                l10n.agentChat_noModel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    final modelReference = viewData.agentSettings.settings.chat.modelReference;
    final activeProviderId = modelReference.providerId;
    final activeModel = modelReference.model;
    var label = '';
    for (final provider in enabled) {
      if (provider.id != activeProviderId) continue;
      for (final model in config.modelsForProviderTask(
        providerId: provider.id,
        taskType: AssistantTaskType.chat,
      )) {
        if (model.name == activeModel) {
          label = model.displayName;
          break;
        }
      }
      if (label.isNotEmpty) break;
    }
    if (label.isEmpty) {
      label = activeModel.isEmpty ? viewData.state.routeLabel : activeModel;
    }
    final displayLabel = _shortModelLabel(label);
    return PopupMenuButton<(String, String)>(
      enabled: viewData.sessionActionsEnabled && _agentSettingsInteractive,
      tooltip: '${l10n.agentChat_model}: $label',
      onSelected: (route) => route.$1 == '__thinking__'
          ? commands.selectThinkingLevel(
              ThinkingLevel.values.firstWhere(
                (level) => level.name == route.$2,
              ),
            )
          : commands.selectModel(route.$1, route.$2),
      itemBuilder: (context) => [
        for (final provider in enabled) ...[
          PopupMenuItem<(String, String)>(
            enabled: false,
            height: viewData.mobile ? 40 : 30,
            child: Text(
              provider.name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final model
              in config
                  .modelsForProviderTask(
                    providerId: provider.id,
                    taskType: AssistantTaskType.chat,
                  )
                  .where((model) => !model.isPlaceholder))
            PopupMenuItem(
              value: (provider.id, model.name),
              height: viewData.mobile ? 48 : 36,
              child: Row(
                children: [
                  if (provider.id == activeProviderId &&
                      model.name == activeModel)
                    Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      model.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (provider == enabled.last &&
              viewData.state.availableThinkingLevels.isNotEmpty) ...[
            const PopupMenuDivider(),
            PopupMenuItem<(String, String)>(
              enabled: false,
              height: viewData.mobile ? 40 : 30,
              child: Text(
                l10n.agentChat_reasoningLevel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final level in viewData.state.availableThinkingLevels)
              PopupMenuItem(
                value: ('__thinking__', level.name),
                height: viewData.mobile ? 48 : 36,
                child: Row(
                  children: [
                    if (level == viewData.state.thinkingLevel)
                      Icon(
                        Icons.check,
                        size: 14,
                        color: theme.colorScheme.primary,
                      )
                    else
                      const SizedBox(width: 14),
                    const SizedBox(width: 6),
                    Text(_thinkingLevelLabel(l10n, level)),
                  ],
                ),
              ),
          ],
        ],
      ],
      child: Container(
        key: const ValueKey('agent-chat-model-selector'),
        height: viewData.mobile ? 44 : 40,
        padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconOnly
              ? [
                  Expanded(
                    child: Icon(
                      Icons.smart_toy_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ]
              : [
                  Flexible(
                    child: Text(
                      displayLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.expand_more,
                    size: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
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

  String _thinkingLevelLabel(AppLocalizations l10n, ThinkingLevel level) =>
      switch (level) {
        ThinkingLevel.off => l10n.agentChat_reasoningOff,
        ThinkingLevel.minimal => l10n.agentChat_reasoningMinimal,
        ThinkingLevel.low => l10n.agentChat_reasoningLow,
        ThinkingLevel.medium => l10n.agentChat_reasoningMedium,
        ThinkingLevel.high => l10n.agentChat_reasoningHigh,
        ThinkingLevel.xhigh => l10n.agentChat_reasoningXHigh,
        ThinkingLevel.max => l10n.agentChat_reasoningMax,
      };

  bool get _agentSettingsInteractive =>
      viewData.agentSettings.initialized &&
      viewData.agentSettings.error.isEmpty &&
      !viewData.controlsLocked;
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.running,
    required this.enabled,
    required this.onSend,
    required this.touchOptimized,
  });

  final bool running;
  final bool enabled;
  final VoidCallback onSend;
  final bool touchOptimized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final backgroundColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final foregroundColor = enabled
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface.withValues(alpha: 0.34);
    final label = running ? l10n.agentChat_queueSteering : l10n.agentChat_send;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 500),
        child: SizedBox(
          key: const ValueKey('agent-chat-send'),
          width: touchOptimized ? 44 : 40,
          height: touchOptimized ? 44 : 40,
          child: Center(
            child: Material(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(touchOptimized ? 14 : 10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onSend : null,
                child: SizedBox(
                  width: touchOptimized ? 40 : 36,
                  height: touchOptimized ? 40 : 36,
                  child: Icon(
                    running ? Icons.queue_rounded : Icons.arrow_upward_rounded,
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

class _StopButton extends StatelessWidget {
  const _StopButton({required this.touchOptimized, required this.onStop});

  final bool touchOptimized;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = context.l10n.agentChat_stop;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: IconButton(
          key: const ValueKey('agent-chat-stop'),
          onPressed: onStop,
          icon: const Icon(Icons.stop_rounded),
          iconSize: touchOptimized ? 20 : 18,
          color: theme.colorScheme.error,
          constraints: BoxConstraints.tightFor(
            width: touchOptimized ? 44 : 40,
            height: touchOptimized ? 44 : 40,
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
