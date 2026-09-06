import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/dlss_provider.dart';
import '../settings/widgets/settings_card.dart';
import 'dlss_environment_card.dart';
import 'dlss_error_view.dart';
import 'dlss_maintenance_card.dart';
import 'dlss_preset_editor.dart';
import 'dlss_runtime_card.dart';

class DlssSettingsSection extends ConsumerStatefulWidget {
  const DlssSettingsSection({super.key});
  @override
  ConsumerState<DlssSettingsSection> createState() =>
      _DlssSettingsSectionState();
}

class _DlssSettingsSectionState extends ConsumerState<DlssSettingsSection> {
  int? _selected;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(dlssProvider).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(dlssProvider);
    final l10n = context.l10n;
    final selected =
        controller.releases.where((r) => r.id == _selected).firstOrNull ??
        controller.latest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.dlss_description),
        const SizedBox(height: 20),
        DlssEnvironmentCard(controller: controller),
        const SizedBox(height: 16),
        SettingsCard(
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('dlss-enabled'),
                title: Text(l10n.dlss_enabled),
                value: controller.enabled,
                onChanged: controller.ready && !controller.busy
                    ? controller.setEnabled
                    : null,
              ),
              SwitchListTile(
                key: const Key('dlss-automatic'),
                title: Text(l10n.dlss_automatic),
                subtitle: Text(l10n.dlss_automaticHint),
                value: controller.automatic,
                onChanged: controller.enabled && !controller.busy
                    ? controller.setAutomatic
                    : null,
              ),
              if (controller.enhancementError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DlssErrorView(
                    error: controller.enhancementError!,
                    summary: l10n.dlss_failed,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DlssRuntimeCard(
          controller: controller,
          selected: selected,
          onSelected: (value) => setState(() => _selected = value),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: l10n.dlss_defaults,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: DlssPresetEditor(),
          ),
        ),
        const SizedBox(height: 16),
        DlssMaintenanceCard(controller: controller),
      ],
    );
  }
}
