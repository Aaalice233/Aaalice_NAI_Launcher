import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_device_probe.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/dlss_provider.dart';
import '../settings/widgets/settings_card.dart';

String dlssAvailabilityLabel(AppLocalizations l10n, DlssAvailability status) =>
    switch (status) {
      DlssAvailability.notChecked => l10n.dlss_notChecked,
      DlssAvailability.checking => l10n.dlss_checking,
      DlssAvailability.missingRuntime => l10n.dlss_missingRuntime,
      DlssAvailability.noCompatibleGpu => l10n.dlss_noGpu,
      DlssAvailability.invalidComponents => l10n.dlss_invalidComponents,
      DlssAvailability.initializationFailed => l10n.dlss_initializationFailed,
      DlssAvailability.ready => l10n.dlss_ready,
    };

class DlssEnvironmentCard extends StatelessWidget {
  const DlssEnvironmentCard({super.key, required this.controller});
  final DlssController controller;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = controller.environment;
    return SettingsCard(
      title: l10n.dlss_environment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(dlssAvailabilityLabel(l10n, state.availability)),
            RadioGroup<String>(
              groupValue: controller.preferredLuid ?? '',
              onChanged: (value) =>
                  controller.selectDevice(value == '' ? null : value),
              child: Column(
                children: [
                  RadioListTile(
                    value: '',
                    title: Text(l10n.dlss_gpuAutomatic),
                    enabled: !controller.busy,
                  ),
                  for (final device in state.devices.where(
                    (device) => device.vendorId == 0x10de,
                  ))
                    RadioListTile(
                      value: device.luid,
                      title: Text(device.name),
                      enabled: !controller.busy,
                      subtitle: Text(
                        '${l10n.dlss_driver}: ${device.driver ?? l10n.dlss_unknown} · ${(device.memoryBytes / 1073741824).toStringAsFixed(1)} GiB',
                      ),
                    ),
                ],
              ),
            ),
            if (state.detail != null)
              ExpansionTile(
                title: Text(l10n.dlss_diagnostics),
                children: [SelectableText(state.detail!)],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('dlss-detect'),
                onPressed: controller.busy ? null : controller.detect,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(l10n.dlss_detect),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
