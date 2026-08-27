import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../utils/queue_export_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../common/app_toast.dart';

/// 队列导出/导入对话框
class QueueExportDialog extends ConsumerStatefulWidget {
  /// 是否为导入模式
  final bool isImport;

  const QueueExportDialog({super.key, this.isImport = false});

  @override
  ConsumerState<QueueExportDialog> createState() => _QueueExportDialogState();
}

class _QueueExportDialogState extends ConsumerState<QueueExportDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ExportFormat _exportFormat = ExportFormat.json;
  ImportStrategy _importStrategy = ImportStrategy.merge;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.isImport ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.import_export),
                  const SizedBox(width: 8),
                  Text(
                    l10n.queue_exportImport,
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab 栏
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: l10n.queue_export),
                Tab(text: l10n.queue_import),
              ],
            ),

            // Tab 内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildExportTab(), _buildImportTab()],
              ),
            ),

            // 错误提示
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportTab() {
    final l10n = context.l10n;
    final queueState = ref.watch(replicationQueueNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.queue_exportFormat,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),

          // 格式选择
          RadioGroup<ExportFormat>(
            groupValue: _exportFormat,
            onChanged: (value) {
              if (value != null) {
                setState(() => _exportFormat = value);
              }
            },
            child: Column(
              children: ExportFormat.values
                  .map(
                    (format) => RadioListTile<ExportFormat>(
                      title: Text(_getFormatDisplayName(format)),
                      subtitle: Text(_getFormatDescription(format)),
                      value: format,
                    ),
                  )
                  .toList(),
            ),
          ),

          const Spacer(),

          // 队列信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Text(l10n.queue_currentQueueInfo(queueState.count)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 导出按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: queueState.isEmpty || _isLoading ? null : _export,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(l10n.queue_export),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.queue_importStrategy,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),

          // 策略选择
          RadioGroup<ImportStrategy>(
            groupValue: _importStrategy,
            onChanged: (value) {
              if (value != null) {
                setState(() => _importStrategy = value);
              }
            },
            child: Column(
              children: ImportStrategy.values
                  .map(
                    (strategy) => RadioListTile<ImportStrategy>(
                      title: Text(_getStrategyDisplayName(strategy)),
                      subtitle: Text(_getStrategyDescription(strategy)),
                      value: strategy,
                    ),
                  )
                  .toList(),
            ),
          ),

          const Spacer(),

          // 支持的格式说明
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.queue_supportedFormats,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(l10n.queue_supportedFormatJson),
                Text(l10n.queue_supportedFormatCsv),
                Text(l10n.queue_supportedFormatText),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 导入按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _import,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(l10n.queue_selectFile),
            ),
          ),
        ],
      ),
    );
  }

  String _getFormatDisplayName(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return context.l10n.queue_exportFormatJson;
      case ExportFormat.csv:
        return context.l10n.queue_exportFormatCsv;
      case ExportFormat.text:
        return context.l10n.queue_exportFormatText;
    }
  }

  String _getFormatDescription(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return context.l10n.queue_exportFormatJsonDesc;
      case ExportFormat.csv:
        return context.l10n.queue_exportFormatCsvDesc;
      case ExportFormat.text:
        return context.l10n.queue_exportFormatTextDesc;
    }
  }

  String _getStrategyDisplayName(ImportStrategy strategy) {
    switch (strategy) {
      case ImportStrategy.merge:
        return context.l10n.queue_importStrategyMerge;
      case ImportStrategy.replace:
        return context.l10n.queue_importStrategyReplace;
    }
  }

  String _getStrategyDescription(ImportStrategy strategy) {
    switch (strategy) {
      case ImportStrategy.merge:
        return context.l10n.queue_importStrategyMergeDesc;
      case ImportStrategy.replace:
        return context.l10n.queue_importStrategyReplaceDesc;
    }
  }

  Future<void> _export() async {
    final l10n = context.l10n;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final queueState = ref.read(replicationQueueNotifierProvider);
      final tasks = queueState.tasks;

      String content;
      switch (_exportFormat) {
        case ExportFormat.json:
          content = QueueExportUtils.exportToJson(tasks);
          break;
        case ExportFormat.csv:
          content = QueueExportUtils.exportToCsv(tasks);
          break;
        case ExportFormat.text:
          content = QueueExportUtils.exportToText(tasks);
          break;
      }

      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'queue_export_$timestamp.${_exportFormat.extension}';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      // 分享文件
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: l10n.queue_shareSubject);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      AppToast.success(context, l10n.queue_exportSuccess);
    } catch (e) {
      if (mounted) {
        setState(() => _error = l10n.queue_exportFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _import() async {
    final l10n = context.l10n;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'txt'],
      );

      if (!mounted) {
        return;
      }

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final extension = result.files.single.extension?.toLowerCase() ?? '';

      List<dynamic> tasks;
      switch (extension) {
        case 'json':
          tasks = QueueExportUtils.importFromJson(content);
          break;
        case 'csv':
          tasks = QueueExportUtils.importFromCsv(content);
          break;
        case 'txt':
          tasks = QueueExportUtils.importFromText(content);
          break;
        default:
          throw FormatException(l10n.queue_unsupportedFileFormat(extension));
      }

      if (tasks.isEmpty) {
        throw FormatException(l10n.queue_noValidTasks);
      }

      final queueNotifier = ref.read(replicationQueueNotifierProvider.notifier);

      if (_importStrategy == ImportStrategy.replace) {
        await ref.read(queueExecutionNotifierProvider.notifier).clearQueue();
      }

      final added = await queueNotifier.addAll(tasks.cast());

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
      AppToast.success(context, l10n.queue_importSuccess(added));
    } catch (e) {
      if (mounted) {
        setState(() => _error = l10n.queue_importFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
