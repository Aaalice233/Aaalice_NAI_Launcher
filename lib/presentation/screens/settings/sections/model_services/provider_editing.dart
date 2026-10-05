import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../../prompt_assistant/providers/provider_remote_models_provider.dart';
import '../../../../widgets/common/themed_confirm_dialog.dart';
import '../../widgets/prompt_assistant_settings_forms.dart';

/// 新建或编辑服务商，返回保存后的服务商 ID；取消时为 null。
Future<String?> showProviderEditor(
  BuildContext context,
  WidgetRef ref, {
  ProviderConfig? provider,
}) async {
  final result =
      await AdaptivePresenter.showForm<PromptAssistantProviderFormResult>(
        context: context,
        dialogWidth: 520,
        title: provider == null
            ? context.l10n.promptAssistant_addProvider
            : context.l10n.promptAssistant_editProviderTitle,
        builder: (context, scrollController) => PromptAssistantProviderForm(
          provider: provider,
          scrollController: scrollController,
        ),
      );
  if (result == null) return null;

  final notifier = ref.read(promptAssistantConfigProvider.notifier);
  final state = ref.read(promptAssistantConfigProvider);
  final name = result.name.isEmpty ? result.preset.defaultName : result.name;
  final id =
      provider?.id ??
      _uniqueProviderId(
        state,
        _providerIdFromName(name, fallback: result.preset.defaultId),
      );
  final next = ProviderConfig(
    id: id,
    name: name,
    type: result.preset.legacyType,
    protocol: result.preset.defaultProtocol,
    preset: result.preset,
    baseUrl: result.baseUrl,
    enabled: provider?.enabled ?? true,
    allowImageInput: result.allowImageInput,
    concurrency: result.concurrency,
  );

  await notifier.upsertProvider(next);
  if (result.apiKey.trim().isNotEmpty) {
    await notifier.setProviderApiKey(id, result.apiKey);
  }
  if (provider == null) {
    await notifier.addProviderModels(
      id,
      result.preset.defaultModelNames,
      source: ModelSource.manual,
    );
  } else if (provider.baseUrl != next.baseUrl) {
    ref.read(providerRemoteModelsProvider.notifier).forget(id);
  }
  return id;
}

Future<bool> confirmDeleteProvider(
  BuildContext context,
  WidgetRef ref,
  ProviderConfig provider,
) async {
  final confirmed = await ThemedConfirmDialog.showDelete(
    context: context,
    itemName: provider.name,
  );
  if (!confirmed) return false;
  await ref
      .read(promptAssistantConfigProvider.notifier)
      .deleteProvider(provider.id);
  ref.read(providerRemoteModelsProvider.notifier).forget(provider.id);
  return true;
}

String _uniqueProviderId(PromptAssistantConfigState state, String baseId) {
  bool taken(String id) => state.providers.any((provider) => provider.id == id);
  if (!taken(baseId)) return baseId;
  var index = 2;
  while (taken('${baseId}_$index')) {
    index++;
  }
  return '${baseId}_$index';
}

String _providerIdFromName(String name, {required String fallback}) {
  final normalized = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return normalized.isEmpty ? fallback : normalized;
}
