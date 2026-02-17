import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../utils/queue_export_utils.dart';
import '../../providers/replication_queue_provider.dart';

/// 队列导出/导入对话框
class QueueExportDialog extends ConsumerStatefulWidget {
  /// 是否为导入模式
  final bool isImport;

  const QueueExportDialog({
    super.key,
    this.isImport = false,
  });

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
                    '导入/导出队列',
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
              tabs: const [
                Tab(text: '导出'),
                Tab(text: '导入'),
              ],
            ),

            // Tab 内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExportTab(),
                  _buildImportTab(),
                ],
              ),
            ),

            // 错误提示
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
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
    final queueState = ref.watch(replicationQueueNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择导出格式',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),

          // 格式选择
          ...ExportFormat.values.map(
            (format) => RadioListTile<ExportFormat>(
              title: Text(format.displayName),
              subtitle: Text(_getFormatDescription(format)),
              value: format,
              groupValue: _exportFormat,
              onChanged: (value) => setState(() => _exportFormat = value!),
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
                Text('当前队列包含 ${queueState.count} 个任务'),
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
              label: const Text('导出'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '导入策略',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),

          // 策略选择
          ...ImportStrategy.values.map(
            (strategy) => RadioListTile<ImportStrategy>(
              title: Text(strategy.displayName),
              subtitle: Text(strategy.description),
              value: strategy,
              groupValue: _importStrategy,
              onChanged: (value) => setState(() => _importStrategy = value!),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('支持的格式:', style: TextStyle(fontWeight: FontWeight.w500)),
                SizedBox(height: 4),
                Text('• JSON 文件 (.json)'),
                Text('• CSV 文件 (.csv)'),
                Text('• 纯文本文件 (.txt) - 每行一个提示词'),
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
              label: const Text('选择文件导入'),
            ),
          ),
        ],
      ),
    );
  }

  String _getFormatDescription(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return '完整数据，包含所有参数';
      case ExportFormat.csv:
        return '表格格式，包含提示词和基本信息';
      case ExportFormat.text:
        return '仅提示词，每行一个';
    }
  }

  Future<void> _export() async {
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
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '队列导出',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功')),
        );
      }
    } catch (e) {
      setState(() => _error = '导出失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'txt'],
      );

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
          throw FormatException('不支持的文件格式: $extension');
      }

      if (tasks.isEmpty) {
        throw const FormatException('文件中没有有效的任务');
      }

      final queueNotifier = ref.read(replicationQueueNotifierProvider.notifier);

      if (_importStrategy == ImportStrategy.replace) {
        await queueNotifier.clear();
      }

      final added = await queueNotifier.addAll(tasks.cast());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $added 个任务')),
        );
      }
    } catch (e) {
      setState(() => _error = '导入失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
