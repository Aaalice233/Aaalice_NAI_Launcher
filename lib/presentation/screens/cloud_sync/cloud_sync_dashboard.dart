import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_conflict_center.dart';
import 'cloud_sync_ffdkj_prompt.dart';
import 'cloud_sync_preview_panel.dart';
import 'cloud_sync_security_section.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncDashboard extends ConsumerWidget {
  const CloudSyncDashboard({super.key, required this.state});

  final CloudSyncUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.watch(cloudSyncUiPortProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _status(context),
        if (state.capabilityMode ==
            CloudSyncCapabilityMode.manualBackupOnly) ...[
          const SizedBox(height: 12),
          CloudSyncStatusBanner(
            icon: Icons.cloud_upload_outlined,
            title: context.l10n.cloudSync_manualBackupOnly,
            message: context.l10n.cloudSync_manualBackupOnlyDescription,
          ),
        ],
        if (state.backend == CloudSyncBackendKind.github) ...[
          const SizedBox(height: 12),
          CloudSyncStatusBanner(
            icon: Icons.history_outlined,
            title: context.l10n.cloudSync_githubHistoryRetention,
            message: context.l10n.cloudSync_githubHistoryRetentionDescription,
          ),
        ],
        if (state.maintenanceWarning != null) ...[
          const SizedBox(height: 12),
          CloudSyncStatusBanner(
            icon: Icons.cleaning_services_outlined,
            title: context.l10n.cloudSync_maintenanceWarning,
            message: state.maintenanceWarning!,
            warning: true,
          ),
        ],
        for (final warning in state.capabilityWarnings) ...[
          const SizedBox(height: 12),
          CloudSyncStatusBanner(
            icon: Icons.warning_amber_rounded,
            title: context.l10n.cloudSync_maintenanceWarning,
            message: warning,
            warning: true,
          ),
        ],
        const SizedBox(height: 24),
        CloudSyncSection(
          title: context.l10n.cloudSync_connectionDetails,
          child: Wrap(
            children: [
              CloudSyncMetadata(
                label: context.l10n.cloudSync_backend,
                value: _backendName(state.backend),
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_deviceName,
                value: state.deviceName ?? '—',
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_lastSync,
                value: _date(state.lastSync),
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_remoteRevision,
                value: state.remoteRevision ?? '—',
              ),
            ],
          ),
        ),
        _syncActions(context, port),
        if (state.progress != null) _progress(context, state.progress!),
        if (state.pendingFfdkjInstall) const CloudSyncFfdkjPrompt(),
        if (state.pendingPreview != null) CloudSyncPreviewPanel(state: state),
        if (state.conflicts.isNotEmpty)
          CloudSyncConflictCenter(conflicts: state.conflicts),
        _activity(context),
        _history(context, port),
        CloudSyncSecuritySection(state: state),
      ],
    );
  }

  Widget _status(BuildContext context) {
    final needsAction =
        state.needsConflictResolution ||
        state.needsPreviewConfirmation ||
        state.pendingRecoveryKey != null;
    final title = needsAction
        ? state.pendingRecoveryKey != null
              ? context.l10n.cloudSync_newRecoveryKeyPending
              : context.l10n.cloudSync_needsConflictResolution
        : switch (state.activityStatus) {
            CloudSyncActivityStatus.syncing => context.l10n.cloudSync_syncing,
            CloudSyncActivityStatus.paused => context.l10n.cloudSync_paused,
            CloudSyncActivityStatus.idle => context.l10n.cloudSync_upToDate,
          };
    return CloudSyncStatusBanner(
      icon: needsAction
          ? Icons.warning_amber_rounded
          : Icons.cloud_done_outlined,
      title: title,
      message: needsAction
          ? state.needsConflictResolution
                ? context.l10n.cloudSync_deferredConflictWarning
                : state.pendingRecoveryKey != null
                ? context.l10n.cloudSync_newRecoveryKeyMustSave
                : context.l10n.cloudSync_previewAwaitingConfirmation
          : context.l10n.cloudSync_connectedDescription,
      warning: needsAction,
    );
  }

  Widget _syncActions(BuildContext context, CloudSyncUiPort port) =>
      CloudSyncSection(
        title: context.l10n.cloudSync_syncControls,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              style: _buttonStyle,
              onPressed:
                  state.activityStatus == CloudSyncActivityStatus.idle &&
                      !state.needsPreviewConfirmation
                  ? () => _runAction(context, port.syncNow)
                  : null,
              icon: const Icon(Icons.sync),
              label: Text(context.l10n.cloudSync_syncNow),
            ),
            if (state.activityStatus == CloudSyncActivityStatus.syncing)
              FilledButton.tonalIcon(
                style: _buttonStyle,
                onPressed: () => _runAction(context, port.pause),
                icon: const Icon(Icons.pause),
                label: Text(context.l10n.cloudSync_pause),
              ),
            if (state.activityStatus == CloudSyncActivityStatus.paused)
              FilledButton.tonalIcon(
                style: _buttonStyle,
                onPressed: () => _runAction(context, port.resume),
                icon: const Icon(Icons.play_arrow),
                label: Text(context.l10n.cloudSync_resume),
              ),
            if (state.activityStatus != CloudSyncActivityStatus.idle)
              TextButton.icon(
                style: _buttonStyle,
                onPressed: () => _runAction(context, port.cancel),
                icon: const Icon(Icons.close),
                label: Text(context.l10n.cloudSync_cancel),
              ),
          ],
        ),
      );

  Widget _progress(
    BuildContext context,
    CloudSyncProgressView progress,
  ) => CloudSyncSection(
    title: context.l10n.cloudSync_progress,
    child: CloudSyncSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: progress.fraction),
          const SizedBox(height: 12),
          Wrap(
            children: [
              CloudSyncMetadata(
                label: context.l10n.cloudSync_stage,
                value: progress.stage,
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_object,
                value: progress.objectName,
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_objects,
                value:
                    '${progress.completedObjects} / ${progress.totalObjects}',
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_bytes,
                value:
                    '${formatCloudBytes(progress.completedBytes)} / ${formatCloudBytes(progress.totalBytes)}',
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _activity(BuildContext context) => CloudSyncSection(
    title: context.l10n.cloudSync_activityLog,
    child: state.logs.isEmpty
        ? Text(context.l10n.cloudSync_noActivity)
        : CloudSyncSurface(
            child: Column(
              children: [
                for (final entry in state.logs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 48,
                    leading: const Icon(Icons.notes),
                    title: Text(entry.message),
                    subtitle: Text(_date(entry.time)),
                  ),
              ],
            ),
          ),
  );

  Widget _history(
    BuildContext context,
    CloudSyncUiPort port,
  ) => CloudSyncSection(
    title: context.l10n.cloudSync_snapshotHistory,
    subtitle: context.l10n.cloudSync_snapshotHistoryDescription,
    child: !state.supportsHistory || state.snapshots.isEmpty
        ? Text(context.l10n.cloudSync_noSnapshots)
        : Column(
            children: [
              for (final snapshot in state.snapshots)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 56,
                  title: Text(snapshot.summary),
                  subtitle: Text(
                    '${_date(snapshot.createdAt)} · ${snapshot.id}',
                  ),
                  trailing:
                      state.capabilityMode ==
                          CloudSyncCapabilityMode.manualBackupOnly
                      ? null
                      : TextButton(
                          style: _buttonStyle,
                          onPressed:
                              state.isBusy || state.needsPreviewConfirmation
                              ? null
                              : () => _runAction(
                                  context,
                                  () =>
                                      port.previewRestoreSnapshot(snapshot.id),
                                ),
                          child: Text(context.l10n.cloudSync_previewRestore),
                        ),
                ),
            ],
          ),
  );

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

  static ButtonStyle get _buttonStyle =>
      const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 48)));

  String _backendName(CloudSyncBackendKind? backend) => switch (backend) {
    CloudSyncBackendKind.webDav => 'WebDAV',
    CloudSyncBackendKind.github => 'GitHub',
    null => '—',
  };

  String _date(DateTime? value) =>
      value == null ? '—' : value.toLocal().toString().split('.').first;
}
