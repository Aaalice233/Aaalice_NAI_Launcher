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
    required this.onContinue,
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
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => CloudSyncSection(
    title: context.l10n.cloudSync_chooseBackend,
    subtitle: context.l10n.cloudSync_chooseBackendDescription,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<CloudSyncBackendKind>(
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 48)),
          ),
          segments: const [
            ButtonSegment(
              value: CloudSyncBackendKind.webDav,
              label: Text('WebDAV'),
            ),
            ButtonSegment(
              value: CloudSyncBackendKind.github,
              label: Text('GitHub'),
            ),
          ],
          selected: {backend},
          onSelectionChanged: (value) => onBackendChanged(value.first),
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
            CloudSyncField(
              controller: path,
              label: context.l10n.cloudSync_remotePath,
            ),
          ]),
          SwitchListTile(
            key: const ValueKey('cloud-sync-allow-insecure-http'),
            contentPadding: EdgeInsets.zero,
            value: allowInsecureHttp,
            onChanged: onAllowInsecureHttpChanged,
            title: Text(context.l10n.cloudSync_allowInsecureHttp),
            subtitle: Text(context.l10n.cloudSync_allowInsecureHttpWarning),
          ),
        ] else
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
            CloudSyncField(
              controller: branch,
              label: context.l10n.cloudSync_branch,
            ),
            CloudSyncField(
              controller: path,
              label: context.l10n.cloudSync_remotePath,
            ),
          ]),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: Text(context.l10n.cloudSync_continueToTest),
          ),
        ),
      ],
    ),
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
}
