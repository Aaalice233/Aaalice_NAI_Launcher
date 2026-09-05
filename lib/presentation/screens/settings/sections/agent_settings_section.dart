import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/agent/agent_settings.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../prompt_assistant/models/assistant_model_capability.dart';
import '../../../agent_settings/providers/agent_settings_provider.dart';
import '../../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/searchable_model_picker.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_page_layout.dart';
import 'web_access_settings.dart';
import 'agent/agent_profile_actions.dart';
import 'agent/context_window_field.dart';
import 'agent/skill_management_panel.dart';
import 'agent/system_prompt_editor.dart';

class AgentSettingsSection extends ConsumerStatefulWidget {
  const AgentSettingsSection({super.key, this.onOpenIntegrations});

  final VoidCallback? onOpenIntegrations;

  @override
  ConsumerState<AgentSettingsSection> createState() =>
      _AgentSettingsSectionState();
}

class _AgentSettingsSectionState extends ConsumerState<AgentSettingsSection> {
  int _selectedPanel = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentSettingsProvider);
    final promptConfig = ref.watch(promptAssistantConfigProvider);
    if (!state.initialized) {
      return SettingsPageLayout(
        title: context.l10n.settings_agent,
        description: context.l10n.agentSettings_subtitle,
        children: const [
          SettingsCard(
            child: Align(
              alignment: Alignment.centerLeft,
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }
    if (state.error.isNotEmpty) {
      return SettingsPageLayout(
        title: context.l10n.settings_agent,
        description: context.l10n.agentSettings_subtitle,
        children: [
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(context.l10n.agentSettings_operationFailed(state.error)),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(agentSettingsProvider.notifier)
                      .retryInitialization(),
                  child: Text(context.l10n.common_retry),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final panelSelector = SegmentedButton<int>(
      key: const ValueKey('agent-settings-panel-selector'),
      segments: [
        ButtonSegment(
          value: 0,
          label: Text(context.l10n.agentSettings_systemPrompt),
        ),
        ButtonSegment(
          value: 1,
          label: Text(context.l10n.agentSettings_skillsTitle),
        ),
      ],
      selected: {_selectedPanel},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() => _selectedPanel = selection.single);
      },
    );

    return SettingsPageLayout(
      title: context.l10n.settings_agent,
      description: context.l10n.agentSettings_subtitle,
      actions: const AgentProfileActions(),
      children: [
        _ModelCard(
          settings: state.settings,
          promptConfig: promptConfig,
          onOpenIntegrations: widget.onOpenIntegrations,
        ),
        _ReadingPreferencesCard(settings: state.settings),
        _PermissionCard(settings: state.settings),
        _WebAccessCard(settings: state.settings),
        if (_selectedPanel == 0)
          AgentSystemPromptEditor(panelSelector: panelSelector)
        else
          SkillManagementPanel(panelSelector: panelSelector),
      ],
    );
  }
}

class _ModelCard extends ConsumerWidget {
  const _ModelCard({
    required this.settings,
    required this.promptConfig,
    required this.onOpenIntegrations,
  });

  final AgentSettings settings;
  final PromptAssistantConfigState promptConfig;
  final VoidCallback? onOpenIntegrations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = <AgentModelReference>[];
    final pickerOptions = <ModelPickerOption<AgentModelReference>>[];
    for (final provider in promptConfig.providers.where(
      (item) => item.enabled,
    )) {
      for (final model in promptConfig.models.where(
        (item) =>
            item.providerId == provider.id &&
            item.forTask == AssistantTaskType.chat &&
            !item.isPlaceholder,
      )) {
        final reference = AgentModelReference(
          providerId: provider.id,
          model: model.name,
        );
        available.add(reference);
        final displayName = model.displayName.trim().isEmpty
            ? model.name
            : model.displayName.trim();
        pickerOptions.add(
          ModelPickerOption(
            id: _modelPickerId(reference),
            value: reference,
            title: displayName,
            subtitle: displayName == model.name
                ? provider.name
                : '${provider.name} · ${model.name}',
            searchTerms: [provider.id],
          ),
        );
      }
    }
    final selected = settings.chat.modelReference;
    final isPending = selected.isConfigured && !available.contains(selected);
    if (isPending) {
      pickerOptions.insert(
        0,
        ModelPickerOption(
          id: _modelPickerId(selected),
          value: selected,
          title: selected.model,
          subtitle:
              '${selected.providerId} · ${context.l10n.agentSettings_pendingMatch}',
          searchTerms: [selected.providerId],
        ),
      );
    }
    final selectedOption = pickerOptions
        .where((option) => option.id == _modelPickerId(selected))
        .firstOrNull;
    return SettingsCard(
      title: context.l10n.agentSettings_chatModel,
      icon: Icons.smart_toy_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchableModelPickerField<AgentModelReference>(
            key: const ValueKey('agent-chat-model-routing'),
            keyPrefix: 'agent-settings-model',
            pickerTitle: context.l10n.agentChat_modelPickerTitle,
            searchLabel: context.l10n.agentChat_searchModels,
            searchHint: context.l10n.agentChat_searchModelsHint,
            clearSearchTooltip: context.l10n.agentChat_clearModelSearch,
            emptyMessage: context.l10n.agentChat_noModelResults,
            options: pickerOptions,
            selectedId: selected.isConfigured ? _modelPickerId(selected) : null,
            selectedLabel: selectedOption == null
                ? null
                : '${_providerName(selected.providerId)} / '
                      '${selectedOption.title}'
                      '${isPending ? ' (${context.l10n.agentSettings_pendingMatch})' : ''}',
            emptyLabel: context.l10n.agentSettings_noModel,
            enabled: pickerOptions.isNotEmpty,
            decoration: InputDecoration(
              labelText: context.l10n.agentSettings_providerModel,
              helperText: context.l10n.agentSettings_modelManagedInIntegrations,
            ),
            onSelected: (value) {
              _reportAgentSettingFailure(
                context,
                ref
                    .read(agentSettingsProvider.notifier)
                    .setModelReference(value),
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('agent-settings-open-integrations'),
              onPressed: onOpenIntegrations,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(context.l10n.agentSettings_manageProviders),
            ),
          ),
          if (available.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(context.l10n.agentSettings_noModel),
            ),
          if (selected.isConfigured)
            ContextWindowField(
              providerId: selected.providerId,
              model: selected.model,
              catalogWindow: _catalogWindow(selected),
              overrideWindow: settings.chat.contextWindowOverrideFor(
                selected.providerId,
                selected.model,
              ),
            ),
        ],
      ),
    );
  }

  /// 只取目录推断值供占位显示，不含手填覆盖——否则提示会自我印证。
  int _catalogWindow(AgentModelReference reference) {
    final provider = promptConfig.providers
        .where((item) => item.id == reference.providerId)
        .firstOrNull;
    if (provider == null) return 0;
    return AssistantModelCatalog.resolveProvider(
      provider: provider,
      model: reference.model,
    ).contextWindow;
  }

  String _providerName(String id) =>
      promptConfig.providers
          .where((provider) => provider.id == id)
          .map((provider) => provider.name)
          .firstOrNull ??
      id;

  String _modelPickerId(AgentModelReference reference) =>
      '${reference.providerId}\u0000${reference.model}';
}

class _ReadingPreferencesCard extends ConsumerWidget {
  const _ReadingPreferencesCard({required this.settings});

  final AgentSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = settings.chat;
    return SettingsCard(
      title: context.l10n.agentSettings_readingAppearance,
      icon: Icons.chrome_reader_mode_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.agentSettings_readingTextSize,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.agentSettings_readingTextSizeDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<double>(
              key: const ValueKey('agent-reading-text-scale'),
              segments: [
                for (final scale in AgentChatConfig.supportedReadingTextScales)
                  ButtonSegment(
                    value: scale,
                    label: Text('${(scale * 100).round()}%'),
                  ),
              ],
              selected: {chat.readingTextScale},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _reportAgentSettingFailure(
                context,
                ref
                    .read(agentSettingsProvider.notifier)
                    .setReadingTextScale(selection.single),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.agentSettings_density,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.agentSettings_densityDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<AgentChatDensity>(
              key: const ValueKey('agent-chat-density'),
              segments: [
                ButtonSegment(
                  value: AgentChatDensity.comfortable,
                  label: Text(context.l10n.agentSettings_densityComfortable),
                ),
                ButtonSegment(
                  value: AgentChatDensity.compact,
                  label: Text(context.l10n.agentSettings_densityCompact),
                ),
              ],
              selected: {chat.density},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _reportAgentSettingFailure(
                context,
                ref
                    .read(agentSettingsProvider.notifier)
                    .setChatDensity(selection.single),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard({required this.settings});

  final AgentSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsCard(
      title: context.l10n.agentSettings_toolPermission,
      icon: Icons.admin_panel_settings_outlined,
      child: RadioGroup<AgentPermissionMode>(
        groupValue: settings.chat.permissionMode,
        onChanged: (value) {
          if (value != null) {
            _reportAgentSettingFailure(
              context,
              ref.read(agentSettingsProvider.notifier).setPermissionMode(value),
            );
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              (
                AgentPermissionMode.safe,
                context.l10n.agentSettings_permissionSafe,
                context.l10n.agentSettings_permissionSafeDescription,
              ),
              (
                AgentPermissionMode.askBeforeSensitiveActions,
                context.l10n.agentSettings_permissionAsk,
                context.l10n.agentSettings_permissionAskDescription,
              ),
              (
                AgentPermissionMode.fullAccess,
                context.l10n.agentSettings_permissionFull,
                context.l10n.agentSettings_permissionFullDescription,
              ),
            ];
            if (constraints.maxWidth < 680) {
              return Column(
                children: [for (final card in cards) _permissionTile(card)],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(child: _permissionTile(cards[index])),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _permissionTile((AgentPermissionMode, String, String) card) =>
      RadioListTile<AgentPermissionMode>(
        value: card.$1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(card.$2),
        subtitle: Text(card.$3),
      );
}

class _WebAccessCard extends ConsumerWidget {
  const _WebAccessCard({required this.settings});

  final AgentSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsCard(
    title: context.l10n.agentSettings_webPreference,
    icon: Icons.public,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.chat.webAccessEnabled,
          title: Text(context.l10n.agentSettings_webEnabled),
          subtitle: Text(context.l10n.agentSettings_webDescription),
          onChanged: (value) => _reportAgentSettingFailure(
            context,
            ref.read(agentSettingsProvider.notifier).setWebAccessEnabled(value),
          ),
        ),
        WebAccessSettings(
          showEnableControl: false,
          enabled: settings.chat.webAccessEnabled,
        ),
      ],
    ),
  );
}

Future<void> _reportAgentSettingFailure(
  BuildContext context,
  Future<void> operation,
) async {
  try {
    await operation;
  } catch (error) {
    if (context.mounted) {
      AppToast.error(
        context,
        context.l10n.agentSettings_operationFailed(error.toString()),
      );
    }
  }
}
