import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 预设导入/导出弹窗
///
/// 用于导出预设为 JSON 文本或从 JSON 文本导入预设
class PresetImportDialog extends StatefulWidget {
  /// 是否为导出模式
  final bool isExport;

  /// 要导出的预设（仅导出模式需要）
  final RandomPreset? presetToExport;

  const PresetImportDialog({
    super.key,
    required this.isExport,
    this.presetToExport,
  });

  /// 显示导入弹窗
  static Future<RandomPreset?> showImport(BuildContext context) {
    return showDialog<RandomPreset>(
      context: context,
      builder: (context) => const PresetImportDialog(isExport: false),
    );
  }

  /// 显示导出弹窗
  static Future<void> showExport(BuildContext context, RandomPreset preset) {
    return showDialog(
      context: context,
      builder: (context) => PresetImportDialog(
        isExport: true,
        presetToExport: preset,
      ),
    );
  }

  @override
  State<PresetImportDialog> createState() => _PresetImportDialogState();
}

class _PresetImportDialogState extends State<PresetImportDialog> {
  final TextEditingController _controller = TextEditingController();
  RandomPreset? _previewPreset;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isExport && widget.presetToExport != null) {
      try {
        final jsonMap = widget.presetToExport!.toExportJson();
        // 使用带缩进的编码器，方便阅读
        const encoder = JsonEncoder.withIndent('  ');
        _controller.text = encoder.convert(jsonMap);
      } catch (e) {
        _error = '导出失败: $e';
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    if (widget.isExport) return;

    if (value.trim().isEmpty) {
      setState(() {
        _previewPreset = null;
        _error = null;
      });
      return;
    }

    try {
      final jsonMap = jsonDecode(value);
      if (jsonMap is! Map<String, dynamic>) {
        throw const FormatException('JSON 根节点必须是对象');
      }
      final preset = RandomPreset.fromExportJson(jsonMap);
      setState(() {
        _previewPreset = preset;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _previewPreset = null;
        _error = '无效的预设数据: ${e.toString()}';
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _controller.text)).then((_) {
      if (mounted) {
        AppToast.success(context, '已复制到剪贴板');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.isExport ? Icons.upload : Icons.download),
          const SizedBox(width: 8),
          Text(widget.isExport ? '导出预设' : '导入预设'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isExport) ...[
                Text(
                  '预设: ${widget.presetToExport?.name ?? "未知"}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '复制以下内容分享给其他人：',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
              ],
              ThemedInput(
                controller: _controller,
                maxLines: 10,
                readOnly: widget.isExport,
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: widget.isExport ? '' : '在此粘贴预设 JSON 数据...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  errorText: _error,
                  errorMaxLines: 3,
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              if (!widget.isExport && _previewPreset != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '预设预览',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const ThemedDivider(),
                        _buildInfoRow('名称', _previewPreset!.name),
                        if (_previewPreset!.description != null &&
                            _previewPreset!.description!.isNotEmpty)
                          _buildInfoRow('描述', _previewPreset!.description!),
                        _buildInfoRow(
                          '类别数',
                          '${_previewPreset!.categories.length}',
                        ),
                        _buildInfoRow(
                          '总标签数',
                          '${_previewPreset!.totalTagCount}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        if (widget.isExport)
          FilledButton.icon(
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.copy),
            label: const Text('复制'),
          )
        else
          FilledButton.icon(
            onPressed: _previewPreset != null
                ? () => Navigator.pop(context, _previewPreset)
                : null,
            icon: const Icon(Icons.check),
            label: const Text('导入'),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
