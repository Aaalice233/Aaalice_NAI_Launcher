import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
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
      builder: (context) =>
          PresetImportDialog(isExport: true, presetToExport: preset),
    );
  }

  @override
  State<PresetImportDialog> createState() => _PresetImportDialogState();
}

class _PresetImportDialogState extends State<PresetImportDialog> {
  final TextEditingController _controller = TextEditingController();
  RandomPreset? _previewPreset;
  String? _error;
  bool _isExportError = false;

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
        _error = e.toString();
        _isExportError = true;
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
        setState(() {
          _previewPreset = null;
          _error = context.l10n.diy_presetJsonRootObject;
          _isExportError = false;
        });
        return;
      }
      final preset = RandomPreset.fromExportJson(jsonMap);
      setState(() {
        _previewPreset = preset;
        _error = null;
        _isExportError = false;
      });
    } catch (e) {
      setState(() {
        _previewPreset = null;
        _error = context.l10n.diy_presetInvalidData(e.toString());
        _isExportError = false;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _controller.text)).then((_) {
      if (mounted) {
        AppToast.success(context, context.l10n.image_copiedToClipboard);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final errorMessage = _error == null
        ? null
        : _isExportError
        ? l10n.diy_presetExportFailed(_error!)
        : _error;

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
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
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
                          colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                          colorScheme.secondaryContainer.withValues(alpha: 0.2),
                        ]
                      : [
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                          colorScheme.secondaryContainer.withValues(alpha: 0.2),
                        ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          (widget.isExport
                                  ? colorScheme.tertiary
                                  : colorScheme.primary)
                              .withValues(alpha: 0.1),
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
                    widget.isExport
                        ? l10n.diy_presetExportTitle
                        : l10n.diy_presetImportTitle,
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
                      backgroundColor: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
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
                                    widget.presetToExport?.name ??
                                        l10n.diy_unknown,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    l10n.diy_presetShareHint,
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
                    ThemedInput(
                      controller: _controller,
                      maxLines: 12,
                      readOnly: widget.isExport,
                      hasError: _error != null,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: widget.isExport
                            ? ''
                            : l10n.diy_presetPasteJsonHint,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.3,
                          ),
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
                                errorMessage,
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
                                  l10n.diy_presetPreview,
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
                              l10n.diy_name,
                              _previewPreset!.name,
                            ),
                            if (_previewPreset!.description != null &&
                                _previewPreset!.description!.isNotEmpty)
                              _buildInfoRow(
                                context,
                                Icons.description_outlined,
                                l10n.diy_description,
                                _previewPreset!.description!,
                              ),
                            _buildInfoRow(
                              context,
                              Icons.category_outlined,
                              l10n.diy_categoryCount,
                              '${_previewPreset!.categories.length}',
                            ),
                            _buildInfoRow(
                              context,
                              Icons.tag,
                              l10n.diy_totalTagCount,
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
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.common_cancel),
                  ),
                  const SizedBox(width: 12),
                  if (widget.isExport)
                    FilledButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l10n.common_copy),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _previewPreset != null
                          ? () => Navigator.pop(context, _previewPreset)
                          : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l10n.common_import),
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
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
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
