import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../prompt_assistant/models/assistant_model_capability.dart';
import '../../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../../prompt_assistant/providers/provider_remote_models_provider.dart';
import '../../../../widgets/common/searchable_model_picker.dart';
import 'model_family_group.dart';
import 'provider_model_actions.dart';

/// 列出接口返回的全部模型，点一行即加入或移出该服务商；面板保持打开便于连续挑选。
Future<void> showProviderModelManagePanel(
  BuildContext context,
  ProviderConfig provider,
) => AdaptivePresenter.showPicker<void>(
  context: context,
  width: 620,
  restoreFocus: false,
  builder: (context, scrollController) => ProviderModelManagePanel(
    providerId: provider.id,
    scrollController: scrollController,
  ),
);

typedef _RemoteEntry = ({String id, String group, String title});

class ProviderModelManagePanel extends ConsumerWidget {
  const ProviderModelManagePanel({
    super.key,
    required this.providerId,
    required this.scrollController,
  });

  final String providerId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(promptAssistantConfigProvider);
    final provider = config.providers
        .where((candidate) => candidate.id == providerId)
        .firstOrNull;
    if (provider == null) return const SizedBox.shrink();
    final remote = ref.watch(providerRemoteModelsProvider)[providerId] ?? [];
    final models = providerModels(config, providerId);
    final added = {for (final model in models) model.name};
    final entries = _entries(provider, remote);
    final missing = [
      for (final entry in entries)
        if (!added.contains(entry.id)) entry.id,
    ];
    final delisted = delistedModelIds(models, remote).toList()..sort();

    return SearchableModelPickerBody<String>(
      title: l10n.modelServices_manageModelsTitle(provider.name),
      titleBadge: '${remote.length}',
      headerActions: [
        TextButton.icon(
          key: const ValueKey('model-services-manage-clean'),
          onPressed: delisted.isEmpty
              ? null
              : () => cleanDelistedModels(
                  context,
                  ref,
                  provider: provider,
                  names: delisted,
                ),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: Text(l10n.modelServices_cleanStaleModels),
        ),
        TextButton.icon(
          key: const ValueKey('model-services-manage-add-all'),
          onPressed: missing.isEmpty
              ? null
              : () => addAllModels(
                  context,
                  ref,
                  provider: provider,
                  names: missing,
                ),
          icon: const Icon(Icons.playlist_add_rounded),
          label: Text(l10n.modelServices_addAllModels),
        ),
      ],
      searchLabel: l10n.agentChat_searchModels,
      searchHint: l10n.agentChat_searchModelsHint,
      clearSearchTooltip: l10n.agentChat_clearModelSearch,
      emptyMessage: l10n.agentChat_noModelResults,
      options: _options(context, ref, provider, entries, added),
      selectedId: null,
      selectedIds: added,
      scrollController: scrollController,
      keyPrefix: 'model-services-manage',
      onSelected: (option) =>
          _toggle(context, ref, provider, added, option.value, option.title),
    );
  }

  List<_RemoteEntry> _entries(ProviderConfig provider, List<String> remote) =>
      [
        for (final id in remote)
          (
            id: id,
            group: modelFamilyGroup(id),
            title:
                AssistantModelCatalog.catalogDisplayName(
                  provider: provider,
                  model: id,
                ) ??
                id,
          ),
      ]..sort((a, b) {
        final byGroup = a.group.compareTo(b.group);
        return byGroup != 0
            ? byGroup
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

  List<ModelPickerOption<String>> _options(
    BuildContext context,
    WidgetRef ref,
    ProviderConfig provider,
    List<_RemoteEntry> entries,
    Set<String> added,
  ) {
    final colors = Theme.of(context).colorScheme;
    final idsByGroup = <String, List<String>>{};
    for (final entry in entries) {
      (idsByGroup[entry.group] ??= []).add(entry.id);
    }
    final groups = {
      for (final group in idsByGroup.keys)
        group: ModelPickerGroup(
          id: group,
          label: group,
          trailing: _groupAction(
            context,
            ref,
            provider,
            group,
            idsByGroup[group]!,
            added,
          ),
        ),
    };
    return [
      for (final entry in entries)
        ModelPickerOption<String>(
          id: entry.id,
          value: entry.id,
          title: entry.title,
          subtitle: entry.title == entry.id ? null : entry.id,
          modelId: entry.id,
          searchTerms: [entry.id],
          group: groups[entry.group],
          trailing: Icon(
            added.contains(entry.id)
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            size: 20,
            color: added.contains(entry.id)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
    ];
  }

  Widget _groupAction(
    BuildContext context,
    WidgetRef ref,
    ProviderConfig provider,
    String group,
    List<String> ids,
    Set<String> added,
  ) {
    final l10n = context.l10n;
    final missing = ids.where((id) => !added.contains(id)).toList();
    if (missing.isEmpty) {
      return IconButton(
        key: ValueKey('model-services-manage-group-remove-$group'),
        tooltip: l10n.modelServices_removeGroup(group),
        icon: const Icon(Icons.playlist_remove_rounded),
        onPressed: () => confirmRemoveModels(
          context,
          ref,
          provider: provider,
          names: ids,
          label: group,
        ),
      );
    }
    return IconButton(
      key: ValueKey('model-services-manage-group-add-$group'),
      tooltip: l10n.modelServices_addGroup(group),
      icon: const Icon(Icons.playlist_add_rounded),
      onPressed: () => ref
          .read(promptAssistantConfigProvider.notifier)
          .addProviderModels(provider.id, missing, source: ModelSource.api),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    ProviderConfig provider,
    Set<String> added,
    String id,
    String label,
  ) async {
    if (added.contains(id)) {
      await confirmRemoveModels(
        context,
        ref,
        provider: provider,
        names: [id],
        label: label,
      );
      return;
    }
    await ref.read(promptAssistantConfigProvider.notifier).addProviderModels(
      provider.id,
      [id],
      source: ModelSource.api,
    );
  }
}
