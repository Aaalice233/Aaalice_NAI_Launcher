import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/content_sized_adaptive_form.dart';

/// 选择导出的 ZIP 是否保留图片元数据。
class ZipExportMetadataDialog extends StatefulWidget {
  const ZipExportMetadataDialog({super.key, this.scrollController});

  final ScrollController? scrollController;

  static Future<bool?> show(BuildContext context) {
    return AdaptivePresenter.showForm<bool>(
      context: context,
      title: context.l10n.localGallery_zipMetadataTitle,
      dialogWidth: 520,
      builder: (panelContext, scrollController) =>
          ZipExportMetadataDialog(scrollController: scrollController),
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

    return ContentSizedAdaptiveForm(
      scrollViewKey: const ValueKey('zip-export-metadata-options'),
      scrollController: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      content: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.folder_zip_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.localGallery_zipMetadataDescription)),
          ],
        ),
        const SizedBox(height: 16),
        RadioGroup<bool>(
          groupValue: _includeMetadata,
          onChanged: (value) {
            if (value != null) setState(() => _includeMetadata = value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<bool>(
                value: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.localGallery_zipIncludeMetadata),
                subtitle: Text(l10n.localGallery_zipIncludeMetadataDescription),
              ),
              RadioListTile<bool>(
                value: false,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.localGallery_zipExcludeMetadata),
                subtitle: Text(l10n.localGallery_zipExcludeMetadataDescription),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SafeArea(
          top: false,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
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
          ),
        ),
      ],
    );
  }
}
