import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/agent/agent_profile_service.dart';
import 'package:nai_launcher/core/services/file_export_service.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_prompt_draft_provider.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/app_toast.dart';

class AgentProfileActions extends ConsumerStatefulWidget {
  const AgentProfileActions({super.key});

  @override
  ConsumerState<AgentProfileActions> createState() =>
      _AgentProfileActionsState();
}

class _AgentProfileActionsState extends ConsumerState<AgentProfileActions> {
  final _service = const AgentProfileService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: _busy ? null : _import,
        icon: const Icon(Icons.file_download_outlined),
        label: Text(context.l10n.agentSettings_importProfile),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _export,
        icon: const Icon(Icons.file_upload_outlined),
        label: Text(context.l10n.agentSettings_exportProfile),
      ),
    ],
  );

  Future<void> _export() => _run(() async {
    final json = _service.exportProfile(
      ref.read(agentSettingsProvider).settings,
    );
    final result = await FileExportService.saveText(
      text: json,
      fileName: 'aaalice-agent-profile.json',
      dialogTitle: context.l10n.agentSettings_exportProfileTitle,
      mimeType: 'application/json',
      allowedExtensions: const ['json'],
    );
    if (result != null && mounted) {
      AppToast.success(context, context.l10n.agentSettings_profileExported);
    }
  });

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      AppToast.error(context, context.l10n.agentSettings_profileReadFailed);
      return;
    }
    await _run(() async {
      final prompt = ref.read(promptAssistantConfigProvider);
      final skills = ref.read(agentSettingsProvider).skills;
      final preview = _service.previewImport(
        raw: utf8.decode(bytes),
        current: ref.read(agentSettingsProvider).settings,
        availableModelReferences: availableAgentModelReferences(prompt),
        availableSkillIds: {
          for (final skill in skills.effectiveEntries) skill.id,
        },
      );
      if (!mounted) return;
      final confirmed = await AdaptivePresenter.showForm<bool>(
        context: context,
        dialogWidth: 568,
        title: context.l10n.agentSettings_confirmProfileImport,
        builder: (context, scrollController) => LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: ListView(
                  key: const Key('agent-profile-import-review-list'),
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    Text(context.l10n.agentSettings_profilePrivacy),
                    const SizedBox(height: 12),
                    Text(
                      preview.changes.isEmpty
                          ? context.l10n.agentSettings_profileNoChanges
                          : context.l10n.agentSettings_profileChanges(
                              preview.changes
                                  .map(
                                    (change) => _changeLabel(context, change),
                                  )
                                  .join(
                                    context.l10n.agentSettings_listSeparator,
                                  ),
                            ),
                    ),
                    if (preview.warnings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.agentSettings_pendingPreferences,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(context.l10n.agentSettings_profilePending),
                      for (final warning in preview.warnings)
                        Text('• ${_warningLabel(context, warning)}'),
                    ],
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.8,
                ),
                child: SingleChildScrollView(
                  key: const Key('agent-profile-import-actions-scroll'),
                  primary: false,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (context, actionConstraints) {
                          final stackActions =
                              actionConstraints.maxWidth < 360 ||
                              MediaQuery.textScalerOf(context).scale(1) >= 2;
                          final cancel = TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.l10n.common_cancel),
                          );
                          final apply = FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(context.l10n.agentSettings_apply),
                          );
                          if (stackActions) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [apply, cancel],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [cancel, const SizedBox(width: 8), apply],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      await ref
          .read(agentSettingsProvider.notifier)
          .replaceSettings(preview.settings);
      ref
          .read(agentPromptDraftProvider.notifier)
          .synchronizeSaved(
            value: preview.settings.chat.customSystemPrompt,
            mode: preview.settings.chat.systemPromptMode,
          );
      if (mounted) {
        AppToast.success(context, context.l10n.agentSettings_profileImported);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.agentSettings_operationFailed(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _changeLabel(BuildContext context, String value) => switch (value) {
    'chatModel' => context.l10n.agentSettings_chatModel,
    'permissionMode' => context.l10n.agentSettings_toolPermission,
    'webAccess' => context.l10n.agentSettings_webPreference,
    'customSystemPrompt' => context.l10n.agentSettings_systemPrompt,
    'systemPromptMode' => context.l10n.agentSettings_systemPrompt,
    'migratedChatRules' => context.l10n.agentSettings_systemPrompt,
    'skillPreferences' => context.l10n.agentSettings_skillsTitle,
    _ => value,
  };

  String _warningLabel(BuildContext context, String value) {
    const modelPrefix = 'unmatchedModel:';
    const skillPrefix = 'unmatchedSkill:';
    if (value.startsWith(modelPrefix)) {
      return context.l10n.agentSettings_missingModel(
        value.substring(modelPrefix.length),
      );
    }
    if (value.startsWith(skillPrefix)) {
      return context.l10n.agentSettings_missingSkill(
        value.substring(skillPrefix.length),
      );
    }
    return value;
  }
}

@visibleForTesting
Set<String> availableAgentModelReferences(PromptAssistantConfigState config) {
  final enabledProviderIds = {
    for (final provider in config.providers)
      if (provider.enabled) provider.id,
  };
  return {
    for (final model in config.models)
      if (enabledProviderIds.contains(model.providerId) &&
          model.forTask == AssistantTaskType.chat &&
          !model.isPlaceholder)
        '${model.providerId}/${model.name}',
  };
}
