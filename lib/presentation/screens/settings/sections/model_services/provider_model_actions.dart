import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/agent/agent_settings.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../agent_settings/providers/agent_settings_provider.dart';
import '../../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/assistant_task_labels.dart';
import 'provider_model_form.dart';

/// 存储里每个模型按任务各有一份，界面以模型 ID 为单位，取第一份代表它。
List<ModelConfig> providerModels(
  PromptAssistantConfigState state,
  String providerId,
) {
  final seen = <String>{};
  return [
    for (final model in state.models)
      if (model.providerId == providerId &&
          !model.isPlaceholder &&
          seen.add(model.name))
        model,
  ];
}

/// 只有从接口列表加入的模型才算失效：中转站常有不在 /models 里却能用的模型，手动添加的不动。
Set<String> delistedModelIds(
  Iterable<ModelConfig> models,
  Iterable<String>? remote,
) {
  if (remote == null) return const {};
  final listed = remote.toSet();
  return {
    for (final model in models)
      if (model.source == ModelSource.api && !listed.contains(model.name))
        model.name,
  };
}

// 一次加入几十上百个模型多半是误点，超过这个数先确认。
const _addAllConfirmThreshold = 20;

Future<void> addAllModels(
  BuildContext context,
  WidgetRef ref, {
  required ProviderConfig provider,
  required List<String> names,
}) async {
  if (names.isEmpty) return;
  if (names.length > _addAllConfirmThreshold) {
    final l10n = context.l10n;
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: l10n.modelServices_addAllModels,
      content: l10n.modelServices_addAllConfirm(names.length),
      confirmText: l10n.modelServices_addAllModels,
    );
    if (!confirmed) return;
  }
  await ref
      .read(promptAssistantConfigProvider.notifier)
      .addProviderModels(provider.id, names, source: ModelSource.api);
}

/// 少量时直接列出模型 ID，方便确认删的是哪些。
Future<bool> cleanDelistedModels(
  BuildContext context,
  WidgetRef ref, {
  required ProviderConfig provider,
  required List<String> names,
}) {
  final l10n = context.l10n;
  return confirmRemoveModels(
    context,
    ref,
    provider: provider,
    names: names,
    label: names.length <= 3
        ? names.join(l10n.modelServices_usageSeparator)
        : l10n.modelServices_staleModelCount(names.length),
  );
}

Future<void> showAddModelForm(
  BuildContext context,
  WidgetRef ref,
  ProviderConfig provider,
) async {
  final existing = {
    for (final model in providerModels(
      ref.read(promptAssistantConfigProvider),
      provider.id,
    ))
      model.name,
  };
  final result = await AdaptivePresenter.showForm<ProviderModelFormResult>(
    context: context,
    dialogWidth: 480,
    title: context.l10n.modelServices_addModel,
    builder: (context, scrollController) => ProviderModelForm(
      provider: provider,
      existingIds: existing,
      scrollController: scrollController,
    ),
  );
  if (result == null) return;
  final notifier = ref.read(promptAssistantConfigProvider.notifier);
  await notifier.addProviderModels(provider.id, [
    result.id,
  ], source: ModelSource.manual);
  if (result.displayName.isNotEmpty) {
    await notifier.renameProviderModel(
      provider.id,
      result.id,
      result.displayName,
    );
  }
}

Future<void> showEditModelForm(
  BuildContext context,
  WidgetRef ref,
  ProviderConfig provider,
  ModelConfig model,
) async {
  final result = await AdaptivePresenter.showForm<ProviderModelFormResult>(
    context: context,
    dialogWidth: 480,
    title: context.l10n.modelServices_editModel,
    builder: (context, scrollController) => ProviderModelForm(
      provider: provider,
      existingIds: const {},
      model: model,
      scrollController: scrollController,
    ),
  );
  if (result == null) return;
  await ref
      .read(promptAssistantConfigProvider.notifier)
      .renameProviderModel(provider.id, model.name, result.displayName);
}

/// 被任务路由或智能体引用时先说明后果再确认；返回是否已移除。
Future<bool> confirmRemoveModels(
  BuildContext context,
  WidgetRef ref, {
  required ProviderConfig provider,
  required List<String> names,
  required String label,
}) async {
  final l10n = context.l10n;
  final usages = modelUsages(
    l10n,
    config: ref.read(promptAssistantConfigProvider),
    agentModel: ref.read(agentSettingsProvider).settings.chat.modelReference,
    providerId: provider.id,
    names: names.toSet(),
  );
  final confirmed = await ThemedConfirmDialog.show(
    context: context,
    title: l10n.modelServices_removeModel,
    content: usages.isEmpty
        ? l10n.modelServices_removeModelConfirm(label)
        : l10n.modelServices_removeModelInUse(
            label,
            usages.join(l10n.modelServices_usageSeparator),
          ),
    confirmText: l10n.modelServices_removeModel,
    type: ThemedConfirmDialogType.danger,
  );
  if (!confirmed) return false;
  await ref
      .read(promptAssistantConfigProvider.notifier)
      .removeProviderModels(provider.id, names);
  return true;
}

List<String> modelUsages(
  AppLocalizations l10n, {
  required PromptAssistantConfigState config,
  required AgentModelReference agentModel,
  required String providerId,
  required Set<String> names,
}) => [
  for (final task in AssistantTaskType.values)
    if (task != AssistantTaskType.chat &&
        config.routing.providerIdFor(task) == providerId &&
        names.contains(config.routing.modelFor(task)))
      task.localizedLabel(l10n),
  if (agentModel.providerId == providerId && names.contains(agentModel.model))
    l10n.settings_agent,
];
