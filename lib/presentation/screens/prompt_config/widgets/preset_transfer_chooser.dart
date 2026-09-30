import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../themes/core/layered_surface_style.dart';

enum PresetTransferAction { importPreset, exportPreset }

/// 预设导入导出的选择面板；未选中预设时导出项不可用
Future<PresetTransferAction?> showPresetTransferChooser(
  BuildContext context, {
  required String? selectedPresetName,
}) {
  return AdaptivePresenter.showPanel<PresetTransferAction>(
    context: context,
    title: context.l10n.randomManager_importExport,
    initialChildSize: 0.34,
    minChildSize: 0.28,
    maxChildSize: 0.62,
    builder: (context, scrollController) => ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        _ImportExportActionCard(
          icon: Icons.download_rounded,
          title: Text(context.l10n.randomManager_importPreset),
          subtitle: Text(context.l10n.randomManager_importPresetSubtitle),
          onTap: () =>
              Navigator.pop(context, PresetTransferAction.importPreset),
        ),
        const SizedBox(height: 10),
        _ImportExportActionCard(
          enabled: selectedPresetName != null,
          icon: Icons.upload_rounded,
          title: Text(context.l10n.randomManager_exportCurrentPreset),
          subtitle: Text(
            selectedPresetName ?? context.l10n.randomManager_noPresetSelected,
          ),
          onTap: selectedPresetName == null
              ? null
              : () => Navigator.pop(context, PresetTransferAction.exportPreset),
        ),
      ],
    ),
  );
}

class _ImportExportActionCard extends StatelessWidget {
  const _ImportExportActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final Widget title;
  final Widget subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: sectionSurfaceColor(colors),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: controlSurfaceColor(colors),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.titleSmall,
                        child: title,
                      ),
                      const SizedBox(height: 3),
                      DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        child: subtitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
