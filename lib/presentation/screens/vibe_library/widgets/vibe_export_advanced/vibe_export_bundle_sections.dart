import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/vibe/vibe_library_entry.dart';
import 'vibe_export_option_card.dart';

/// Bundle 导出模式选项（仅单选 bundle 时显示）
class VibeExportBundleModeCard extends StatelessWidget {
  const VibeExportBundleModeCard({
    super.key,
    required this.entry,
    required this.exportWholeBundle,
    required this.onModeChanged,
  });

  final VibeLibraryEntry entry;
  final bool exportWholeBundle;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = entry.bundledVibeCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_zip_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.vibe_export_method,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                value: true,
                label: Text(context.l10n.vibe_export_wholeBundle),
                icon: const Icon(Icons.folder_zip),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text(context.l10n.vibe_export_internalVibe),
                icon: const Icon(Icons.layers),
              ),
            ],
            selected: {exportWholeBundle},
            onSelectionChanged: (value) => onModeChanged(value.first),
          ),
          const SizedBox(height: 8),
          Text(
            exportWholeBundle
                ? context.l10n.vibe_export_wholeBundleDescription(count)
                : context.l10n.vibe_export_internalVibeDescription(count),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 内部 vibe 选择列表（仅当单选 bundle 且选择导出单个 vibe 时显示）
class VibeExportInternalVibeList extends StatelessWidget {
  const VibeExportInternalVibeList({
    super.key,
    required this.entry,
    required this.selectedInternalVibes,
    required this.errorMessage,
    required this.hasInternalVibeSelectionError,
    required this.onToggleAll,
    required this.onItemChanged,
  });

  final VibeLibraryEntry entry;
  final List<bool> selectedInternalVibes;
  final String? errorMessage;
  final bool hasInternalVibeSelectionError;
  final VoidCallback onToggleAll;
  final void Function(int index, bool selected) onItemChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = entry.bundledVibeNames ?? [];
    final previews = entry.bundledVibePreviews ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.vibe_export_selectVibesToExport,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onToggleAll,
                child: Text(
                  selectedInternalVibes.every((v) => v)
                      ? context.l10n.common_deselectAll
                      : context.l10n.common_selectAll,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: names.length,
              itemBuilder: (context, index) {
                final name = names[index];
                final preview = index < previews.length
                    ? previews[index]
                    : null;
                final isSelected = selectedInternalVibes[index];

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) => onItemChanged(index, value ?? false),
                  title: Row(
                    children: [
                      if (preview != null) ...[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: theme.colorScheme.surfaceContainerHigh,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(
                            preview,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image,
                                size: 20,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          if (errorMessage != null && hasInternalVibeSelectionError) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 导出 Bundle / 文件选项卡片
class VibeExportBundleOptionCard extends StatelessWidget {
  const VibeExportBundleOptionCard({
    super.key,
    required this.isSelected,
    required this.isDisabled,
    required this.isBundle,
    required this.includeThumbnail,
    required this.compress,
    required this.onToggle,
    required this.onIncludeThumbnailChanged,
    required this.onCompressChanged,
  });

  final bool isSelected;
  final bool isDisabled;
  final bool isBundle;
  final bool includeThumbnail;
  final bool compress;
  final VoidCallback? onToggle;
  final ValueChanged<bool> onIncludeThumbnailChanged;
  final ValueChanged<bool> onCompressChanged;

  @override
  Widget build(BuildContext context) {
    return VibeExportOptionCard(
      isSelected: isSelected,
      isDisabled: isDisabled,
      onTap: isDisabled ? null : onToggle,
      icon: Icons.folder_zip_outlined,
      title: isBundle
          ? context.l10n.vibe_export_exportBundle
          : context.l10n.vibe_export_exportAsFiles,
      subtitle: isBundle
          ? context.l10n.vibe_export_exportBundleDescription
          : context.l10n.vibe_export_exportAsFilesDescription,
      child: isSelected
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Bundle 选项
                VibeExportCheckboxRow(
                  value: includeThumbnail,
                  onChanged: (value) =>
                      onIncludeThumbnailChanged(value ?? true),
                  title: context.l10n.vibe_export_include_thumbnails,
                  subtitle:
                      context.l10n.vibe_export_include_thumbnails_subtitle,
                ),
                const SizedBox(height: 8),
                VibeExportCheckboxRow(
                  value: compress,
                  onChanged: (value) => onCompressChanged(value ?? false),
                  title: context.l10n.vibe_export_compressData,
                  subtitle: context.l10n.vibe_export_compressDataDescription,
                ),
              ],
            )
          : null,
    );
  }
}

/// 导出为 ZIP 选项卡片
class VibeExportZipOptionCard extends StatelessWidget {
  const VibeExportZipOptionCard({
    super.key,
    required this.isSelected,
    required this.includeThumbnail,
    required this.compress,
    required this.onToggle,
    required this.onIncludeThumbnailChanged,
    required this.onCompressChanged,
  });

  final bool isSelected;
  final bool includeThumbnail;
  final bool compress;
  final VoidCallback onToggle;
  final ValueChanged<bool> onIncludeThumbnailChanged;
  final ValueChanged<bool> onCompressChanged;

  @override
  Widget build(BuildContext context) {
    return VibeExportOptionCard(
      isSelected: isSelected,
      onTap: onToggle,
      icon: Icons.archive_outlined,
      title: context.l10n.vibe_export_exportAsZip,
      subtitle: context.l10n.vibe_export_exportAsZipDescription,
      child: isSelected
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                VibeExportCheckboxRow(
                  value: includeThumbnail,
                  onChanged: (value) =>
                      onIncludeThumbnailChanged(value ?? true),
                  title: context.l10n.vibe_export_include_thumbnails,
                  subtitle:
                      context.l10n.vibe_export_include_thumbnails_subtitle,
                ),
                const SizedBox(height: 8),
                VibeExportCheckboxRow(
                  value: compress,
                  onChanged: (value) => onCompressChanged(value ?? false),
                  title: context.l10n.vibe_export_compressData,
                  subtitle: context.l10n.vibe_export_zipCompressDescription,
                ),
              ],
            )
          : null,
    );
  }
}
