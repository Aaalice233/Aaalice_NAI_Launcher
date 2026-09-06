import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/dlss_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../settings/widgets/settings_card.dart';
import 'dlss_enhancement_panel.dart';

class DlssMaintenanceCard extends StatelessWidget {
  const DlssMaintenanceCard({super.key, required this.controller});
  final DlssController controller;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bytes = controller.installations.fold<int>(
      0,
      (sum, item) => sum + item.installedBytes,
    );
    return SettingsCard(
      title: l10n.dlss_maintenance,
      icon: Icons.build_outlined,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.dlss_diskUsage}: ${(bytes / 1048576).toStringAsFixed(1)} MiB',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: controller.enabled && !controller.busy
                    ? () => _pick(context)
                    : null,
                icon: const Icon(Icons.image_outlined),
                label: Text(l10n.dlss_tryImage),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      if (context.mounted) await showDlssEnhancement(context, bytes);
    } catch (error) {
      if (context.mounted) AppToast.error(context, error.toString());
    }
  }
}
