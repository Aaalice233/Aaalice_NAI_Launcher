import 'dart:async';

import 'package:flutter/material.dart';
import '../../../widgets/common/provider_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../prompt_assistant/models/assistant_model_capability.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../widgets/common/searchable_model_picker.dart';
import '../widgets/prompt_assistant_settings_forms.dart';
import '../widgets/assistant_task_labels.dart';
import '../widgets/assistant_task_thinking_field.dart';
import '../widgets/settings_card.dart';

class PromptAssistantSettingsSection extends ConsumerWidget {
  const PromptAssistantSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(promptAssistantConfigProvider);
    final notifier = ref.read(promptAssistantConfigProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: context.l10n.settings_integrationConnectionSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                value: state.enabled,
                title: Text(context.l10n.promptAssistant_enableAssistant),
                subtitle: Text(
                  context.l10n.promptAssistant_settingsInputSwitchSubtitle,
                ),
                onChanged: notifier.setEnabled,
              ),
              if (PlatformCapabilities
                  .current
                  .supportsDesktopOverlayInteractions)
                SwitchListTile(
                  value: state.desktopOverlayEnabled,
                  title: Text(context.l10n.promptAssistant_desktopOverlayTitle),
                  subtitle: Text(
                    context.l10n.promptAssistant_desktopOverlaySubtitle,
                  ),
                  onChanged: notifier.setDesktopOverlayEnabled,
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.l10n.promptAssistant_responseTimeoutTitle),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.promptAssistant_responseTimeoutDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      key: const ValueKey('prompt-assistant-response-timeout'),
                      isExpanded: true,
                      value: state.responseTimeoutSeconds,
                      items: [
                        for (final seconds
                            in PromptAssistantConfigState
                                .responseTimeoutChoices)
                          DropdownMenuItem(
                            value: seconds,
                            child: Text(
                              context.l10n.queue_minutes(seconds ~/ 60),
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          notifier.setResponseTimeoutSeconds(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          key: const ValueKey('prompt-assistant-routing-section'),
          title: context.l10n.promptAssistant_taskRouting,
          description: context.l10n.promptAssistant_taskRoutingSubtitle,
          child: _buildRouting(context, state, notifier),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: context.l10n.promptAssistant_ruleTemplates,
          description: context.l10n.promptAssistant_ruleTemplatesSubtitle,
          child: _buildRules(context, state, notifier),
        ),
      ],
    );
  }

  Widget _buildRouting(
    BuildContext context,
    PromptAssistantConfigState state,
    PromptAssistantConfigNotifier notifier,
  ) {
    final providerItems = state.providers
        .map(
          (p) => DropdownMenuItem(
            value: p.id,
            child: ProviderNameLabel(provider: p),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth > 860;
            final cards = AssistantTaskType.values
                .where((taskType) => taskType != AssistantTaskType.chat)
                .map(
                  (taskType) => _buildTaskRouteCardForTask(
                    context: context,
                    state: state,
                    notifier: notifier,
                    taskType: taskType,
                    providerItems: providerItems,
                  ),
                )
                .toList();

            if (twoCols) {
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  cards[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTaskRouteCardForTask({
    required BuildContext context,
    required PromptAssistantConfigState state,
    required PromptAssistantConfigNotifier notifier,
    required AssistantTaskType taskType,
    required List<DropdownMenuItem<String>> providerItems,
  }) {
    final providerId = state.routing.providerIdFor(taskType);
    final modelName = state.routing.modelFor(taskType);
    final models = state.modelsForProviderTask(
      providerId: providerId,
      taskType: taskType,
    );
    final provider = state.providers
        .where((provider) => provider.id == providerId)
        .firstOrNull;
    final modelOptions =
        models
            .map(
              (model) => ModelPickerOption(
                id: model.name,
                modelId: model.name,
                value: model.name,
                title: _modelLabel(provider, model),
                tooltip: model.name,
                searchTerms: [providerId, model.name],
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    final hasRealModel = models.any(
      (m) => m.name.trim().isNotEmpty && m.name.trim() != 'default-model',
    );
    final useCurrentModel =
        models.any((m) => m.name == modelName) &&
        !(modelName.trim() == 'default-model' && hasRealModel);
    final modelValue = useCurrentModel
        ? modelName
        : models.isNotEmpty
        ? models.first.name
        : null;

    return _buildTaskRouteCard(
      context: context,
      title: taskType.localizedLabel(context.l10n),
      modelPickerKeyPrefix: 'prompt-route-${taskType.name}-model',
      thinkingField: AssistantTaskThinkingField(
        task: taskType,
        provider: state.providers.where((p) => p.id == providerId).firstOrNull,
        model: modelValue,
        value: state.routing.thinkingFor(taskType),
        onChanged: (level) => notifier.setRouting(
          state.routing.copyWith(
            thinkingLevels: {...state.routing.thinkingLevels, taskType: level},
          ),
        ),
      ),
      providerValue: providerItems.any((item) => item.value == providerId)
          ? providerId
          : null,
      providerItems: providerItems,
      onProviderChanged: (value) {
        if (value == null) return;
        final providerModels = state.modelsForProviderTask(
          providerId: value,
          taskType: taskType,
        );
        final firstModel = providerModels.isNotEmpty
            ? providerModels.first
            : ModelConfig(
                providerId: value,
                name: 'default-model',
                displayName: 'default-model',
                forTask: taskType,
              );
        unawaited(notifier.upsertModel(firstModel.copyWith(forTask: taskType)));
        notifier.setRouting(
          state.routing.copyWithTask(
            taskType: taskType,
            providerId: value,
            model: firstModel.name,
          ),
        );
      },
      modelValue: modelValue,
      modelOptions: modelOptions,
      onModelChanged: modelOptions.isEmpty
          ? null
          : (value) {
              if (value == null) return;
              final selectedModel = models.firstWhere(
                (model) => model.name == value,
              );
              unawaited(notifier.upsertModel(selectedModel));
              notifier.setRouting(
                state.routing.copyWithTask(
                  taskType: taskType,
                  providerId: providerId,
                  model: value,
                ),
              );
            },
    );
  }

  Widget _buildTaskRouteCard({
    required BuildContext context,
    required String title,
    required String modelPickerKeyPrefix,
    required Widget thinkingField,
    required String? providerValue,
    required List<DropdownMenuItem<String>> providerItems,
    required ValueChanged<String?> onProviderChanged,
    required String? modelValue,
    required List<ModelPickerOption<String>> modelOptions,
    required ValueChanged<String?>? onModelChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.promptAssistant_taskRouteTitle(title),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: providerValue,
            isExpanded: true,
            items: providerItems,
            onChanged: onProviderChanged,
            decoration: InputDecoration(
              labelText: context.l10n.promptAssistant_provider,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SearchableModelPickerField<String>(
            keyPrefix: modelPickerKeyPrefix,
            pickerTitle: context.l10n.agentChat_modelPickerTitle,
            searchLabel: context.l10n.agentChat_searchModels,
            searchHint: context.l10n.agentChat_searchModelsHint,
            clearSearchTooltip: context.l10n.agentChat_clearModelSearch,
            emptyMessage: context.l10n.agentChat_noModelResults,
            options: modelOptions,
            selectedId: modelValue,
            emptyLabel: context.l10n.promptAssistant_noModelsPullFirst,
            enabled: onModelChanged != null,
            onSelected: (value) => onModelChanged?.call(value),
            decoration: InputDecoration(
              labelText: context.l10n.promptAssistant_model,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          thinkingField,
        ],
      ),
    );
  }

  Widget _buildRules(
    BuildContext context,
    PromptAssistantConfigState state,
    PromptAssistantConfigNotifier notifier,
  ) {
    final rules =
        state.rules
            .where((rule) => rule.taskType != AssistantTaskType.chat)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return Column(
      children: [
        ...rules.map(
          (rule) => ListTile(
            title: Text(localizedRuleName(context.l10n, rule)),
            subtitle: Text(
              _displayRuleContent(context, rule),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            leading: Switch(
              value: rule.enabled,
              onChanged: (value) {
                notifier.upsertRule(rule.copyWith(enabled: value));
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showRuleDialog(context, notifier, rule: rule),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _showRuleDialog(context, notifier),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.promptAssistant_addRule),
          ),
        ),
      ],
    );
  }

  Future<void> _showRuleDialog(
    BuildContext context,
    PromptAssistantConfigNotifier notifier, {
    PromptRuleTemplate? rule,
  }) async {
    final newRuleName = context.l10n.promptAssistant_newRule;
    final result =
        await AdaptivePresenter.showForm<PromptAssistantRuleFormResult>(
          context: context,
          dialogWidth: 560,
          title: rule == null
              ? context.l10n.promptAssistant_addRuleTitle
              : context.l10n.promptAssistant_editRuleTitle,
          builder: (context, scrollController) => PromptAssistantRuleForm(
            rule: rule,
            scrollController: scrollController,
          ),
        );
    if (result == null) return;
    if (result.deleted) {
      await notifier.removeRule(rule!.id);
      return;
    }

    final next = PromptRuleTemplate(
      id: rule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
      name: result.name.isEmpty ? newRuleName : result.name,
      taskType: result.taskType,
      content: result.content,
      enabled: rule?.enabled ?? true,
      isDefault: rule?.isDefault ?? false,
      order: rule?.order ?? 100,
    );

    await notifier.upsertRule(next);
  }

  String _modelLabel(ProviderConfig? provider, ModelConfig model) {
    if (provider == null) {
      final custom = model.displayName.trim();
      return custom.isEmpty ? model.name : custom;
    }
    return AssistantModelCatalog.displayLabel(provider: provider, model: model);
  }

  String _displayRuleContent(BuildContext context, PromptRuleTemplate rule) {
    if (!rule.isDefault || !_usesBuiltinDefaultContent(rule)) {
      return rule.content;
    }
    final l10n = context.l10n;
    return switch (rule.id) {
      'opt_default' => l10n.promptAssistant_defaultOptimizeRuleContent,
      'translate_default' => l10n.promptAssistant_defaultTranslateRuleContent,
      'reverse_default' => l10n.promptAssistant_defaultReverseRuleContent,
      'character_replace_default' =>
        l10n.promptAssistant_defaultCharacterReplaceRuleContent,
      'custom_default' => l10n.promptAssistant_defaultCustomRuleContent,
      _ => rule.content,
    };
  }

  bool _usesBuiltinDefaultContent(PromptRuleTemplate rule) {
    PromptRuleTemplate? defaultRule;
    for (final candidate in PromptAssistantConfigState.defaults().rules) {
      if (candidate.id == rule.id) {
        defaultRule = candidate;
        break;
      }
    }
    if (defaultRule == null) return false;
    return rule.content.trim() == defaultRule.content.trim();
  }
}
