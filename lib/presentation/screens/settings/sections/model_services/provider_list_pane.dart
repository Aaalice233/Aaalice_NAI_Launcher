import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../themes/theme_extension.dart';
import '../../../../widgets/common/provider_icon.dart';
import '../../widgets/settings_card.dart';

/// [selectedId] 为 null 表示单栏模式：点击进入详情页，行尾显示前进箭头。
class ProviderListPane extends StatefulWidget {
  const ProviderListPane({
    super.key,
    required this.providers,
    required this.selectedId,
    required this.onSelected,
    required this.onAdd,
  });

  final List<ProviderConfig> providers;
  final String? selectedId;
  final ValueChanged<ProviderConfig> onSelected;
  final VoidCallback onAdd;

  static const searchThreshold = 6;

  @override
  State<ProviderListPane> createState() => _ProviderListPaneState();
}

class _ProviderListPaneState extends State<ProviderListPane> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.providers
        : widget.providers
              .where(
                (provider) =>
                    provider.name.toLowerCase().contains(query) ||
                    provider.id.toLowerCase().contains(query),
              )
              .toList();

    return SettingsCard(
      key: const ValueKey('model-services-provider-list'),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.providers.length > ProviderListPane.searchThreshold)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  key: const ValueKey('model-services-provider-search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.modelServices_searchProviders,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(l10n.modelServices_noProviderMatches),
              ),
            for (final provider in visible)
              _ProviderListItem(
                provider: provider,
                selected: provider.id == widget.selectedId,
                showChevron: widget.selectedId == null,
                onTap: () => widget.onSelected(provider),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                key: const ValueKey('model-services-add-provider'),
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.promptAssistant_addProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderListItem extends StatelessWidget {
  const _ProviderListItem({
    required this.provider,
    required this.selected,
    required this.showChevron,
    required this.onTap,
  });

  final ProviderConfig provider;
  final bool selected;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('model-services-provider-${provider.id}'),
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.36,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.appTheme.controlRadius),
      ),
      contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      horizontalTitleGap: 12,
      leading: ProviderIcon(provider: provider, size: 24),
      title: Text(provider.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: provider.enabled
          ? null
          : Text(context.l10n.modelServices_disabled),
      trailing: showChevron ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: onTap,
    );
  }
}
