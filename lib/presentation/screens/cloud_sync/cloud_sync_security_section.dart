import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncSecuritySection extends ConsumerWidget {
  const CloudSyncSecuritySection({super.key, required this.state});

  final CloudSyncUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.watch(cloudSyncUiPortProvider);
    return CloudSyncSection(
      title: context.l10n.cloudSync_securityAndConnection,
      child: Column(
        children: [
          if (state.pendingRecoveryKey != null) ...[
            CloudSyncSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.cloudSync_newRecoveryKeyPending,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(state.pendingRecoveryKey!),
                  const SizedBox(height: 8),
                  Text(context.l10n.cloudSync_newRecoveryKeyMustSave),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: state.isBusy
                          ? null
                          : () => _confirmRecoveryKeySaved(context, port),
                      child: Text(
                        context.l10n.cloudSync_recoveryKeySavedAction,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            title: Text(context.l10n.cloudSync_changePassword),
            subtitle: Text(context.l10n.cloudSync_rewrapExplanation),
            trailing: const Icon(Icons.chevron_right),
            enabled: !state.isBusy && state.pendingRecoveryKey == null,
            onTap: state.isBusy || state.pendingRecoveryKey != null
                ? null
                : () => _changePassword(context, port),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            title: Text(context.l10n.cloudSync_rotateRecoveryKey),
            subtitle: Text(context.l10n.cloudSync_rotateRecoveryKeyDescription),
            trailing: const Icon(Icons.key_outlined),
            enabled: !state.isBusy && state.pendingRecoveryKey == null,
            onTap: state.isBusy || state.pendingRecoveryKey != null
                ? null
                : () => _rotateRecoveryKey(context, port),
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
              enabled: !state.isBusy && state.pendingRecoveryKey == null,
              onTap: state.isBusy || state.pendingRecoveryKey != null
                  ? null
                  : () => _confirmAction(
                      context,
                      context.l10n.cloudSync_deleteRemoteNamespace,
                      context.l10n.cloudSync_deleteRemoteConfirm,
                      port.deleteRemoteNamespace,
                    ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            title: Text(context.l10n.cloudSync_disconnect),
            subtitle: Text(context.l10n.cloudSync_disconnectDescription),
            trailing: const Icon(Icons.link_off),
            enabled: !state.isBusy && state.pendingRecoveryKey == null,
            onTap: state.isBusy || state.pendingRecoveryKey != null
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

  Future<void> _rotateRecoveryKey(
    BuildContext context,
    CloudSyncUiPort port,
  ) async {
    await _runAction(context, port.rotateRecoveryKey);
    if (!context.mounted) return;
    final key = ProviderScope.containerOf(
      context,
    ).read(cloudSyncUiStateProvider).pendingRecoveryKey;
    if (key == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.cloudSync_newRecoveryKeyPending),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(key),
            const SizedBox(height: 12),
            Text(context.l10n.cloudSync_newRecoveryKeyMustSave),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cloudSync_saveLater),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.cloudSync_recoveryKeySavedAction),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      await _runAction(context, port.confirmRecoveryKeySaved);
    }
  }

  Future<void> _confirmRecoveryKeySaved(
    BuildContext context,
    CloudSyncUiPort port,
  ) => _confirmAction(
    context,
    context.l10n.cloudSync_newRecoveryKeyPending,
    context.l10n.cloudSync_recoveryKeySavedConfirm,
    port.confirmRecoveryKeySaved,
  );

  Future<void> _changePassword(
    BuildContext context,
    CloudSyncUiPort port,
  ) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.cloudSync_changePassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.cloudSync_rewrapExplanation),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.cloudSync_newPassword,
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cloudSync_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.l10n.cloudSync_changePassword),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted) return;
    if (password != null && password.isNotEmpty) {
      await _runAction(context, () => port.changePassword(password));
    }
  }

  Future<void> _confirmAction(
    BuildContext context,
    String title,
    String message,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cloudSync_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.cloudSync_confirm),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed == true) await _runAction(context, action);
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cloudSync_actionFailed('$error'))),
      );
    }
  }
}
