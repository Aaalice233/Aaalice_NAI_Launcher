import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../../widgets/common/heading_semantics.dart';
import '../../../../widgets/common/provider_icon.dart';
import 'provider_connection_card.dart';
import 'provider_editing.dart';
import 'provider_models_card.dart';

class ProviderDetailPane extends StatelessWidget {
  const ProviderDetailPane({super.key, required this.provider, this.onDeleted});

  final ProviderConfig provider;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('model-services-detail-${provider.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProviderDetailHeader(provider: provider, onDeleted: onDeleted),
        const SizedBox(height: 12),
        ProviderConnectionCard(provider: provider),
        const SizedBox(height: 16),
        ProviderModelsCard(provider: provider),
      ],
    );
  }
}

enum _ProviderMenuAction { edit, delete }

class _ProviderDetailHeader extends ConsumerWidget {
  const _ProviderDetailHeader({required this.provider, this.onDeleted});

  final ProviderConfig provider;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      children: [
        const SizedBox(width: 4),
        ProviderIcon(provider: provider, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: HeadingSemantics(
            level: 3,
            child: Text(
              provider.name,
              key: const ValueKey('model-services-detail-title'),
              style: theme.textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Semantics(
          label: l10n.modelServices_enableProvider,
          child: Switch(
            key: const ValueKey('model-services-provider-enabled'),
            value: provider.enabled,
            onChanged: (value) => ref
                .read(promptAssistantConfigProvider.notifier)
                .upsertProvider(provider.copyWith(enabled: value)),
          ),
        ),
        PopupMenuButton<_ProviderMenuAction>(
          key: const ValueKey('model-services-provider-menu'),
          tooltip: l10n.modelServices_moreActions,
          onSelected: (action) async {
            switch (action) {
              case _ProviderMenuAction.edit:
                await showProviderEditor(context, ref, provider: provider);
              case _ProviderMenuAction.delete:
                final deleted = await confirmDeleteProvider(
                  context,
                  ref,
                  provider,
                );
                if (deleted) onDeleted?.call();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ProviderMenuAction.edit,
              child: ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.promptAssistant_editProvider),
              ),
            ),
            PopupMenuItem(
              value: _ProviderMenuAction.delete,
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  l10n.promptAssistant_deleteProvider,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
