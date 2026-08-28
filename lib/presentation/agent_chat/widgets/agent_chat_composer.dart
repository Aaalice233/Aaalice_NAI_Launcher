import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';
import '../providers/agent_chat_state.dart';
import 'agent_chat_header.dart';
import 'agent_chat_panel_controller.dart';
import 'agent_chat_panel_view_data.dart';

class AgentChatComposer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      key: const ValueKey('agent-chat-input-container'),
      padding: EdgeInsets.fromLTRB(
        viewData.mobile ? 12 : 8,
        6,
        viewData.mobile ? 12 : 8,
        viewData.mobile ? 10 : 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: viewData.mobile
              ? theme.colorScheme.surfaceContainerHigh
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(viewData.mobile ? 16 : 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (viewData.state.queuedMessages.isNotEmpty)
              _queuedMessages(theme, l10n),
            if (viewData.state.pendingResources.isNotEmpty)
              _resourceCards(theme),
            Focus(
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
                  commands.editQueuedMessage(
                    viewData.state.queuedMessages.last,
                  );
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
                if (controller.inputController.text.trim().isNotEmpty ||
                    controller.pendingImages.isNotEmpty) {
                  commands.send();
                }
                return KeyEventResult.handled;
              },
              child: TextField(
                key: const ValueKey('agent-chat-input'),
                controller: controller.inputController,
                focusNode: controller.inputFocus,
                enabled: viewData.state.initialized,
                minLines: viewData.compactMobile
                    ? 1
                    : (viewData.mobile ? 2 : 3),
                maxLines: viewData.compactMobile
                    ? 3
                    : (viewData.mobile ? 5 : 8),
                style:
                    (viewData.mobile
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.bodySmall)
                        ?.copyWith(height: 1.45),
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.agentChat_inputHint,
                  hintStyle:
                      (viewData.mobile
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.bodySmall)
                          ?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.75),
                          ),
                  contentPadding: EdgeInsets.fromLTRB(
                    viewData.mobile ? 14 : 12,
                    viewData.mobile ? 12 : 10,
                    viewData.mobile ? 14 : 12,
                    6,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                4,
                0,
                viewData.mobile ? 4 : 8,
                viewData.mobile ? 4 : 6,
              ),
              child: _composerControls(theme, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composerControls(ThemeData theme, AppLocalizations l10n) {
    final sendButton = _SendButton(
      running: viewData.running,
      enabled:
          viewData.canSend &&
          (controller.inputController.text.trim().isNotEmpty ||
              controller.pendingImages.isNotEmpty),
      touchOptimized: viewData.mobile,
      onSend: commands.send,
    );
    final leading = <Widget>[
      _attachButton(theme, l10n),
      _moreMenu(theme, l10n),
      SizedBox(width: viewData.mobile ? 0 : 2),
      _permissionModeButton(theme, l10n),
      const SizedBox(width: 2),
      _webAccessToggle(theme, l10n),
      const SizedBox(width: 2),
    ];
    if (viewData.mobile && viewData.running) {
      return Column(
        key: const ValueKey('agent-chat-composer-controls'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                ...leading,
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: _modelSelector(theme, l10n),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _followUpButton(l10n),
                _StopButton(touchOptimized: true, onStop: commands.stop),
                const SizedBox(width: 4),
                sendButton,
              ],
            ),
          ),
        ],
      );
    }
    return SizedBox(
      key: const ValueKey('agent-chat-composer-controls'),
      height: viewData.mobile ? 48 : 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...leading,
          if (!viewData.mobile) const Spacer(),
          if (viewData.mobile)
            Expanded(
              child: SizedBox(height: 48, child: _modelSelector(theme, l10n)),
            )
          else
            _modelSelector(theme, l10n),
          const SizedBox(width: 4),
          if (viewData.running) ...[
            _followUpButton(l10n),
            _StopButton(touchOptimized: viewData.mobile, onStop: commands.stop),
            const SizedBox(width: 4),
          ],
          sendButton,
        ],
      ),
    );
  }

  Widget _followUpButton(AppLocalizations l10n) => PopupMenuButton<bool>(
    tooltip: l10n.agentChat_queueFollowUp,
    onSelected: (_) => commands.sendFollowUp(),
    itemBuilder: (_) => [
      PopupMenuItem<bool>(
        value: true,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.playlist_add_rounded),
          title: Text(l10n.agentChat_queueFollowUp),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ],
    icon: const Icon(Icons.playlist_add_rounded, size: 18),
    constraints: BoxConstraints.tightFor(
      width: viewData.mobile ? 44 : 30,
      height: viewData.mobile ? 44 : 30,
    ),
  );

  Widget _queuedMessages(ThemeData theme, AppLocalizations l10n) {
    final queued = viewData.state.queuedMessages;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          key: const ValueKey('agent-chat-queue'),
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
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: TextButton(
            onPressed: commands.clearQueuedMessages,
            child: Text(l10n.common_clear),
          ),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: viewData.mobile ? 96 : 160,
              ),
              child: ListView.builder(
                primary: false,
                shrinkWrap: true,
                itemCount: queued.length,
                itemBuilder: (context, index) {
                  final item = queued[index];
                  return Row(
                    children: [
                      if (viewData.mobile)
                        Tooltip(
                          message: item.kind == AgentQueuedMessageKind.steering
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
          ],
        ),
      ),
    );
  }

  Widget _resourceCards(ThemeData theme) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
        scrollDirection: Axis.horizontal,
        itemCount: viewData.state.pendingResources.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final reference = viewData.state.pendingResources[index];
          final label =
              reference.display['name'] ??
              reference.display['title'] ??
              reference.resourceId;
          final unavailable = viewData.state.unavailableResourceKeys.contains(
            AgentChatResourceReferenceCodec.encodeJson(reference),
          );
          return Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.only(left: 9),
            decoration: BoxDecoration(
              color: unavailable
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.55)
                  : theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.55,
                    ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  unavailable ? Icons.link_off_outlined : Icons.link_outlined,
                  size: 15,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    unavailable
                        ? '$label · ${context.l10n.agentChat_resourceUnavailable}'
                        : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  iconSize: 15,
                  onPressed: () => commands.removePendingResource(index),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _attachButton(ThemeData theme, AppLocalizations l10n) {
    final enabled = viewData.state.initialized;
    return Tooltip(
      message: l10n.agentChat_attachImage,
      waitDuration: const Duration(milliseconds: 400),
      child: SizedBox(
        key: const ValueKey('agent-chat-attach-image'),
        width: viewData.mobile ? 48 : 30,
        height: viewData.mobile ? 48 : 30,
        child: InkWell(
          onTap: enabled ? commands.pickImages : null,
          borderRadius: BorderRadius.circular(8),
          child: Icon(
            Icons.image_outlined,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(
              alpha: enabled ? 0.65 : 0.25,
            ),
          ),
        ),
      ),
    );
  }

  Widget _moreMenu(ThemeData theme, AppLocalizations l10n) =>
      PopupMenuButton<AgentChatMoreAction>(
        key: const ValueKey('agent-chat-more-actions'),
        tooltip: l10n.agentChat_moreActions,
        onSelected: commands.moreAction,
        itemBuilder: (context) => [
          _moreItem(
            theme,
            AgentChatMoreAction.newSession,
            Icons.add_comment_outlined,
            l10n.agentChat_newChat,
          ),
          _moreItem(
            theme,
            AgentChatMoreAction.rename,
            Icons.edit_outlined,
            l10n.common_rename,
          ),
          _moreItem(
            theme,
            AgentChatMoreAction.compact,
            Icons.compress_outlined,
            l10n.agentChat_compact,
          ),
          _moreItem(
            theme,
            AgentChatMoreAction.delete,
            Icons.delete_outline,
            l10n.common_delete,
            danger: true,
          ),
        ],
        child: SizedBox(
          width: viewData.mobile ? 48 : 30,
          height: viewData.mobile ? 48 : 30,
          child: Icon(
            Icons.add,
            size: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      );

  PopupMenuItem<AgentChatMoreAction> _moreItem(
    ThemeData theme,
    AgentChatMoreAction value,
    IconData icon,
    String label, {
    bool danger = false,
  }) {
    final color = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface.withValues(alpha: 0.8);
    return PopupMenuItem(
      value: value,
      enabled: viewData.sessionActionsEnabled,
      height: viewData.mobile ? 48 : 36,
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: viewData.sessionActionsEnabled
                  ? color
                  : color.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
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
      child: SizedBox(
        width: viewData.mobile ? 48 : 30,
        height: viewData.mobile ? 48 : 30,
        child: Icon(
          icon,
          size: 17,
          color: theme.colorScheme.onSurface.withValues(
            alpha: _agentSettingsInteractive ? 0.6 : 0.25,
          ),
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
      child: SizedBox.square(
        dimension: viewData.mobile ? 48 : 30,
        child: IconButton(
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
            width: viewData.mobile ? 48 : 30,
            height: viewData.mobile ? 48 : 30,
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
      ),
    );
  }

  Widget _modelSelector(ThemeData theme, AppLocalizations l10n) {
    final config = viewData.config;
    final enabled = config.providers
        .where((provider) => provider.enabled)
        .toList();
    if (enabled.isEmpty || !viewData.state.routeReady) {
      return Tooltip(
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
    return PopupMenuButton<(String, String)>(
      enabled: viewData.sessionActionsEnabled && _agentSettingsInteractive,
      tooltip: l10n.agentChat_model,
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
        width: viewData.mobile ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: viewData.mobile ? 12 : 8,
          vertical: 5,
        ),
        constraints: BoxConstraints(
          minHeight: viewData.mobile ? 48 : 0,
          maxWidth: viewData.mobile ? double.infinity : 140,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 3),
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
    final foregroundColor = touchOptimized
        ? enabled
              ? theme.colorScheme.onPrimary
              : ThemeData.estimateBrightnessForColor(backgroundColor) ==
                    Brightness.light
              ? Colors.black54
              : Colors.white54
        : enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.3);
    return Tooltip(
      message: running ? l10n.agentChat_queueSteering : l10n.agentChat_send,
      waitDuration: const Duration(milliseconds: 500),
      child: SizedBox(
        key: const ValueKey('agent-chat-send'),
        width: touchOptimized ? 48 : 30,
        height: touchOptimized ? 48 : 30,
        child: Center(
          child: Material(
            color: touchOptimized ? backgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(touchOptimized ? 14 : 8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onSend : null,
              child: SizedBox(
                width: touchOptimized ? 40 : 30,
                height: touchOptimized ? 40 : 30,
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
    return Tooltip(
      message: context.l10n.agentChat_stop,
      child: IconButton(
        key: const ValueKey('agent-chat-stop'),
        onPressed: onStop,
        icon: const Icon(Icons.stop_rounded),
        iconSize: touchOptimized ? 20 : 18,
        color: theme.colorScheme.error,
        constraints: BoxConstraints.tightFor(
          width: touchOptimized ? 48 : 30,
          height: touchOptimized ? 48 : 30,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
