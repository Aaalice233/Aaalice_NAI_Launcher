import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';

/// 选择导出的 ZIP 是否保留图片元数据。
class ZipExportMetadataDialog extends StatefulWidget {
  const ZipExportMetadataDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const ZipExportMetadataDialog(),
    );
  }

  @override
  State<ZipExportMetadataDialog> createState() =>
      _ZipExportMetadataDialogState();
}

class _ZipExportMetadataDialogState extends State<ZipExportMetadataDialog> {
  bool _includeMetadata = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      icon: const Icon(Icons.folder_zip_outlined),
      title: Text(l10n.localGallery_zipMetadataTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.localGallery_zipMetadataDescription),
            const SizedBox(height: 16),
            RadioGroup<bool>(
              groupValue: _includeMetadata,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _includeMetadata = value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<bool>(
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.localGallery_zipIncludeMetadata),
                    subtitle: Text(
                      l10n.localGallery_zipIncludeMetadataDescription,
                    ),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.localGallery_zipExcludeMetadata),
                    subtitle: Text(
                      l10n.localGallery_zipExcludeMetadataDescription,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_includeMetadata),
          icon: const Icon(Icons.archive_outlined),
          label: Text(l10n.common_export),
        ),
      ],
    );
  }
}
