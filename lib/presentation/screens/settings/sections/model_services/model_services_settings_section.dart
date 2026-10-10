import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../widgets/settings_card.dart';
import 'provider_detail_pane.dart';
import 'provider_editing.dart';
import 'provider_list_pane.dart';

/// 宽度够时左列表右详情；不够时列表点进独立详情页，避免在设置页里再叠一层返回逻辑。
class ModelServicesSettingsSection extends ConsumerStatefulWidget {
  const ModelServicesSettingsSection({super.key});

  static const splitMinWidth = 640.0;

  @override
  ConsumerState<ModelServicesSettingsSection> createState() =>
      _ModelServicesSettingsSectionState();
}

class _ModelServicesSettingsSectionState
    extends ConsumerState<ModelServicesSettingsSection> {
  String? _selectedId;

  Future<void> _addProvider({required bool split}) async {
    final id = await showProviderEditor(context, ref);
    if (id == null || !mounted) return;
    if (split) {
      setState(() => _selectedId = id);
      return;
    }
    final provider = ref
        .read(promptAssistantConfigProvider)
        .providers
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (provider != null) _openDetailPage(provider);
  }

  void _openDetailPage(ProviderConfig provider) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderDetailPage(providerId: provider.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(
      promptAssistantConfigProvider.select((state) => state.providers),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final split =
            constraints.maxWidth >= ModelServicesSettingsSection.splitMinWidth;
        if (providers.isEmpty) {
          return _EmptyProviders(onAdd: () => _addProvider(split: split));
        }
        if (!split) {
          return ProviderListPane(
            providers: providers,
            selectedId: null,
            onSelected: _openDetailPage,
            onAdd: () => _addProvider(split: false),
          );
        }
        final selected =
            providers.where((p) => p.id == _selectedId).firstOrNull ??
            providers.first;
        final listWidth = (constraints.maxWidth * 0.3).clamp(200.0, 280.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: listWidth,
              child: ProviderListPane(
                providers: providers,
                selectedId: selected.id,
                onSelected: (provider) =>
                    setState(() => _selectedId = provider.id),
                onAdd: () => _addProvider(split: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: ProviderDetailPane(provider: selected)),
          ],
        );
      },
    );
  }
}

class ProviderDetailPage extends ConsumerWidget {
  const ProviderDetailPage({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(
      promptAssistantConfigProvider.select(
        (state) => state.providers
            .where((candidate) => candidate.id == providerId)
            .firstOrNull,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_modelServices)),
      body: SafeArea(
        top: false,
        child: provider == null
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: ProviderDetailPane(
                  provider: provider,
                  onDeleted: () => Navigator.of(context).maybePop(),
                ),
              ),
      ),
    );
  }
}

class _EmptyProviders extends StatelessWidget {
  const _EmptyProviders({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SettingsCard(
      key: const ValueKey('model-services-empty'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.hub_outlined,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.modelServices_emptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.modelServices_emptyBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('model-services-add-provider'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.promptAssistant_addProvider),
            ),
          ],
        ),
      ),
    );
  }
}
