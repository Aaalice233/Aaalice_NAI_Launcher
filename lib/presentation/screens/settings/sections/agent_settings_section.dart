import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/agent/agent_settings.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../agent_settings/providers/agent_settings_provider.dart';
import '../../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../settings/widgets/settings_card.dart';
import '../../settings/widgets/settings_page_layout.dart';
import 'web_access_settings.dart';
import 'agent/agent_profile_actions.dart';
import 'agent/skill_management_panel.dart';
import 'agent/system_prompt_editor.dart';

class AgentSettingsSection extends ConsumerStatefulWidget {
  const AgentSettingsSection({super.key});

  @override
  ConsumerState<AgentSettingsSection> createState() =>
      _AgentSettingsSectionState();
}

class _AgentSettingsSectionState extends ConsumerState<AgentSettingsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

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
    return SettingsPageLayout(
      title: context.l10n.settings_agent,
      description: context.l10n.agentSettings_subtitle,
      actions: const AgentProfileActions(),
      children: [
        _ModelCard(settings: state.settings, promptConfig: promptConfig),
        _PermissionCard(settings: state.settings),
        _WebAccessCard(settings: state.settings),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: context.l10n.agentSettings_systemPrompt),
            Tab(text: context.l10n.agentSettings_skillsTitle),
          ],
        ),
        if (_tabController.index == 0)
          const AgentSystemPromptEditor()
        else
          const SkillManagementPanel(),
      ],
    );
  }
}

class _ModelCard extends ConsumerWidget {
  const _ModelCard({required this.settings, required this.promptConfig});

  final AgentSettings settings;
  final PromptAssistantConfigState promptConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = <AgentModelReference>[];
    for (final provider in promptConfig.providers.where(
      (item) => item.enabled,
    )) {
      for (final model in promptConfig.models.where(
        (item) =>
            item.providerId == provider.id &&
            item.forTask == AssistantTaskType.chat &&
            !item.isPlaceholder,
      )) {
        available.add(
          AgentModelReference(providerId: provider.id, model: model.name),
        );
      }
    }
    final selected = settings.chat.modelReference;
    final isPending = selected.isConfigured && !available.contains(selected);
    return SettingsCard(
      title: context.l10n.agentSettings_chatModel,
      icon: Icons.smart_toy_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<AgentModelReference>(
            key: const ValueKey('agent-chat-model-routing'),
            isExpanded: true,
            initialValue: selected.isConfigured ? selected : null,
            decoration: InputDecoration(
              labelText: context.l10n.agentSettings_providerModel,
              helperText: context.l10n.agentSettings_modelManagedInIntegrations,
            ),
            items: [
              if (isPending)
                DropdownMenuItem(
                  value: selected,
                  child: Text(
                    '${selected.providerId} / ${selected.model} '
                    '(${context.l10n.agentSettings_pendingMatch})',
                  ),
                ),
              for (final reference in available)
                DropdownMenuItem(
                  value: reference,
                  child: Text(
                    '${_providerName(reference.providerId)} / ${reference.model}',
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                _reportAgentSettingFailure(
                  context,
                  ref
                      .read(agentSettingsProvider.notifier)
                      .setModelReference(value),
                );
              }
            },
          ),
          if (available.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(context.l10n.agentSettings_noModel),
            ),
        ],
      ),
    );
  }

  String _providerName(String id) =>
      promptConfig.providers
          .where((provider) => provider.id == id)
          .map((provider) => provider.name)
          .firstOrNull ??
      id;
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
