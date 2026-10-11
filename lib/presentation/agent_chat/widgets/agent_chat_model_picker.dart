import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/agent/agent_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../prompt_assistant/models/assistant_model_capability.dart';
import '../../widgets/common/searchable_model_picker.dart';
import '../../widgets/common/model_family_icon.dart';
import '../../widgets/common/provider_icon.dart';

double _agentChatControlExtent(BuildContext context) => math.max(
  context.interactionPolicy.minimumControlExtent,
  MediaQuery.textScalerOf(context).scale(16) + 12,
);

/// 将模型与思考强度收进同一个分级入口，避免高频输入区被两个选择器占满。
class AgentChatConfigurationControl extends StatelessWidget {
  const AgentChatConfigurationControl({
    super.key,
    required this.config,
    required this.agentSettings,
    required this.routeLabel,
    required this.routeError,
    required this.thinkingLevel,
    required this.availableThinkingLevels,
    required this.enabled,
    required this.onModelSelected,
    required this.onThinkingSelected,
    this.restoreFocusNode,
    this.showModelName = true,
  });

  final PromptAssistantConfigState config;
  final AgentSettingsState agentSettings;
  final String routeLabel;
  final String routeError;
  final ThinkingLevel thinkingLevel;
  final List<ThinkingLevel> availableThinkingLevels;
  final bool enabled;
  final Future<void> Function(String providerId, String model) onModelSelected;
  final Future<void> Function(ThinkingLevel level) onThinkingSelected;
  final FocusNode? restoreFocusNode;
  final bool showModelName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = _modelOptions(config);
    final current = _currentModelOption(options, agentSettings);
    final modelName = _modelDisplayName(
      current: current,
      reference: agentSettings.settings.chat.modelReference,
      routeLabel: routeLabel,
      emptyLabel: l10n.agentChat_noModel,
    );
    final thinkingName = thinkingLevelLabel(l10n, thinkingLevel);
    final interactive =
        enabled && (options.isNotEmpty || availableThinkingLevels.isNotEmpty);
    final tooltip = routeError.isNotEmpty
        ? routeError
        : '${l10n.agentChat_modelLabel}: $modelName · '
              '${l10n.agentChat_reasoningLevel}: $thinkingName';
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: interactive,
        label: tooltip,
        child: Material(
          key: const ValueKey('agent-chat-model-selector-surface'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            key: const ValueKey('agent-chat-model-selector'),
            borderRadius: BorderRadius.circular(11),
            onTap: interactive
                ? () => _openConfigurationPicker(context, current)
                : null,
            child: SizedBox(
              height: math.max(42, _agentChatControlExtent(context)),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: showModelName ? 11 : 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ModelFamilyIcon(
                      modelId:
                          current?.model.name ??
                          agentSettings.settings.chat.modelReference.model,
                      displayName: modelName,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    if (showModelName) ...[
                      Flexible(
                        child: Text(
                          modelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        thinkingName,
                        key: const ValueKey('agent-chat-thinking-selector'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.expand_more_rounded, size: 17),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openConfigurationPicker(
    BuildContext context,
    _AgentChatModelOption? current,
  ) async {
    final restoreFocus = restoreFocusNode?.hasFocus ?? false;
    restoreFocusNode?.unfocus();
    final selection =
        await AdaptivePresenter.showPicker<_AgentChatConfigurationSelection>(
          context: context,
          initialChildSize: 0.64,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          width: 440,
          maxCenteredHeight: 480,
          restoreFocus: false,
          builder: (_, scrollController) => _AgentChatConfigurationPickerBody(
            options: _modelOptions(config),
            selectedModel: current,
            thinkingLevel: thinkingLevel,
            availableThinkingLevels: availableThinkingLevels,
            scrollController: scrollController,
          ),
        );
    if (selection?.model case final model?) {
      await onModelSelected(model.provider.id, model.model.name);
    } else if (selection?.thinkingLevel case final level?) {
      await onThinkingSelected(level);
    }
    if (context.mounted &&
        restoreFocus &&
        restoreFocusNode?.canRequestFocus == true) {
      restoreFocusNode!.requestFocus();
    }
  }
}

class _AgentChatConfigurationSelection {
  const _AgentChatConfigurationSelection.model(this.model)
    : thinkingLevel = null;

  const _AgentChatConfigurationSelection.thinking(this.thinkingLevel)
    : model = null;

  final _AgentChatModelOption? model;
  final ThinkingLevel? thinkingLevel;
}

class _AgentChatConfigurationPickerBody extends StatefulWidget {
  const _AgentChatConfigurationPickerBody({
    required this.options,
    required this.selectedModel,
    required this.thinkingLevel,
    required this.availableThinkingLevels,
    required this.scrollController,
  });

  final List<_AgentChatModelOption> options;
  final _AgentChatModelOption? selectedModel;
  final ThinkingLevel thinkingLevel;
  final List<ThinkingLevel> availableThinkingLevels;
  final ScrollController scrollController;

  @override
  State<_AgentChatConfigurationPickerBody> createState() =>
      _AgentChatConfigurationPickerBodyState();
}

class _AgentChatConfigurationPickerBodyState
    extends State<_AgentChatConfigurationPickerBody> {
  var _showModels = false;

  @override
  Widget build(BuildContext context) {
    if (_showModels) {
      final l10n = context.l10n;
      return SearchableModelPickerBody<_AgentChatModelOption>(
        title: l10n.agentChat_modelPickerTitle,
        searchLabel: l10n.agentChat_searchModels,
        searchHint: l10n.agentChat_searchModelsHint,
        clearSearchTooltip: l10n.agentChat_clearModelSearch,
        emptyMessage: l10n.agentChat_noModelResults,
        options: _pickerOptions(widget.options),
        selectedId: widget.selectedModel?.pickerId,
        scrollController: widget.scrollController,
        keyPrefix: 'agent-chat-model',
        headerKeyPrefix: 'agent-chat-model-picker',
        onBack: () => setState(() => _showModels = false),
        onSelected: (option) => Navigator.pop(
          context,
          _AgentChatConfigurationSelection.model(option.value),
        ),
      );
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final currentModel =
        widget.selectedModel?.displayName ?? l10n.agentChat_noModel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PickerHeader(
          title:
              '${l10n.agentChat_modelLabel} · ${l10n.agentChat_reasoningLevel}',
        ),
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            controller: widget.scrollController,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            children: [
              Material(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.52,
                ),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  key: const ValueKey('agent-chat-model-submenu'),
                  leading: ModelFamilyIcon(
                    modelId: widget.selectedModel?.model.name ?? currentModel,
                    displayName: currentModel,
                    size: 22,
                  ),
                  minTileHeight: math.max(56, _agentChatControlExtent(context)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  title: Text(
                    l10n.agentChat_modelLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    currentModel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => setState(() => _showModels = true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 4),
                child: Text(
                  l10n.agentChat_reasoningLevel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final option in widget.availableThinkingLevels)
                ListTile(
                  key: ValueKey('agent-chat-thinking-option-${option.name}'),
                  minTileHeight: _agentChatControlExtent(context),
                  leading: SizedBox(
                    width: 20,
                    child: option == widget.thinkingLevel
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  title: Text(thinkingLevelLabel(l10n, option)),
                  onTap: () => Navigator.pop(
                    context,
                    _AgentChatConfigurationSelection.thinking(option),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 8, top: 4),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                key: const ValueKey('agent-chat-model-picker-title'),
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: const ValueKey('agent-chat-model-picker-close'),
              onPressed: () => Navigator.maybePop(context),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class AgentChatModelControl extends StatelessWidget {
  const AgentChatModelControl({
    super.key,
    required this.config,
    required this.agentSettings,
    required this.routeLabel,
    required this.routeError,
    required this.enabled,
    required this.onSelected,
    this.restoreFocusNode,
    this.showLabel = true,
  });

  final PromptAssistantConfigState config;
  final AgentSettingsState agentSettings;
  final String routeLabel;
  final String routeError;
  final bool enabled;
  final Future<void> Function(String providerId, String model) onSelected;
  final FocusNode? restoreFocusNode;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = _modelOptions(config);
    final reference = agentSettings.settings.chat.modelReference;
    final current = options.cast<_AgentChatModelOption?>().firstWhere(
      (option) =>
          option?.provider.id == reference.providerId &&
          option?.model.name == reference.model,
      orElse: () => null,
    );
    final displayValue = _modelDisplayName(
      current: current,
      reference: reference,
      routeLabel: routeLabel,
      emptyLabel: l10n.agentChat_noModel,
    );
    final interactive = enabled && options.isNotEmpty;
    final tooltip = routeError.isNotEmpty
        ? routeError
        : '${l10n.agentChat_modelLabel}: $displayValue';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: interactive,
        label: tooltip,
        child: Material(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: const ValueKey('agent-chat-model-selector'),
            borderRadius: BorderRadius.circular(8),
            onTap: interactive ? () => _openPicker(context, current) : null,
            child: SizedBox(
              height: _agentChatControlExtent(context),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: showLabel ? 10 : 6),
                child: Row(
                  children: [
                    if (showLabel) ...[
                      Text(
                        '${l10n.agentChat_modelLabel}:',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(width: 4),
                    ],
                    ModelFamilyIcon(
                      modelId: current?.model.name ?? reference.model,
                      displayName: displayValue,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        displayValue,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: showLabel ? 4 : 2),
                    Icon(Icons.expand_more_rounded, size: showLabel ? 16 : 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    _AgentChatModelOption? current,
  ) async {
    final restoreFocus = restoreFocusNode?.hasFocus ?? false;
    restoreFocusNode?.unfocus();
    final selected = await _showAgentChatModelPicker(
      context,
      options: _modelOptions(config),
      selected: current,
    );
    if (selected != null) {
      await onSelected(selected.provider.id, selected.model.name);
    }
    if (context.mounted &&
        restoreFocus &&
        restoreFocusNode?.canRequestFocus == true) {
      restoreFocusNode!.requestFocus();
    }
  }
}

class AgentChatThinkingControl extends StatelessWidget {
  const AgentChatThinkingControl({
    super.key,
    required this.level,
    required this.availableLevels,
    required this.enabled,
    required this.onSelected,
    this.showLabel = true,
  });

  final ThinkingLevel level;
  final List<ThinkingLevel> availableLevels;
  final bool enabled;
  final Future<void> Function(ThinkingLevel level) onSelected;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = thinkingLevelLabel(l10n, level);
    final interactive = enabled && availableLevels.isNotEmpty;
    return PopupMenuButton<ThinkingLevel>(
      enabled: interactive,
      tooltip: '${l10n.agentChat_reasoningLevel}: $value',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in availableLevels)
          PopupMenuItem<ThinkingLevel>(
            value: option,
            height: _agentChatControlExtent(context),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: option == level
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(thinkingLevelLabel(l10n, option)),
              ],
            ),
          ),
      ],
      child: Semantics(
        button: true,
        enabled: interactive,
        label: '${l10n.agentChat_reasoningLevel}: $value',
        child: Container(
          key: const ValueKey('agent-chat-thinking-selector'),
          height: _agentChatControlExtent(context),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabel) ...[
                Flexible(
                  child: Text(
                    '${l10n.agentChat_reasoningLevel}:',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (interactive && showLabel) ...[
                const SizedBox(width: 2),
                const Icon(Icons.expand_more_rounded, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<_AgentChatModelOption?> _showAgentChatModelPicker(
  BuildContext context, {
  required List<_AgentChatModelOption> options,
  required _AgentChatModelOption? selected,
}) {
  final l10n = context.l10n;
  return showSearchableModelPicker<_AgentChatModelOption>(
    context: context,
    title: l10n.agentChat_modelPickerTitle,
    searchLabel: l10n.agentChat_searchModels,
    searchHint: l10n.agentChat_searchModelsHint,
    clearSearchTooltip: l10n.agentChat_clearModelSearch,
    emptyMessage: l10n.agentChat_noModelResults,
    options: _pickerOptions(options),
    selectedId: selected?.pickerId,
    keyPrefix: 'agent-chat-model',
    headerKeyPrefix: 'agent-chat-model-picker',
  );
}

class _AgentChatModelOption {
  _AgentChatModelOption({required this.provider, required this.model})
    : displayName = AssistantModelCatalog.displayLabel(
        provider: provider,
        model: model,
      );

  final ProviderConfig provider;
  final ModelConfig model;
  final String displayName;

  String get pickerId => '${provider.id}\u0000${model.name}';
}

List<ModelPickerOption<_AgentChatModelOption>> _pickerOptions(
  List<_AgentChatModelOption> options,
) => [
  for (final option in options)
    ModelPickerOption(
      id: option.pickerId,
      value: option,
      title: option.displayName,
      modelId: option.model.name,
      tooltip: option.model.name,
      group: ModelPickerGroup(
        id: option.provider.id,
        label: option.provider.name,
        leading: ProviderIcon(provider: option.provider, size: 14),
      ),
      searchTerms: [option.provider.id, option.model.name],
      keyValue: '${option.provider.id}-${option.model.name}',
    ),
];

_AgentChatModelOption? _currentModelOption(
  List<_AgentChatModelOption> options,
  AgentSettingsState agentSettings,
) {
  final reference = agentSettings.settings.chat.modelReference;
  return options.cast<_AgentChatModelOption?>().firstWhere(
    (option) =>
        option?.provider.id == reference.providerId &&
        option?.model.name == reference.model,
    orElse: () => null,
  );
}

String _modelDisplayName({
  required _AgentChatModelOption? current,
  required AgentModelReference reference,
  required String routeLabel,
  required String emptyLabel,
}) {
  final fallback = reference.model.isEmpty ? routeLabel : reference.model;
  final value = (current?.displayName ?? fallback).trim();
  return value.isEmpty ? emptyLabel : value;
}

// 组内按用户看到的名称排序，而不是按存储的模型 ID。
List<_AgentChatModelOption> _modelOptions(PromptAssistantConfigState config) =>
    [
      for (final provider in config.providers)
        if (provider.enabled)
          ...[
            for (final model in config.modelsForProviderTask(
              providerId: provider.id,
              taskType: AssistantTaskType.chat,
            ))
              if (!model.isPlaceholder)
                _AgentChatModelOption(provider: provider, model: model),
          ]..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          ),
    ];

String thinkingLevelLabel(AppLocalizations l10n, ThinkingLevel level) =>
    switch (level) {
      ThinkingLevel.off => l10n.agentChat_reasoningOff,
      ThinkingLevel.minimal => l10n.agentChat_reasoningMinimal,
      ThinkingLevel.low => l10n.agentChat_reasoningLow,
      ThinkingLevel.medium => l10n.agentChat_reasoningMedium,
      ThinkingLevel.high => l10n.agentChat_reasoningHigh,
      ThinkingLevel.xhigh => l10n.agentChat_reasoningXHigh,
      ThinkingLevel.max => l10n.agentChat_reasoningMax,
    };
