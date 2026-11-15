import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../adaptive/interaction_policy.dart';
import 'vibe_export_advanced_models.dart';
import 'vibe_export_option_card.dart';

/// 嵌入 PNG 图片选项卡片
class VibeExportEmbedImageOptionCard extends StatelessWidget {
  const VibeExportEmbedImageOptionCard({
    super.key,
    required this.isSelected,
    required this.isBundleInternalExport,
    required this.isBatchPngExport,
    required this.carrierImageOptions,
    required this.selectedCarrierImageId,
    required this.selectedImagePath,
    required this.selectedImagePreview,
    required this.isValidatingImage,
    required this.onToggle,
    required this.onCarrierChanged,
    required this.onPickImage,
  });

  final bool isSelected;
  final bool isBundleInternalExport;
  final bool isBatchPngExport;
  final List<VibeExportCarrierImageOption> carrierImageOptions;
  final String? selectedCarrierImageId;
  final String? selectedImagePath;
  final Uint8List? selectedImagePreview;
  final bool isValidatingImage;
  final VoidCallback onToggle;
  final ValueChanged<String?> onCarrierChanged;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 从 bundle 导出内部单个 vibe 时暂不支持嵌入图片
    final isDisabled = isBundleInternalExport;

    return VibeExportOptionCard(
      isSelected: isSelected,
      isDisabled: isDisabled,
      onTap: isDisabled ? null : onToggle,
      icon: Icons.image_outlined,
      title: context.l10n.vibe_export_exportAsPng,
      subtitle: isBundleInternalExport
          ? context.l10n.vibe_export_pngInternalBundleUnsupported
          : context.l10n.vibe_export_embedVibeDataIntoPng,
      child: isSelected
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (isBatchPngExport) ...[
                  Text(
                    context.l10n.vibe_export_batchPngUsesFirstImage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else if (carrierImageOptions.isNotEmpty) ...[
                  Text(
                    context.l10n.vibe_export_exportCarrierImage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      selectedImagePath == null ? selectedCarrierImageId : null,
                    ),
                    initialValue: selectedImagePath == null
                        ? selectedCarrierImageId
                        : null,
                    items: carrierImageOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option.id,
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onCarrierChanged,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // 图片选择
                if (!isBatchPngExport && selectedImagePath == null) ...[
                  OutlinedButton.icon(
                    onPressed: isValidatingImage ? null : onPickImage,
                    icon: isValidatingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open),
                    label: Text(
                      context.l10n.vibe_export_selectExternalPngImage,
                    ),
                  ),
                ] else if (!isBatchPngExport) ...[
                  Row(
                    children: [
                      // 图片预览
                      if (selectedImagePreview != null)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: theme.colorScheme.surfaceContainerHigh,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(
                            selectedImagePreview!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedImagePath!
                                  .split(Platform.pathSeparator)
                                  .last,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              key: const ValueKey(
                                'vibe-export-change-carrier-image',
                              ),
                              onPressed: isValidatingImage ? null : onPickImage,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text(context.l10n.common_change),
                              style: TextButton.styleFrom(
                                padding:
                                    context.interactionPolicy.touchAvailable
                                    ? const EdgeInsets.symmetric(horizontal: 8)
                                    : EdgeInsets.zero,
                                minimumSize:
                                    resolveVibeExportChangeImageMinimumSize(
                                      context.interactionPolicy,
                                    ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (selectedImagePath != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.vibe_export_usingExternalCarrierImage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            )
          : null,
    );
  }
}

/// 导出编码（JSON / Base64）选项卡片
class VibeExportEncodingOptionCard extends StatelessWidget {
  const VibeExportEncodingOptionCard({
    super.key,
    required this.isSelected,
    required this.encodingAsJson,
    required this.onToggle,
    required this.onFormatChanged,
  });

  final bool isSelected;
  final bool encodingAsJson;
  final VoidCallback onToggle;
  final ValueChanged<bool> onFormatChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VibeExportOptionCard(
      isSelected: isSelected,
      onTap: onToggle,
      icon: Icons.code,
      title: context.l10n.vibe_export_exportAsEncodings,
      subtitle: context.l10n.vibe_export_exportAsEncodingsDescription,
      child: isSelected
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // 编码格式选择
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('JSON'),
                      icon: Icon(Icons.data_object),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Base64'),
                      icon: Icon(Icons.text_fields),
                    ),
                  ],
                  selected: {encodingAsJson},
                  onSelectionChanged: (value) => onFormatChanged(value.first),
                ),
                const SizedBox(height: 8),
                Text(
                  encodingAsJson
                      ? context.l10n.vibe_export_jsonDescription
                      : context.l10n.vibe_export_base64Description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
