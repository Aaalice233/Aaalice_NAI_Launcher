import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../prompt_assistant/models/prompt_assistant_models.dart';

class AgentChatModelControl extends StatelessWidget {
  const AgentChatModelControl({
    super.key,
    required this.config,
    required this.agentSettings,
    required this.routeLabel,
    required this.routeError,
    required this.enabled,
    required this.touchOptimized,
    required this.onSelected,
    this.restoreFocusNode,
  });

  final PromptAssistantConfigState config;
  final AgentSettingsState agentSettings;
  final String routeLabel;
  final String routeError;
  final bool enabled;
  final bool touchOptimized;
  final Future<void> Function(String providerId, String model) onSelected;
  final FocusNode? restoreFocusNode;

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
    final fallback = reference.model.isEmpty ? routeLabel : reference.model;
    final value = current?.model.displayName.trim().isNotEmpty == true
        ? current!.model.displayName.trim()
        : fallback.trim();
    final displayValue = value.isEmpty ? l10n.agentChat_noModel : value;
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
              height: touchOptimized ? 44 : 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Text(
                      '${l10n.agentChat_modelLabel}:',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(width: 4),
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
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more_rounded, size: 16),
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
      touchOptimized: touchOptimized,
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
    required this.touchOptimized,
    required this.onSelected,
  });

  final ThinkingLevel level;
  final List<ThinkingLevel> availableLevels;
  final bool enabled;
  final bool touchOptimized;
  final Future<void> Function(ThinkingLevel level) onSelected;

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
            height: touchOptimized ? 48 : 40,
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
          height: touchOptimized ? 44 : 40,
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
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
              ),
              if (interactive) ...[
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
  required bool touchOptimized,
}) {
  final picker = _AgentChatModelPickerBody(
    options: options,
    selected: selected,
    touchOptimized: touchOptimized,
  );
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<_AgentChatModelOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: FractionallySizedBox(heightFactor: 0.78, child: picker),
      ),
    );
  }
  return showDialog<_AgentChatModelOption>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
        child: picker,
      ),
    ),
  );
}

class _AgentChatModelPickerBody extends StatefulWidget {
  const _AgentChatModelPickerBody({
    required this.options,
    required this.selected,
    required this.touchOptimized,
  });

  final List<_AgentChatModelOption> options;
  final _AgentChatModelOption? selected;
  final bool touchOptimized;

  @override
  State<_AgentChatModelPickerBody> createState() =>
      _AgentChatModelPickerBodyState();
}

class _AgentChatModelPickerBodyState extends State<_AgentChatModelPickerBody> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  var _query = '';
  var _highlightedIndex = 0;

  List<_AgentChatModelOption> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    return widget.options
        .where((option) => option.searchText.contains(query))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final selectedIndex = widget.selected == null
        ? -1
        : widget.options.indexWhere(
            (option) => option.sameModel(widget.selected!),
          );
    _highlightedIndex = selectedIndex < 0 ? 0 : selectedIndex;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final filtered = _filtered;
    final rowExtent = widget.touchOptimized ? 72.0 : 64.0;
    return Focus(
      onKeyEvent: (node, event) => _handleKey(event, filtered, rowExtent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.agentChat_modelPickerTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              key: const ValueKey('agent-chat-model-search'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _query = value;
                  _highlightedIndex = 0;
                });
                _scrollToHighlight(rowExtent);
              },
              decoration: InputDecoration(
                labelText: l10n.agentChat_searchModels,
                hintText: l10n.agentChat_searchModelsHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('agent-chat-model-search-clear'),
                        tooltip: l10n.agentChat_clearModelSearch,
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.agentChat_noModelResults,
                        key: const ValueKey('agent-chat-model-empty'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey('agent-chat-model-results'),
                    controller: _scrollController,
                    itemExtent: rowExtent,
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final option = filtered[index];
                      final selected =
                          widget.selected?.sameModel(option) == true;
                      final highlighted = index == _highlightedIndex;
                      return Semantics(
                        selected: selected,
                        button: true,
                        label:
                            '${option.displayName}, ${option.provider.name}, ${option.model.name}',
                        child: Material(
                          color: highlighted
                              ? theme.colorScheme.surfaceContainerHighest
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            key: ValueKey(
                              'agent-chat-model-option-${option.provider.id}-${option.model.name}',
                            ),
                            borderRadius: BorderRadius.circular(6),
                            onHover: (hovered) {
                              if (hovered && _highlightedIndex != index) {
                                setState(() => _highlightedIndex = index);
                              }
                            },
                            onTap: () => Navigator.pop(context, option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    child: selected
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.displayName,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : null,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _modelMetadata(option),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKey(
    KeyEvent event,
    List<_AgentChatModelOption> filtered,
    double rowExtent,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_query.isNotEmpty) {
        _clearSearch();
      } else {
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    }
    if (filtered.isEmpty) return KeyEventResult.ignored;
    int? next;
    if (key == LogicalKeyboardKey.arrowDown) {
      next = (_highlightedIndex + 1).clamp(0, filtered.length - 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      next = (_highlightedIndex - 1).clamp(0, filtered.length - 1);
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = filtered.length - 1;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      Navigator.pop(context, filtered[_highlightedIndex]);
      return KeyEventResult.handled;
    }
    if (next == null) return KeyEventResult.ignored;
    setState(() => _highlightedIndex = next!);
    _scrollToHighlight(rowExtent);
    return KeyEventResult.handled;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      final selectedIndex = widget.selected == null
          ? -1
          : widget.options.indexWhere(
              (option) => option.sameModel(widget.selected!),
            );
      _highlightedIndex = selectedIndex < 0 ? 0 : selectedIndex;
    });
    _searchFocusNode.requestFocus();
    _scrollToHighlight(widget.touchOptimized ? 72 : 64);
  }

  void _scrollToHighlight(double rowExtent) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = (_highlightedIndex * rowExtent).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _modelMetadata(_AgentChatModelOption option) {
    if (option.displayName == option.model.name.trim()) {
      return '${option.provider.name} · ${option.provider.id}';
    }
    return '${option.provider.name} · ${option.model.name}';
  }
}

class _AgentChatModelOption {
  const _AgentChatModelOption({required this.provider, required this.model});

  final ProviderConfig provider;
  final ModelConfig model;

  String get displayName => model.displayName.trim().isEmpty
      ? model.name.trim()
      : model.displayName.trim();

  String get searchText => [
    provider.name,
    provider.id,
    displayName,
    model.name,
  ].join('\n').toLowerCase();

  bool sameModel(_AgentChatModelOption other) =>
      provider.id == other.provider.id && model.name == other.model.name;
}

List<_AgentChatModelOption> _modelOptions(PromptAssistantConfigState config) =>
    [
      for (final provider in config.providers)
        if (provider.enabled)
          for (final model in config.modelsForProviderTask(
            providerId: provider.id,
            taskType: AssistantTaskType.chat,
          ))
            if (!model.isPlaceholder)
              _AgentChatModelOption(provider: provider, model: model),
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
