import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import '../../../../widgets/common/app_toast.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/common/elevated_card.dart';

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
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏 - 渐变背景
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isExport
                      ? [
                          colorScheme.tertiaryContainer.withOpacity(0.3),
                          colorScheme.secondaryContainer.withOpacity(0.2),
                        ]
                      : [
                          colorScheme.primaryContainer.withOpacity(0.3),
                          colorScheme.secondaryContainer.withOpacity(0.2),
                        ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (widget.isExport
                              ? colorScheme.tertiary
                              : colorScheme.primary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.isExport
                          ? Icons.upload_rounded
                          : Icons.download_rounded,
                      color: widget.isExport
                          ? colorScheme.tertiary
                          : colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.isExport ? '导出预设' : '导入预设',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.isExport) ...[
                      ElevatedCard(
                        elevation: CardElevation.level1,
                        borderRadius: 10,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.presetToExport?.name ?? "未知",
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '复制以下内容分享给其他人',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // JSON 输入/输出区域
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _error != null
                              ? colorScheme.error.withOpacity(0.5)
                              : colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ThemedInput(
                          controller: _controller,
                          maxLines: 12,
                          readOnly: widget.isExport,
                          onChanged: _onTextChanged,
                          decoration: InputDecoration(
                            hintText:
                                widget.isExport ? '' : '在此粘贴预设 JSON 数据...',
                            border: InputBorder.none,
                            filled: true,
                            fillColor: colorScheme.surfaceContainerLow,
                            contentPadding: const EdgeInsets.all(14),
                          ),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 16,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!widget.isExport && _previewPreset != null) ...[
                      const SizedBox(height: 16),
                      ElevatedCard(
                        elevation: CardElevation.level2,
                        borderRadius: 12,
                        gradientBorder: CardGradients.primary(colorScheme),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.preview,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '预设预览',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              context,
                              Icons.label_outline,
                              '名称',
                              _previewPreset!.name,
                            ),
                            if (_previewPreset!.description != null &&
                                _previewPreset!.description!.isNotEmpty)
                              _buildInfoRow(
                                context,
                                Icons.description_outlined,
                                '描述',
                                _previewPreset!.description!,
                              ),
                            _buildInfoRow(
                              context,
                              Icons.category_outlined,
                              '类别数',
                              '${_previewPreset!.categories.length}',
                            ),
                            _buildInfoRow(
                              context,
                              Icons.tag,
                              '总标签数',
                              '${_previewPreset!.totalTagCount}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  if (widget.isExport)
                    FilledButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _previewPreset != null
                          ? () => Navigator.pop(context, _previewPreset)
                          : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('导入'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
