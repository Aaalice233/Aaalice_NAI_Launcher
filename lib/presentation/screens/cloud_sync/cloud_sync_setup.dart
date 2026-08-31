import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/cloud_sync/cloud_sync_content_selection_store.dart';
import '../../agent_settings/providers/agent_settings_provider.dart';
import '../../providers/cloud_sync/cloud_sync_flight_gate.dart';
import '../../providers/cloud_sync/cloud_sync_provider_wiring.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_agent_content_section.dart';
import 'cloud_sync_setup_configuration.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncSetup extends ConsumerStatefulWidget {
  const CloudSyncSetup({super.key});

  @override
  ConsumerState<CloudSyncSetup> createState() => _CloudSyncSetupState();
}

class _CloudSyncSetupState extends ConsumerState<CloudSyncSetup> {
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _secret = TextEditingController();
  final _owner = TextEditingController();
  final _repository = TextEditingController();
  final _branch = TextEditingController(text: 'main');
  final _path = TextEditingController(text: 'aaalice-sync');
  var _backend = CloudSyncBackendKind.webDav;
  var _busy = false;
  var _allowInsecureHttp = false;
  CloudSyncConnectionDraft? _oauthDraft;
  var _dataKinds = <CloudSyncDataKind>{
    CloudSyncDataKind.settings,
    CloudSyncDataKind.prompts,
    CloudSyncDataKind.galleries,
  };
  late final CloudSyncUiPort _cloudSyncUiPort;
  late final CloudSyncContentSelectionStore _contentSelectionStore;
  late CloudSyncContentSelection _contentSelection;

  Iterable<TextEditingController> get _controllers => [
    _url,
    _username,
    _secret,
    _owner,
    _repository,
    _branch,
    _path,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_refreshInputState);
    }
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

  void _refreshInputState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final pendingOAuth = _oauthDraft;
    if (pendingOAuth != null) {
      unawaited(_cloudSyncUiPort.discardCloudDriveAuthorization(pendingOAuth));
    }
    for (final controller in _controllers) {
      controller.removeListener(_refreshInputState);
      controller.dispose();
    }
    super.dispose();
  }

  CloudSyncConnectionDraft get _draft {
    final oauth = _oauthDraft;
    if (_backend.usesOAuth && oauth != null) {
      return CloudSyncConnectionDraft(
        backend: _backend,
        path: _path.text.trim().isEmpty ? 'aaalice-sync' : _path.text.trim(),
        accountId: oauth.accountId,
        accountLabel: oauth.accountLabel,
      );
    }
    return CloudSyncConnectionDraft(
      backend: _backend,
      serverUrl: _url.text.trim(),
      username: _username.text.trim(),
      secret: _secret.text,
      owner: _owner.text.trim(),
      repository: _repository.text.trim(),
      branch: _branch.text.trim().isEmpty ? 'main' : _branch.text.trim(),
      path: _path.text.trim().isEmpty ? 'aaalice-sync' : _path.text.trim(),
      allowInsecureHttp: _allowInsecureHttp,
    );
  }

  bool get _canConnect => switch (_backend) {
    CloudSyncBackendKind.webDav =>
      _url.text.trim().isNotEmpty &&
          _username.text.trim().isNotEmpty &&
          _secret.text.isNotEmpty,
    CloudSyncBackendKind.github =>
      _owner.text.trim().isNotEmpty &&
          _repository.text.trim().isNotEmpty &&
          _secret.text.isNotEmpty,
    CloudSyncBackendKind.googleDrive || CloudSyncBackendKind.oneDrive =>
      _oauthDraft?.backend == _backend &&
          (_oauthDraft?.accountId.isNotEmpty ?? false),
  };

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (!mounted) return;
      final message = error is CloudSyncOperationInProgressException
          ? context.l10n.cloudSync_operationInProgress
          : ref.read(cloudSyncUiStateProvider).error;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authorizeOAuth() async {
    final backend = _backend;
    final stopwatch = Stopwatch()..start();
    AppLogger.i(
      'OAuth authorization UI started: backend=${backend.name}',
      'CloudSync',
    );
    await _run(() async {
      final previous = _oauthDraft;
      if (previous != null) {
        await _cloudSyncUiPort.discardCloudDriveAuthorization(previous);
        if (!mounted) return;
        setState(() => _oauthDraft = null);
      }
      final connected = await _cloudSyncUiPort.authorizeCloudDrive(backend);
      if (!mounted) {
        await _cloudSyncUiPort.discardCloudDriveAuthorization(connected);
        return;
      }
      setState(() => _oauthDraft = connected);
    });
    AppLogger.i(
      'OAuth authorization UI finished: backend=${backend.name}, '
          'elapsedMs=${stopwatch.elapsedMilliseconds}',
      'CloudSync',
    );
  }

  void _changeBackend(CloudSyncBackendKind value) {
    if (value == _backend) return;
    final previous = _oauthDraft;
    setState(() {
      _backend = value;
      _oauthDraft = null;
    });
    if (previous != null) {
      unawaited(_cloudSyncUiPort.discardCloudDriveAuthorization(previous));
    }
  }

  Future<void> _connect() async {
    if (!_canConnect) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cloudSync_fillRequiredFields)),
      );
      return;
    }
    final connection = _draft;
    final oauthDraft = connection.backend.usesOAuth ? _oauthDraft : null;
    final request = CloudSyncConnectRequest(
      connection: connection,
      dataKinds: _dataKinds,
      contentSelection: _contentSelection,
    );

    // The save operation owns this authorization from its first await onward.
    // dispose() must not revoke a session while connect() is persisting it.
    if (oauthDraft != null) _oauthDraft = null;
    await _run(() async {
      try {
        await _cloudSyncUiPort.connect(request);
      } catch (_) {
        if (oauthDraft != null) {
          if (mounted) {
            _oauthDraft = oauthDraft;
          } else {
            await _cloudSyncUiPort.discardCloudDriveAuthorization(oauthDraft);
          }
        }
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final oauthDiagnostic = _backend.usesOAuth
        ? ref
              .watch(cloudDriveProviderRegistryProvider)
              .require(_backend.oauthProvider)
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
          backend: _backend,
          url: _url,
          username: _username,
          secret: _secret,
          owner: _owner,
          repository: _repository,
          branch: _branch,
          path: _path,
          allowInsecureHttp: _allowInsecureHttp,
          onBackendChanged: _changeBackend,
          onAllowInsecureHttpChanged: (value) =>
              setState(() => _allowInsecureHttp = value),
          oauthConfigured: oauthDiagnostic?.isConfigured ?? true,
          oauthConfigurationMessage: oauthDiagnostic?.reasons.join('\n') ?? '',
          oauthBusy: _busy,
          oauthAccountLabel: _oauthDraft?.accountLabel,
          onAuthorizeOAuth: _authorizeOAuth,
        ),
        _dataScope(),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('cloud-sync-save-connection'),
            onPressed: _busy ? null : _connect,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(context.l10n.cloudSync_saveConnection),
          ),
        ),
      ],
    );
  }

  Widget _dataScope() => CloudSyncSection(
    title: context.l10n.cloudSync_dataScope,
    subtitle: context.l10n.cloudSync_dataScopeDescription,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filter(
              CloudSyncDataKind.settings,
              context.l10n.cloudSync_kindSettings,
            ),
            _filter(
              CloudSyncDataKind.prompts,
              context.l10n.cloudSync_kindPrompts,
            ),
            _filter(
              CloudSyncDataKind.galleries,
              context.l10n.cloudSync_kindGalleries,
            ),
            _filter(
              CloudSyncDataKind.largeBinary,
              context.l10n.cloudSync_kindLargeFiles,
            ),
          ],
        ),
        const SizedBox(height: 16),
        CloudSyncAgentContentSection(
          selection: _contentSelection,
          skills: ref.watch(agentSettingsProvider).skills,
          onChanged: _updateContentSelection,
        ),
      ],
    ),
  );

  Widget _filter(CloudSyncDataKind kind, String label) => FilterChip(
    label: Text(label),
    selected: _dataKinds.contains(kind),
    onSelected: (selected) => setState(() {
      _dataKinds = {..._dataKinds};
      selected ? _dataKinds.add(kind) : _dataKinds.remove(kind);
    }),
  );

  void _updateContentSelection(CloudSyncContentSelection value) {
    setState(() => _contentSelection = value);
    unawaited(_contentSelectionStore.save(value));
  }
}
