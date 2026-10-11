import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../prompt_assistant/models/assistant_model_capability.dart';
import '../../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../../prompt_assistant/providers/provider_remote_models_provider.dart';
import '../../widgets/settings_card.dart';
import 'model_capability_tags.dart';
import 'model_family_group.dart';
import 'provider_model_actions.dart';
import 'provider_model_manage_panel.dart';

class ProviderModelsCard extends ConsumerWidget {
  const ProviderModelsCard({super.key, required this.provider});

  final ProviderConfig provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final count = providerModels(
      ref.watch(promptAssistantConfigProvider),
      provider.id,
    ).length;
    return SettingsCard(
      key: const ValueKey('model-services-models-card'),
      title: l10n.modelServices_models,
      description: l10n.modelServices_modelCount(count),
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ManageModelsButton(provider: provider),
          TextButton.icon(
            key: const ValueKey('model-services-add-model'),
            onPressed: () => showAddModelForm(context, ref, provider),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.modelServices_addModel),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: ProviderModelList(provider: provider),
      ),
    );
  }
}

/// 先拉到列表再打开面板：失败时留在原地报告原因，不打开一个空面板。
class _ManageModelsButton extends ConsumerStatefulWidget {
  const _ManageModelsButton({required this.provider});

  final ProviderConfig provider;

  @override
  ConsumerState<_ManageModelsButton> createState() =>
      _ManageModelsButtonState();
}

class _ManageModelsButtonState extends ConsumerState<_ManageModelsButton> {
  var _loading = false;

  Future<void> _open() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final remote = ref.read(providerRemoteModelsProvider.notifier);
    setState(() => _loading = true);
    try {
      final models = await remote.fetch(widget.provider.id);
      if (!mounted) return;
      if (models.isEmpty) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.promptAssistant_emptyModelList)),
        );
        return;
      }
      setState(() => _loading = false);
      await showProviderModelManagePanel(context, widget.provider);
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.promptAssistant_pullModelsFailed('$error')),
        ),
      );
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      key: const ValueKey('model-services-manage-models'),
      onPressed: _loading ? null : _open,
      icon: _loading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.checklist_rounded),
      label: Text(context.l10n.modelServices_manageModels),
    );
  }
}

/// 模型多时默认折叠分组，避免整页被几百行撑长；搜索时全部展开。
class ProviderModelList extends ConsumerStatefulWidget {
  const ProviderModelList({super.key, required this.provider});

  final ProviderConfig provider;

  static const collapseThreshold = 30;
  static const searchThreshold = 8;

  @override
  ConsumerState<ProviderModelList> createState() => _ProviderModelListState();
}

class _ProviderModelListState extends ConsumerState<ProviderModelList> {
  final _searchController = TextEditingController();
  final _flippedGroups = <String>{};
  var _query = '';

  @override
  void didUpdateWidget(covariant ProviderModelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider.id != widget.provider.id) {
      _flippedGroups.clear();
      _searchController.clear();
      _query = '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = widget.provider;
    final models = providerModels(
      ref.watch(promptAssistantConfigProvider),
      provider.id,
    );
    final remote = ref.watch(providerRemoteModelsProvider)[provider.id];
    if (models.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Text(
          l10n.modelServices_noModels,
          key: const ValueKey('model-services-no-models'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final query = _query.trim().toLowerCase();
    final groups = <String, List<({ModelConfig model, String label})>>{};
    for (final model in models) {
      final label = AssistantModelCatalog.displayLabel(
        provider: provider,
        model: model,
      );
      if (query.isNotEmpty &&
          !label.toLowerCase().contains(query) &&
          !model.name.toLowerCase().contains(query)) {
        continue;
      }
      (groups[modelFamilyGroup(model.name)] ??= []).add((
        model: model,
        label: label,
      ));
    }
    for (final entries in groups.values) {
      entries.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
    }
    final groupNames = groups.keys.toList()..sort();
    final collapsedByDefault =
        models.length > ProviderModelList.collapseThreshold;
    bool expanded(String group) =>
        query.isNotEmpty ||
        collapsedByDefault == _flippedGroups.contains(group);
    final delisted = delistedModelIds(models, remote);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (models.length > ProviderModelList.searchThreshold)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextField(
              key: const ValueKey('model-services-model-search'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.agentChat_searchModels,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.agentChat_clearModelSearch,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
        if (groupNames.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(l10n.agentChat_noModelResults),
          ),
        for (final group in groupNames) ...[
          _ModelGroupHeader(
            group: group,
            count: groups[group]!.length,
            expanded: expanded(group),
            onToggle: query.isNotEmpty
                ? null
                : () => setState(() {
                    if (!_flippedGroups.remove(group)) {
                      _flippedGroups.add(group);
                    }
                  }),
          ),
          if (expanded(group))
            for (final entry in groups[group]!)
              _ProviderModelRow(
                provider: provider,
                model: entry.model,
                label: entry.label,
                notListed: delisted.contains(entry.model.name),
              ),
        ],
      ],
    );
  }
}

class _ModelGroupHeader extends StatelessWidget {
  const _ModelGroupHeader({
    required this.group,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String group;
  final int count;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      button: onToggle != null,
      expanded: expanded,
      child: InkWell(
        key: ValueKey('model-services-group-$group'),
        borderRadius: BorderRadius.circular(6),
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.expand_more_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    group,
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text('$count', style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderModelRow extends ConsumerWidget {
  const _ProviderModelRow({
    required this.provider,
    required this.model,
    required this.label,
    required this.notListed,
  });

  final ProviderConfig provider;
  final ModelConfig model;
  final String label;
  final bool notListed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final id = model.name;
    return ConstrainedBox(
      key: ValueKey('model-services-model-$id'),
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(30, 6, 0, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (label != id)
                    Text(
                      id,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (notListed)
                        _NotListedTag(label: l10n.modelServices_notListed),
                      ModelCapabilityTags(provider: provider, modelId: id),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('model-services-model-edit-$id'),
              tooltip: l10n.modelServices_editModel,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showEditModelForm(context, ref, provider, model),
            ),
            IconButton(
              key: ValueKey('model-services-model-remove-$id'),
              tooltip: l10n.modelServices_removeModel,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: () => confirmRemoveModels(
                context,
                ref,
                provider: provider,
                names: [id],
                label: label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotListedTag extends StatelessWidget {
  const _NotListedTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onErrorContainer),
        ),
      ),
    );
  }
}
