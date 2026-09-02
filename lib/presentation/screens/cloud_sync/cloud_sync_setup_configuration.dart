import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';
import 'cloud_sync_widgets.dart';

class CloudSyncSetupConfiguration extends StatelessWidget {
  const CloudSyncSetupConfiguration({
    super.key,
    required this.backend,
    required this.url,
    required this.username,
    required this.secret,
    required this.owner,
    required this.repository,
    required this.branch,
    required this.path,
    required this.allowInsecureHttp,
    required this.onBackendChanged,
    required this.onAllowInsecureHttpChanged,
    required this.oauthConfigured,
    required this.oauthConfigurationMessage,
    required this.oauthBusy,
    required this.oauthAccountLabel,
    required this.onAuthorizeOAuth,
    required this.onCancelOAuth,
  });

  final CloudSyncBackendKind backend;
  final TextEditingController url;
  final TextEditingController username;
  final TextEditingController secret;
  final TextEditingController owner;
  final TextEditingController repository;
  final TextEditingController branch;
  final TextEditingController path;
  final bool allowInsecureHttp;
  final ValueChanged<CloudSyncBackendKind> onBackendChanged;
  final ValueChanged<bool> onAllowInsecureHttpChanged;
  final bool oauthConfigured;
  final String oauthConfigurationMessage;
  final bool oauthBusy;
  final String? oauthAccountLabel;
  final VoidCallback onAuthorizeOAuth;
  final VoidCallback onCancelOAuth;

  @override
  Widget build(BuildContext context) => CloudSyncSection(
    title: context.l10n.cloudSync_chooseBackend,
    subtitle: context.l10n.cloudSync_chooseBackendDescription,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: context.l10n.cloudSync_chooseBackend,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _destinationChip(CloudSyncBackendKind.webDav, 'WebDAV'),
              _destinationChip(CloudSyncBackendKind.github, 'GitHub'),
              _destinationChip(
                CloudSyncBackendKind.googleDrive,
                'Google Drive',
              ),
              _destinationChip(CloudSyncBackendKind.oneDrive, 'OneDrive'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (backend == CloudSyncBackendKind.webDav) ...[
          _fieldGrid([
            CloudSyncField(
              controller: url,
              label: context.l10n.cloudSync_webDavUrl,
            ),
            CloudSyncField(
              controller: username,
              label: context.l10n.cloudSync_username,
            ),
            CloudSyncField(
              controller: secret,
              label: context.l10n.cloudSync_password,
              obscureText: true,
            ),
          ]),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.l10n.cloudSync_advancedSettings),
            children: [
              CloudSyncField(
                controller: path,
                label: context.l10n.cloudSync_remotePath,
              ),
              SwitchListTile(
                key: const ValueKey('cloud-sync-allow-insecure-http'),
                contentPadding: EdgeInsets.zero,
                value: allowInsecureHttp,
                onChanged: onAllowInsecureHttpChanged,
                title: Text(context.l10n.cloudSync_allowInsecureHttp),
                subtitle: Text(context.l10n.cloudSync_allowInsecureHttpWarning),
              ),
            ],
          ),
        ] else if (backend == CloudSyncBackendKind.github)
          _fieldGrid([
            CloudSyncField(
              controller: secret,
              label: context.l10n.cloudSync_githubToken,
              obscureText: true,
            ),
            CloudSyncField(
              controller: owner,
              label: context.l10n.cloudSync_owner,
            ),
            CloudSyncField(
              controller: repository,
              label: context.l10n.cloudSync_repository,
            ),
          ])
        else
          _oauthConnection(context),
        if (backend == CloudSyncBackendKind.github)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.l10n.cloudSync_advancedSettings),
            children: [
              _fieldGrid([
                CloudSyncField(
                  controller: branch,
                  label: context.l10n.cloudSync_branch,
                ),
                CloudSyncField(
                  controller: path,
                  label: context.l10n.cloudSync_remotePath,
                ),
              ]),
            ],
          ),
      ],
    ),
  );

  Widget _destinationChip(CloudSyncBackendKind value, String label) =>
      ChoiceChip(
        label: Text(label),
        selected: backend == value,
        onSelected: oauthBusy
            ? null
            : (selected) {
                if (selected) onBackendChanged(value);
              },
      );

  Widget _oauthConnection(BuildContext context) {
    final providerName = backend == CloudSyncBackendKind.googleDrive
        ? 'Google Drive'
        : 'OneDrive';
    final connected = oauthAccountLabel != null;
    return CloudSyncSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                connected ? Icons.account_circle_outlined : Icons.lock_outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? context.l10n.cloudSync_accountConnected(
                              providerName,
                            )
                          : context.l10n.cloudSync_oauthDescription(
                              providerName,
                            ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connected
                          ? oauthAccountLabel!
                          : oauthConfigured
                          ? context.l10n.cloudSync_oauthSystemBrowser
                          : context.l10n.cloudSync_oauthUnavailable(
                              oauthConfigurationMessage,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              key: ValueKey('cloud-sync-authorize-${backend.name}'),
              onPressed: oauthBusy
                  ? onCancelOAuth
                  : oauthConfigured
                  ? onAuthorizeOAuth
                  : null,
              icon: Icon(
                oauthBusy
                    ? Icons.close
                    : connected
                    ? Icons.swap_horiz
                    : Icons.open_in_browser,
              ),
              label: Text(
                oauthBusy
                    ? context.l10n.cloudSync_cancel
                    : connected
                    ? context.l10n.cloudSync_changeAccount
                    : context.l10n.cloudSync_connectAccount,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}
