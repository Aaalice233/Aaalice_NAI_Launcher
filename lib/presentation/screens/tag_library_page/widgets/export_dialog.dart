import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../../data/services/tag_library_io_service.dart';

/// 导出对话框
class ExportDialog extends ConsumerStatefulWidget {
  final List<TagLibraryEntry> entries;
  final List<TagLibraryCategory> categories;

  const ExportDialog({
    super.key,
    required this.entries,
    required this.categories,
  });

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  bool _includeThumbnails = true;
  bool _isExporting = false;
  double _progress = 0;
  String _progressMessage = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.tagLibrary_export,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (!_isExporting)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              if (_isExporting) ...[
                // 导出进度
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 12),
                Text(
                  _progressMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ] else ...[
                // 导出预览
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '导出预览',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: '条目数',
                        value: widget.entries.length.toString(),
                      ),
                      _InfoRow(
                        label: '分类数',
                        value: widget.categories.length.toString(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 选项
                CheckboxListTile(
                  title: const Text('包含预览图'),
                  subtitle: const Text('将增加文件大小'),
                  value: _includeThumbnails,
                  onChanged: (value) {
                    setState(() => _includeThumbnails = value ?? true);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 24),

                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.common_cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _export,
                      icon: const Icon(Icons.file_download),
                      label: const Text('选择保存位置'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    // 选择保存位置
    final result = await FilePicker.platform.saveFile(
      dialogTitle: '选择保存位置',
      fileName: TagLibraryIOService().generateExportFileName(),
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null) return;

    setState(() {
      _isExporting = true;
      _progress = 0;
      _progressMessage = '准备导出...';
    });

    try {
      final service = TagLibraryIOService();
      await service.exportLibrary(
        entries: widget.entries,
        categories: widget.categories,
        includeThumbnails: _includeThumbnails,
        outputPath: result,
        onProgress: (progress, message) {
          setState(() {
            _progress = progress;
            _progressMessage = message;
          });
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.outline)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
