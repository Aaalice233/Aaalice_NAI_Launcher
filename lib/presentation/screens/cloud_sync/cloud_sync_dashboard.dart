import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud_sync/backend/cloud_sync_backend.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../data/cloud_sync/cloud_sync_content_selection_store.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_content_selection_dialog.dart';
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
        for (final warning in state.capabilityWarnings) ...[
          const SizedBox(height: 12),
          CloudSyncStatusBanner(
            icon: Icons.privacy_tip_outlined,
            title: context.l10n.cloudSync_providerWarning,
            message: _warningMessage(context, warning),
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
              if (state.accountLabel != null)
                CloudSyncMetadata(
                  label: context.l10n.cloudSync_connectedAccount,
                  value: state.accountLabel!,
                ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_deviceName,
                value: state.deviceName ?? '—',
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_lastSync,
                value: _date(state.lastSync),
              ),
            ],
          ),
        ),
        CloudSyncSection(
          title: context.l10n.cloudSync_dataScope,
          subtitle: context.l10n.cloudSync_dataScopeDescription,
          child: ListTile(
            key: const ValueKey('cloud-sync-content-selection-entry'),
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            title: Text(context.l10n.cloudSync_chooseBackupContents),
            subtitle: Text(
              context.l10n.cloudSync_selectedContentSummary(
                state.contentSelection.selectedItemCount,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: !state.isBusy && !state.needsPreviewConfirmation,
            onTap: state.isBusy || state.needsPreviewConfirmation
                ? null
                : () => _editContentSelection(context, ref, port),
          ),
        ),
        _syncActions(context, port),
        if (state.progress != null) _progress(context, state.progress!),
        if (state.metrics != null) _metrics(context, state.metrics!),
        if (state.pendingFfdkjInstall) const CloudSyncFfdkjPrompt(),
        if (state.pendingPreview != null) CloudSyncPreviewPanel(state: state),
        if (state.conflicts.isNotEmpty)
          CloudSyncConflictCenter(conflicts: state.conflicts),
        if (state.supportsHistory) _history(context, port),
        CloudSyncSecuritySection(state: state),
      ],
    );
  }

  String _warningMessage(BuildContext context, CloudBackendWarning warning) =>
      switch (warning) {
        CloudBackendWarning.googleDriveWeakCas =>
          context.l10n.cloudSync_warningGoogleDriveWeakCas,
        CloudBackendWarning.githubPublicRepository =>
          context.l10n.cloudSync_warningGithubPublicRepository,
        CloudBackendWarning.webDavWeakCas =>
          context.l10n.cloudSync_warningWebDavWeakCas,
        CloudBackendWarning.webDavUnverifiedCas =>
          context.l10n.cloudSync_warningWebDavUnverifiedCas,
      };

  Widget _status(BuildContext context) {
    final needsAction =
        state.needsConflictResolution || state.needsPreviewConfirmation;
    final title = needsAction
        ? context.l10n.cloudSync_needsConflictResolution
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
                  ? () => _confirmDirection(
                      context,
                      title: context.l10n.cloudSync_pushConfirmTitle,
                      message: context.l10n.cloudSync_pushConfirmDescription,
                      action: port.pushNow,
                    )
                  : null,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(context.l10n.cloudSync_pushLocal),
            ),
            FilledButton.tonalIcon(
              style: _buttonStyle,
              onPressed:
                  state.activityStatus == CloudSyncActivityStatus.idle &&
                      !state.needsPreviewConfirmation &&
                      state.remoteExists == true
                  ? () => _confirmDirection(
                      context,
                      title: context.l10n.cloudSync_pullConfirmTitle,
                      message: context.l10n.cloudSync_pullConfirmDescription,
                      action: port.pullNow,
                    )
                  : null,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(context.l10n.cloudSync_pullRemote),
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

  Future<void> _confirmDirection(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
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
    if (confirmed == true && context.mounted) {
      await _runAction(context, action);
    }
  }

  Future<void> _editContentSelection(
    BuildContext context,
    WidgetRef ref,
    CloudSyncUiPort port,
  ) async {
    final selection = await showCloudSyncContentSelectionDialog(
      context: context,
      initialSelection: state.contentSelection,
      skills: ref.read(agentSettingsProvider).skills,
    );
    if (selection == null || !context.mounted) return;
    await _runAction(context, () async {
      await port.updateContentSelection(selection);
      await CloudSyncContentSelectionStore(
        ref.read(localStorageServiceProvider),
      ).save(selection);
    });
  }

  Widget _progress(
    BuildContext context,
    CloudSyncProgressView progress,
  ) => CloudSyncSection(
    title: context.l10n.cloudSync_progress,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: progress.fraction),
        const SizedBox(height: 12),
        Wrap(
          children: [
            CloudSyncMetadata(
              label: context.l10n.cloudSync_stage,
              value: _stageName(context, progress.stage),
            ),
            CloudSyncMetadata(
              label: context.l10n.cloudSync_objects,
              value: '${progress.completedObjects} / ${progress.totalObjects}',
            ),
            if (progress.reusedObjects > 0)
              CloudSyncMetadata(
                label: context.l10n.cloudSync_reusedObjects,
                value: '${progress.reusedObjects}',
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
  );

  Widget _metrics(BuildContext context, CloudSyncMetricsView metrics) =>
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Text(context.l10n.cloudSync_metricsDetails),
        children: [
          Wrap(
            children: [
              CloudSyncMetadata(
                label: context.l10n.cloudSync_metricsElapsed,
                value: '${metrics.elapsedMilliseconds} ms',
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_metricsRequests,
                value: '${metrics.requestCount}',
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_metricsRead,
                value: formatCloudBytes(metrics.bytesRead),
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_metricsWritten,
                value: formatCloudBytes(metrics.bytesWritten),
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_metricsHashPasses,
                value: '${metrics.hashPasses}',
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_metricsPayloadReads,
                value: '${metrics.payloadReads}',
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_metricsLocalRead,
                value: formatCloudBytes(metrics.localBytesRead),
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_metricsLocalWritten,
                value: formatCloudBytes(metrics.localBytesWritten),
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_metricsFlushes,
                value: '${metrics.flushes}',
              ),
              for (final entry in metrics.stageMilliseconds.entries)
                CloudSyncMetadata(
                  label: _stageName(context, entry.key),
                  value: '${entry.value} ms',
                ),
            ],
          ),
        ],
      );

  Widget _history(
    BuildContext context,
    CloudSyncUiPort port,
  ) => CloudSyncSection(
    title: context.l10n.cloudSync_snapshotHistory,
    subtitle: context.l10n.cloudSync_snapshotHistoryDescription,
    trailing: IconButton(
      tooltip: context.l10n.common_refresh,
      onPressed: state.isBusy
          ? null
          : () => _runAction(context, port.refreshHistory),
      icon: const Icon(Icons.refresh_rounded),
    ),
    child: !state.supportsHistory || state.snapshots.isEmpty
        ? Text(context.l10n.cloudSync_noSnapshots)
        : Column(
            children: [
              for (final snapshot in state.snapshots)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final action =
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
                                    () => port.previewRestoreSnapshot(
                                      snapshot.id,
                                    ),
                                  ),
                            child: Text(context.l10n.cloudSync_previewRestore),
                          );
                    final details = ListTile(
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 56,
                      title: Text(
                        context.l10n.cloudSync_backupItemCount(
                          snapshot.objectCount,
                        ),
                      ),
                      subtitle: Text(_date(snapshot.createdAt)),
                      trailing: constraints.maxWidth >= 520 ? action : null,
                    );
                    if (action == null || constraints.maxWidth >= 520) {
                      return details;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        details,
                        Align(alignment: Alignment.centerRight, child: action),
                      ],
                    );
                  },
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
      showCloudSyncActionError(context, error);
    }
  }

  static ButtonStyle get _buttonStyle =>
      const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 48)));

  String _backendName(CloudSyncBackendKind? backend) => switch (backend) {
    CloudSyncBackendKind.webDav => 'WebDAV',
    CloudSyncBackendKind.github => 'GitHub',
    CloudSyncBackendKind.googleDrive => 'Google Drive',
    CloudSyncBackendKind.oneDrive => 'OneDrive',
    null => '—',
  };

  String _date(DateTime? value) =>
      value == null ? '—' : value.toLocal().toString().split('.').first;

  String _stageName(BuildContext context, String stage) => switch (stage) {
    'preparing' => context.l10n.cloudSync_stagePreparing,
    'scanning' => context.l10n.cloudSync_stageScanning,
    'hashing' => context.l10n.cloudSync_stageHashing,
    'downloading' => context.l10n.cloudSync_stageDownloading,
    'verifying' => context.l10n.cloudSync_stageVerifying,
    'merging' => context.l10n.cloudSync_stageMerging,
    'reusing' => context.l10n.cloudSync_stageReusing,
    'uploading' => context.l10n.cloudSync_stageUploading,
    'committing' => context.l10n.cloudSync_stageCommitting,
    'applying' => context.l10n.cloudSync_stageApplying,
    'saving' => context.l10n.cloudSync_stageSaving,
    'retryWaiting' => context.l10n.cloudSync_stageRetryWaiting,
    'rollingBack' => context.l10n.cloudSync_stageRollingBack,
    'completed' => context.l10n.cloudSync_stageCompleted,
    _ => context.l10n.cloudSync_stageWorking,
  };
}
