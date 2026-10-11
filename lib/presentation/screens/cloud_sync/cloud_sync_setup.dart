import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/cloud_sync/oauth/cloud_drive_oauth_client.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/cloud_sync/cloud_sync_content_selection_store.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../providers/cloud_sync/cloud_sync_error_reporter.dart';
import '../../providers/cloud_sync/cloud_sync_flight_gate.dart';
import '../../providers/cloud_sync/cloud_sync_provider_wiring.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_content_selection_dialog.dart';
import 'cloud_sync_setup_configuration.dart';
import 'cloud_sync_setup_draft.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncSetup extends ConsumerStatefulWidget {
  const CloudSyncSetup({super.key, required this.draft});

  final CloudSyncSetupDraft draft;

  @override
  ConsumerState<CloudSyncSetup> createState() => _CloudSyncSetupState();
}

class _CloudSyncSetupState extends ConsumerState<CloudSyncSetup> {
  var _busy = false;
  final _dataKinds = <CloudSyncDataKind>{
    CloudSyncDataKind.settings,
    CloudSyncDataKind.prompts,
    CloudSyncDataKind.galleries,
  };
  late final CloudSyncUiPort _cloudSyncUiPort;
  late final CloudSyncContentSelectionStore _contentSelectionStore;
  late CloudSyncContentSelection _contentSelection;

  @override
  void initState() {
    super.initState();
    widget.draft.addListener(_refreshInputState);
    _cloudSyncUiPort = ref.read(cloudSyncUiPortProvider);
    _contentSelectionStore = CloudSyncContentSelectionStore(
      ref.read(localStorageServiceProvider),
    );
    try {
      _contentSelection = _contentSelectionStore.load();
    } on FormatException {
      _contentSelection = const CloudSyncContentSelection();
    }
  }

  @override
  void didUpdateWidget(covariant CloudSyncSetup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.draft, widget.draft)) return;
    oldWidget.draft.removeListener(_refreshInputState);
    widget.draft.addListener(_refreshInputState);
  }

  void _refreshInputState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.draft.removeListener(_refreshInputState);
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (!mounted) return;
      if (error is CloudDriveOAuthException &&
          error.code == CloudDriveOAuthFailureCode.cancelled) {
        return;
      }
      final authorizationInProgress =
          error is CloudDriveOAuthException &&
          error.code == CloudDriveOAuthFailureCode.authorizationInProgress;
      final message =
          error is CloudSyncOperationInProgressException ||
              authorizationInProgress
          ? context.l10n.cloudSync_operationInProgress
          : localizeCloudSyncError(context, cloudSyncErrorMessage(error));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authorizeOAuth() => _run(widget.draft.authorizeOAuth);

  Future<void> _cancelOAuth() async {
    final draft = widget.draft;
    final backend = draft.backend;
    AppLogger.i(
      'OAuth authorization cancellation requested: backend=${backend.name}',
      'CloudSync',
    );
    try {
      await draft.cancelOAuth();
    } catch (error, stackTrace) {
      AppLogger.e(
        'OAuth authorization cancellation failed: backend=${backend.name}',
        error,
        stackTrace,
        'CloudSync',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cloudSync_operationFailed)),
      );
    }
  }

  Future<void> _connect() async {
    final draft = widget.draft;
    if (!draft.canConnect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cloudSync_fillRequiredFields)),
      );
      return;
    }
    final request = CloudSyncConnectRequest(
      connection: draft.connection,
      dataKinds: _dataKinds,
      contentSelection: _contentSelection,
    );
    final oauthDraft = draft.handOffOAuthDraft();
    await _run(() async {
      try {
        await _cloudSyncUiPort.connect(request);
      } catch (_) {
        if (oauthDraft != null) await draft.reclaimOAuthDraft(oauthDraft);
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final backend = draft.backend;
    final oauthDiagnostic = backend.usesOAuth
        ? ref
              .watch(cloudDriveProviderRegistryProvider)
              .require(backend.oauthProvider)
              .diagnose()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CloudSyncStatusBanner(
          icon: Icons.cloud_sync_outlined,
          title: context.l10n.cloudSync_disconnected,
          message: context.l10n.cloudSync_oneClickDescription,
        ),
        const SizedBox(height: 20),
        CloudSyncSetupConfiguration(
          backend: backend,
          url: draft.url,
          username: draft.username,
          secret: draft.secret,
          owner: draft.owner,
          repository: draft.repository,
          branch: draft.branch,
          path: draft.path,
          allowInsecureHttp: draft.allowInsecureHttp,
          onBackendChanged: draft.changeBackend,
          onAllowInsecureHttpChanged: draft.setAllowInsecureHttp,
          oauthConfigured: oauthDiagnostic?.isConfigured ?? true,
          oauthConfigurationMessage: oauthDiagnostic?.reasons.join('\n') ?? '',
          oauthBusy: draft.authorizingOAuth,
          oauthAccountLabel: draft.oauthAccountLabel,
          onAuthorizeOAuth: _authorizeOAuth,
          onCancelOAuth: _cancelOAuth,
        ),
        _dataScope(),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final button = compact
                ? FilledButton(
                    key: const ValueKey('cloud-sync-save-connection'),
                    onPressed: _busy ? null : _connect,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.l10n.cloudSync_saveConnection,
                            textAlign: TextAlign.center,
                          ),
                  )
                : FilledButton.icon(
                    key: const ValueKey('cloud-sync-save-connection'),
                    onPressed: _busy ? null : _connect,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(context.l10n.cloudSync_saveConnection),
                  );
            return Align(
              alignment: Alignment.centerRight,
              child: compact
                  ? SizedBox(width: double.infinity, child: button)
                  : button,
            );
          },
        ),
      ],
    );
  }

  Widget _dataScope() => CloudSyncSection(
    child: ListTile(
      key: const ValueKey('cloud-sync-content-selection-entry'),
      contentPadding: EdgeInsets.zero,
      minTileHeight: 56,
      title: Text(context.l10n.cloudSync_chooseBackupContents),
      subtitle: Text(
        context.l10n.cloudSync_selectedContentSummary(
          _contentSelection.selectedItemCount,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _editContentSelection,
    ),
  );

  Future<void> _editContentSelection() async {
    final value = await showCloudSyncContentSelectionDialog(
      context: context,
      initialSelection: _contentSelection,
      skills: ref.read(agentSettingsProvider).skills,
    );
    if (value != null && mounted) _updateContentSelection(value);
  }

  void _updateContentSelection(CloudSyncContentSelection value) {
    setState(() => _contentSelection = value);
    unawaited(_contentSelectionStore.save(value));
  }
}
