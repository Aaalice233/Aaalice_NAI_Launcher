import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncSecuritySection extends ConsumerWidget {
  const CloudSyncSecuritySection({super.key, required this.state});

  final CloudSyncUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.watch(cloudSyncUiPortProvider);
    return CloudSyncSection(
      title: context.l10n.cloudSync_connectionManagement,
      child: Column(
        children: [
          if (state.supportsDelete)
            ListTile(
              key: const ValueKey('cloud-sync-rebuild-compact-backup'),
              contentPadding: EdgeInsets.zero,
              minTileHeight: 56,
              title: Text(context.l10n.cloudSync_rebuildCompactBackup),
              subtitle: Text(
                context.l10n.cloudSync_rebuildCompactBackupDescription,
              ),
              trailing: const Icon(Icons.recycling_outlined),
              enabled: !state.isBusy && !state.needsPreviewConfirmation,
              onTap: state.isBusy || state.needsPreviewConfirmation
                  ? null
                  : () => _confirmAction(
                      context,
                      context.l10n.cloudSync_rebuildCompactBackup,
                      context.l10n.cloudSync_rebuildCompactBackupConfirm,
                      port.rebuildCompactBackup,
                      destructive: true,
                    ),
            ),
          if (state.supportsDelete)
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 56,
              title: Text(context.l10n.cloudSync_deleteRemoteNamespace),
              subtitle: Text(
                context.l10n.cloudSync_deleteRemoteNamespaceDescription,
              ),
              textColor: Theme.of(context).colorScheme.error,
              iconColor: Theme.of(context).colorScheme.error,
              trailing: const Icon(Icons.delete_outline),
              enabled: !state.isBusy,
              onTap: state.isBusy
                  ? null
                  : () => _confirmAction(
                      context,
                      context.l10n.cloudSync_deleteRemoteNamespace,
                      context.l10n.cloudSync_deleteRemoteConfirm,
                      port.deleteRemoteNamespace,
                      destructive: true,
                    ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            title: Text(context.l10n.cloudSync_disconnect),
            subtitle: Text(context.l10n.cloudSync_disconnectDescription),
            trailing: const Icon(Icons.link_off),
            enabled: !state.isBusy,
            onTap: state.isBusy
                ? null
                : () => _confirmAction(
                    context,
                    context.l10n.cloudSync_disconnect,
                    context.l10n.cloudSync_disconnectConfirm,
                    port.disconnect,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAction(
    BuildContext context,
    String title,
    String message,
    Future<void> Function() action, {
    bool destructive = false,
  }) async {
    final confirmed = await AdaptivePresenter.showForm<bool>(
      context: context,
      title: title,
      dialogWidth: 520,
      builder: (dialogContext, scrollController) => ListView(
        controller: scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text(message),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cloudSync_cancel),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      )
                    : null,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.cloudSync_confirm),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await action();
    } catch (_) {
      if (!context.mounted) return;
      final message = ProviderScope.containerOf(
        context,
      ).read(cloudSyncUiStateProvider).error;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }
}
