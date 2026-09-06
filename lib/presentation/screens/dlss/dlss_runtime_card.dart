import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_release.dart';
import '../../../data/services/dlss/dlss_runtime_manager.dart';
import 'dlss_error_view.dart';
import '../../providers/dlss_provider.dart';
import '../settings/widgets/settings_card.dart';

class DlssRuntimeCard extends StatelessWidget {
  const DlssRuntimeCard({
    super.key,
    required this.controller,
    required this.selected,
    required this.onSelected,
  });
  final DlssController controller;
  final DlssRelease? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = this.selected;
    return SettingsCard(
      title: l10n.dlss_runtime,
      description: l10n.dlss_source,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.dlss_current}: ${controller.active?.release.tag ?? l10n.dlss_notInstalled}',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => controller.refresh(),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.common_refresh),
                ),
                TextButton.icon(
                  onPressed: () =>
                      launchUrl(Uri.parse('$dlssRepositoryUrl/releases')),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('GitHub Releases'),
                ),
              ],
            ),
            if (controller.busy) ...[
              LinearProgressIndicator(value: controller.progress?.clamp(0, 1)),
              const SizedBox(height: 8),
              Text(switch (controller.installPhase) {
                DlssInstallPhase.downloading =>
                  '${l10n.dlss_downloading} ${(100 * (controller.progress ?? 0)).toStringAsFixed(0)}%\n${(controller.downloadedBytes / 1048576).toStringAsFixed(1)} / ${(controller.downloadTotalBytes / 1048576).toStringAsFixed(1)} MiB · ${(controller.downloadBytesPerSecond / 1048576).toStringAsFixed(2)} MiB/s',
                DlssInstallPhase.extracting => l10n.dlss_extracting,
                DlssInstallPhase.probing => l10n.dlss_probing,
                DlssInstallPhase.activating => l10n.dlss_activating,
                null => l10n.dlss_loadingReleases,
              }),
              if (controller.canCancelInstall)
                TextButton(
                  onPressed: controller.cancelDownload,
                  child: Text(l10n.common_cancel),
                ),
            ],
            if (controller.error != null) ...[
              const SizedBox(height: 8),
              DlssErrorView(error: controller.error!),
            ],
            if (!controller.busy && controller.releases.isEmpty)
              Text(l10n.dlss_noReleases),
            _releases(context),
            if (selected != null)
              FilledButton.icon(
                key: const Key('dlss-install'),
                onPressed:
                    controller.busy ||
                        (controller.active?.release.directoryName ==
                                selected.directoryName &&
                            controller.ready)
                    ? null
                    : () => controller.install(selected),
                icon: const Icon(Icons.download),
                label: Text(l10n.dlss_install),
              ),
            if (controller.installations.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.dlss_installed,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _installed(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _releases(BuildContext context) {
    final l10n = context.l10n;
    return RadioGroup<int>(
      groupValue: selected?.id,
      onChanged: onSelected,
      child: Column(
        children: [
          for (final release in controller.releases)
            RadioListTile<int>(
              value: release.id,
              enabled: !controller.busy,
              title: Text(release.tag),
              subtitle: Text(
                '${release.publishedAt.toLocal().toIso8601String().split('T').first} · ${(release.bytes / 1048576).toStringAsFixed(1)} MiB'
                '${release.prerelease
                    ? ' · ${l10n.dlss_prerelease}'
                    : release.id == controller.latest?.id
                    ? ' · ${l10n.dlss_latest}'
                    : ''}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _installed(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        for (final installation in controller.installations)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${installation.release.tag} · ${(installation.installedBytes / 1048576).toStringAsFixed(1)} MiB',
                ),
                if (controller.active?.release.directoryName ==
                    installation.release.directoryName)
                  Text(l10n.dlss_current)
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: controller.busy
                            ? null
                            : () => controller.activate(installation),
                        child: Text(l10n.dlss_activate),
                      ),
                      TextButton(
                        onPressed: controller.busy
                            ? null
                            : () => controller.remove(installation),
                        child: Text(l10n.common_delete),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
