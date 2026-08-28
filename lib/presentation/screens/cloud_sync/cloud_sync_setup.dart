import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_setup_configuration.dart';
import 'cloud_sync_initial_choice.dart';
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
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  final _recoveryInput = TextEditingController();
  var _backend = CloudSyncBackendKind.webDav;
  var _step = 0;
  var _busy = false;
  var _allowInsecureHttp = false;
  var _recoveryConfirmed = false;
  var _dataKinds = <CloudSyncDataKind>{
    CloudSyncDataKind.settings,
    CloudSyncDataKind.prompts,
    CloudSyncDataKind.galleries,
  };
  CloudSyncCapabilityResult? _testResult;
  CloudSyncInitialAction? _initialAction;
  String? _recoveryKey;
  bool? _remoteExists;

  @override
  void dispose() {
    for (final controller in [
      _url,
      _username,
      _secret,
      _owner,
      _repository,
      _branch,
      _path,
      _password,
      _passwordConfirmation,
      _recoveryInput,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  CloudSyncConnectionDraft get _draft => CloudSyncConnectionDraft(
    backend: _backend,
    serverUrl: _url.text.trim(),
    username: _username.text.trim(),
    secret: _secret.text,
    owner: _owner.text.trim(),
    repository: _repository.text.trim(),
    branch: _branch.text.trim(),
    path: _path.text.trim(),
    allowInsecureHttp: _allowInsecureHttp,
  );

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.cloudSync_actionFailed('$error')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testConnection() => _run(() async {
    final result = await ref
        .read(cloudSyncUiPortProvider)
        .testConnection(_draft);
    if (!mounted) return;
    setState(() {
      _testResult = result;
    });
  });

  Future<void> _detectRemote() => _run(() async {
    await ref.read(cloudSyncUiPortProvider).detectRemote(_draft);
    if (mounted) {
      setState(() {
        _remoteExists = ref.read(cloudSyncUiStateProvider).remoteExists;
        _initialAction =
            _testResult?.mode == CloudSyncCapabilityMode.manualBackupOnly
            ? CloudSyncInitialAction.upload
            : _remoteExists == true
            ? CloudSyncInitialAction.mergePreview
            : CloudSyncInitialAction.upload;
        _step = 4;
      });
    }
  });

  Future<void> _createRecoveryKey() => _run(() async {
    final key = await ref
        .read(cloudSyncUiPortProvider)
        .createRecoveryKey(_password.text);
    if (mounted) {
      setState(() {
        _recoveryKey = key;
        _recoveryConfirmed = false;
      });
    }
  });

  Future<void> _recover() => _run(() async {
    await ref
        .read(cloudSyncUiPortProvider)
        .recoverKeyEnvelope(_recoveryInput.text.trim(), _password.text);
  });

  Future<void> _connect() => _run(() async {
    if (_initialAction != CloudSyncInitialAction.mergePreview) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.cloudSync_dangerousFirstSyncTitle),
          content: Text(
            _initialAction == CloudSyncInitialAction.upload
                ? context.l10n.cloudSync_initialUploadWarning
                : context.l10n.cloudSync_initialDownloadWarning,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cloudSync_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.cloudSync_confirmOverwrite),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref
        .read(cloudSyncUiPortProvider)
        .connect(
          CloudSyncConnectRequest(
            connection: _draft,
            dataKinds: _dataKinds,
            encryptionPassword: _password.text,
            recoveryKeyConfirmed: _recoveryConfirmed,
            initialAction: _initialAction!,
          ),
        );
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.cloudSync_stepConfiguration,
      context.l10n.cloudSync_stepTest,
      context.l10n.cloudSync_stepData,
      context.l10n.cloudSync_stepRemote,
      context.l10n.cloudSync_stepEncryption,
      context.l10n.cloudSync_stepInitial,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CloudSyncStatusBanner(
          icon: Icons.cloud_off_outlined,
          title: context.l10n.cloudSync_disconnected,
          message: context.l10n.cloudSync_disconnectedDescription,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < labels.length; index++)
              Chip(
                avatar: CircleAvatar(child: Text('${index + 1}')),
                label: Text(labels[index]),
                backgroundColor: index == _step
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              0 => CloudSyncSetupConfiguration(
                backend: _backend,
                url: _url,
                username: _username,
                secret: _secret,
                owner: _owner,
                repository: _repository,
                branch: _branch,
                path: _path,
                allowInsecureHttp: _allowInsecureHttp,
                onBackendChanged: (value) => setState(() {
                  _backend = value;
                  _testResult = null;
                }),
                onAllowInsecureHttpChanged: (value) =>
                    setState(() => _allowInsecureHttp = value),
                onContinue: () => setState(() => _step = 1),
              ),
              1 => _connectionTest(),
              2 => _dataScope(),
              3 => _remoteDetection(),
              4 => _encryption(),
              _ => CloudSyncInitialChoice(
                value: _initialAction,
                manualBackupOnly:
                    _testResult?.mode ==
                    CloudSyncCapabilityMode.manualBackupOnly,
                busy: _busy,
                onChanged: (value) => setState(() => _initialAction = value),
                onConnect: _connect,
              ),
            },
          ),
        ),
      ],
    );
  }

  Widget _connectionTest() => CloudSyncSection(
    title: context.l10n.cloudSync_testConnection,
    subtitle: context.l10n.cloudSync_testConnectionDescription,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_testResult != null) ...[
          CloudSyncStatusBanner(
            icon: _testResult!.succeeded
                ? Icons.check_circle_outline
                : Icons.error_outline,
            title: _testResult!.succeeded
                ? context.l10n.cloudSync_testSucceeded
                : context.l10n.cloudSync_testFailed,
            message: _testResult!.message.isEmpty
                ? context.l10n.cloudSync_serviceNotConnected
                : _testResult!.message,
            warning: !_testResult!.succeeded,
          ),
          if (_testResult!.limit != null) ...[
            const SizedBox(height: 8),
            Text(context.l10n.cloudSync_limit(_testResult!.limit!)),
          ],
          const SizedBox(height: 8),
          Wrap(
            children: [
              CloudSyncMetadata(
                label: context.l10n.cloudSync_snapshotHistory,
                value: _testResult!.supportsHistory ? '✓' : '—',
              ),
              CloudSyncMetadata(
                label: context.l10n.cloudSync_deleteRemoteNamespace,
                value: _testResult!.supportsDelete ? '✓' : '—',
              ),
            ],
          ),
          for (final warning in _testResult!.warnings) ...[
            const SizedBox(height: 8),
            CloudSyncStatusBanner(
              icon: Icons.warning_amber_rounded,
              title: context.l10n.cloudSync_maintenanceWarning,
              message: warning,
              warning: true,
            ),
          ],
          if (_testResult!.mode ==
              CloudSyncCapabilityMode.manualBackupOnly) ...[
            const SizedBox(height: 8),
            Text(context.l10n.cloudSync_manualBackupOnly),
          ],
          const SizedBox(height: 16),
        ],
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _busy ? null : _testConnection,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(context.l10n.cloudSync_runRealTest),
            ),
            if (_testResult?.succeeded == true)
              FilledButton(
                onPressed: () => setState(() => _step = 2),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: Text(context.l10n.cloudSync_continueToData),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _dataScope() => CloudSyncSection(
    title: context.l10n.cloudSync_dataScope,
    subtitle: context.l10n.cloudSync_dataScopeDescription,
    child: Column(
      children: [
        _dataCheckbox(
          CloudSyncDataKind.settings,
          context.l10n.cloudSync_kindSettings,
        ),
        _dataCheckbox(
          CloudSyncDataKind.prompts,
          context.l10n.cloudSync_kindPrompts,
        ),
        _dataCheckbox(
          CloudSyncDataKind.galleries,
          context.l10n.cloudSync_kindGalleries,
        ),
        _dataCheckbox(
          CloudSyncDataKind.largeBinary,
          context.l10n.cloudSync_kindLargeFiles,
        ),
        const SizedBox(height: 12),
        _nextButton(
          context.l10n.cloudSync_continueToEncryption,
          () => setState(() => _step = 3),
        ),
      ],
    ),
  );

  Widget _encryption() => CloudSyncSection(
    title: context.l10n.cloudSync_encryption,
    subtitle: context.l10n.cloudSync_encryptionDescription,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldGrid([
          CloudSyncField(
            controller: _password,
            label: context.l10n.cloudSync_encryptionPassword,
            obscureText: true,
            onChanged: (_) => setState(() {}),
          ),
          if (_remoteExists != true)
            CloudSyncField(
              controller: _passwordConfirmation,
              label: context.l10n.cloudSync_confirmPassword,
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),
        ]),
        if (_remoteExists == true) ...[
          CloudSyncField(
            controller: _recoveryInput,
            label: context.l10n.cloudSync_oneTimeRecoveryKey,
            obscureText: true,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed:
                  _busy ||
                      _recoveryInput.text.trim().isEmpty ||
                      _password.text.isEmpty
                  ? null
                  : _recover,
              child: Text(context.l10n.cloudSync_oneTimeRecoveryKey),
            ),
          ),
        ],
        if (_remoteExists != true) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            value: _recoveryConfirmed,
            onChanged: _recoveryKey == null
                ? null
                : (value) =>
                      setState(() => _recoveryConfirmed = value ?? false),
            title: Text(context.l10n.cloudSync_recoveryKeyConfirmed),
            subtitle: Text(context.l10n.cloudSync_recoveryKeyDescription),
          ),
          if (_recoveryKey == null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : _createRecoveryKey,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.key_outlined),
                label: Text(context.l10n.cloudSync_generateRecoveryKey),
              ),
            )
          else
            CloudSyncSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.cloudSync_oneTimeRecoveryKey,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_recoveryKey!),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.cloudSync_oneTimeRecoveryKeyDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        _nextButton(
          context.l10n.cloudSync_stepInitial,
          _password.text.isNotEmpty &&
                  (_remoteExists == true ||
                      (_password.text == _passwordConfirmation.text &&
                          _recoveryKey != null &&
                          _recoveryConfirmed))
              ? () => setState(() => _step = 5)
              : null,
        ),
      ],
    ),
  );

  Widget _remoteDetection() => CloudSyncSection(
    title: context.l10n.cloudSync_detectRemote,
    subtitle: context.l10n.cloudSync_detectRemoteDescription,
    child: _nextButton(
      context.l10n.cloudSync_detectRemoteAction,
      _detectRemote,
    ),
  );

  Widget _dataCheckbox(CloudSyncDataKind kind, String label) =>
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 56,
        value: _dataKinds.contains(kind),
        title: Text(label),
        onChanged: (selected) => setState(() {
          _dataKinds = {..._dataKinds};
          selected == true ? _dataKinds.add(kind) : _dataKinds.remove(kind);
        }),
      );

  Widget _fieldGrid(List<Widget> fields) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 680
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final field in fields) SizedBox(width: width, child: field),
        ],
      );
    },
  );

  Widget _nextButton(String label, VoidCallback? onPressed) => Align(
    alignment: Alignment.centerRight,
    child: FilledButton(
      onPressed: _busy ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      child: Text(label),
    ),
  );
}
