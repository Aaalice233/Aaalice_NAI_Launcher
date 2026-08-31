import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncEncryptionSection extends ConsumerStatefulWidget {
  const CloudSyncEncryptionSection({super.key, required this.state});

  final CloudSyncUiState state;

  @override
  ConsumerState<CloudSyncEncryptionSection> createState() =>
      _CloudSyncEncryptionSectionState();
}

class _CloudSyncEncryptionSectionState
    extends ConsumerState<CloudSyncEncryptionSection> {
  final _recovery = TextEditingController();
  var _saved = false;
  var _busy = false;

  @override
  void dispose() {
    _recovery.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) showCloudSyncActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.recoveryRequired) return _recoveryForm(context);
    final recoveryKey = widget.state.pendingRecoveryKey;
    if (recoveryKey == null) return const SizedBox.shrink();
    return CloudSyncSection(
      title: context.l10n.cloudSync_encryptionRecoveryTitle,
      subtitle: context.l10n.cloudSync_encryptionRecoveryDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CloudSyncSurface(
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    recoveryKey,
                    key: const ValueKey('cloud-sync-recovery-key'),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.cloudSync_copyRecoveryKey,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: recoveryKey));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.cloudSync_recoveryKeyCopied),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
          ),
          CheckboxListTile(
            key: const ValueKey('cloud-sync-recovery-saved'),
            contentPadding: EdgeInsets.zero,
            value: _saved,
            onChanged: _busy
                ? null
                : (value) => setState(() => _saved = value ?? false),
            title: Text(context.l10n.cloudSync_recoveryKeySaved),
            subtitle: Text(context.l10n.cloudSync_recoveryKeyOneTimeWarning),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('cloud-sync-confirm-recovery-key'),
              onPressed: !_saved || _busy
                  ? null
                  : () => _run(
                      ref
                          .read(cloudSyncUiPortProvider)
                          .confirmCloudDriveRecoveryKeySaved,
                    ),
              icon: const Icon(Icons.check),
              label: Text(context.l10n.cloudSync_confirm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recoveryForm(BuildContext context) => CloudSyncSection(
    title: context.l10n.cloudSync_recoveryRequiredTitle,
    subtitle: context.l10n.cloudSync_recoveryRequiredDescription,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CloudSyncField(
          controller: _recovery,
          label: context.l10n.cloudSync_recoveryKey,
          obscureText: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('cloud-sync-unlock-recovery-key'),
            onPressed: _busy || _recovery.text.trim().isEmpty
                ? null
                : () => _run(
                    () => ref
                        .read(cloudSyncUiPortProvider)
                        .recoverCloudDriveEncryption(_recovery.text),
                  ),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open_outlined),
            label: Text(context.l10n.cloudSync_unlock),
          ),
        ),
      ],
    ),
  );
}
