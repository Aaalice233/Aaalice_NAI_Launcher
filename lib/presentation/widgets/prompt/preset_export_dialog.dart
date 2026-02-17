import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/prompt/preset_export_format.dart';
import '../../../data/models/prompt/random_preset.dart';
import '../../../data/services/preset_export_service.dart';

import '../../widgets/common/app_toast.dart';

/// 预设导出对话框
///
/// 支持单选/多选预设导出为不同格式（Bundle/JSON/Encoding）
class PresetExportDialog extends ConsumerStatefulWidget {
  final List<RandomPreset> presets;

  const PresetExportDialog({
    super.key,
    required this.presets,
  });

  /// 显示对话框
  static Future<void> show(BuildContext context, List<RandomPreset> presets) {
    return showDialog<void>(
      context: context,
      builder: (context) => PresetExportDialog(presets: presets),
    );
  }

  @override
  ConsumerState<PresetExportDialog> createState() => _PresetExportDialogState();
}

class _PresetExportDialogState extends ConsumerState<PresetExportDialog> {
  PresetExportFormat _exportFormat = PresetExportFormat.bundle;
  bool _includeFullData = true;
  bool _includePreview = true;
  bool _isExporting = false;
  double _progress = 0;
  String _progressMessage = '';

  // 选中的预设ID
  final Set<String> _selectedPresetIds = {};

  @override
  void initState() {
    super.initState();
    // 默认全选所有预设
    _selectedPresetIds.addAll(widget.presets.map((p) => p.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
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
                    '导出预设',
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

              const SizedBox(height: 16),

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
                // 统计信息
                _buildStatsBar(theme),

                const SizedBox(height: 16),

                // 导出格式选择
                _buildFormatSelection(theme),

                const SizedBox(height: 16),

                // 全选/全不选按钮
                _buildSelectionActions(theme),

                const SizedBox(height: 8),

                // 可滚动的选择列表
                Expanded(child: _buildSelectionList(theme)),

                const Divider(height: 24),

                // 选项
                _buildOptionsSection(theme),

                const SizedBox(height: 16),

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
                      onPressed: _selectedPresetIds.isNotEmpty ? _export : null,
                      icon: const Icon(Icons.file_download),
                      label: Text(
                        '导出 (${_selectedPresetIds.length} 个)',
                      ),
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

  /// 构建统计信息栏
  Widget _buildStatsBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _StatItem(
            label: '已选择',
            value: '${_selectedPresetIds.length}/${widget.presets.length}',
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(width: 24),
          _StatItem(
            label: '导出格式',
            value: _exportFormat.displayName,
            icon: Icons.folder_outlined,
          ),
        ],
      ),
    );
  }

  /// 构建格式选择区域
  Widget _buildFormatSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('导出格式', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...PresetExportFormat.values.map((format) {
          final isSelected = _exportFormat == format;
          final isDisabled =
              format == PresetExportFormat.json && _selectedPresetIds.length > 1;

          return InkWell(
            onTap: isDisabled
                ? null
                : () => setState(() => _exportFormat = format),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : isDisabled
                          ? theme.colorScheme.outlineVariant.withOpacity(0.3)
                          : theme.colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isSelected
                    ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                    : isDisabled
                        ? theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.5)
                        : null,
              ),
              child: Row(
                children: [
                  Radio<PresetExportFormat>(
                    value: format,
                    groupValue: _exportFormat,
                    onChanged: isDisabled
                        ? null
                        : (value) {
                            setState(() => _exportFormat = value!);
                          },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              format.displayName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: isDisabled
                                    ? theme.colorScheme.outline
                                    : null,
                              ),
                            ),
                            if (format == PresetExportFormat.bundle) ...[
                              const SizedBox(width: 8),
                              _FormatBadge(
                                label: '推荐',
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _getFormatDescription(format),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDisabled
                                ? theme.colorScheme.outline.withOpacity(0.6)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        if (isDisabled)
                          Text(
                            'JSON 格式仅支持导出单个预设',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 获取格式描述
  String _getFormatDescription(PresetExportFormat format) {
    switch (format) {
      case PresetExportFormat.bundle:
        return '将多个预设打包为一个文件 (.naiv4presetbundle)，适合批量备份和分享';
      case PresetExportFormat.json:
        return '导出为 JSON 文件，包含完整的预设配置数据';
      case PresetExportFormat.encoding:
        return '导出为 Base64 编码文本，适合与其他系统交换数据';
    }
  }

  /// 构建选择操作按钮
  Widget _buildSelectionActions(ThemeData theme) {
    final allPresetsSelected =
        _selectedPresetIds.length == widget.presets.length;

    return Row(
      children: [
        Text('选择要导出的预设', style: theme.textTheme.titleSmall),
        const Spacer(),
        TextButton.icon(
          onPressed: allPresetsSelected ? null : _selectAll,
          icon: const Icon(Icons.select_all, size: 18),
          label: const Text('全选'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        TextButton.icon(
          onPressed: _selectedPresetIds.isEmpty ? null : _selectNone,
          icon: const Icon(Icons.deselect, size: 18),
          label: const Text('全不选'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  /// 构建选择列表
  Widget _buildSelectionList(ThemeData theme) {
    return ListView.builder(
      itemCount: widget.presets.length,
      itemBuilder: (context, index) {
        final preset = widget.presets[index];
        return _buildPresetTile(preset);
      },
    );
  }

  /// 构建预设项
  Widget _buildPresetTile(RandomPreset preset) {
    final theme = Theme.of(context);
    final isSelected = _selectedPresetIds.contains(preset.id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedPresetIds.remove(preset.id);
          } else {
            _selectedPresetIds.add(preset.id);
          }
          // 如果切换到 JSON 格式且选择了多个，自动切换到 bundle
          if (_exportFormat == PresetExportFormat.json &&
              _selectedPresetIds.length > 1) {
            _exportFormat = PresetExportFormat.bundle;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedPresetIds.add(preset.id);
                    } else {
                      _selectedPresetIds.remove(preset.id);
                    }
                    // 如果切换到 JSON 格式且选择了多个，自动切换到 bundle
                    if (_exportFormat == PresetExportFormat.json &&
                        _selectedPresetIds.length > 1) {
                      _exportFormat = PresetExportFormat.bundle;
                    }
                  });
                },
              ),
            ),
            Icon(
              preset.isDefault ? Icons.star : Icons.folder_outlined,
              size: 20,
              color: preset.isDefault
                  ? Colors.amber
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (preset.description != null &&
                      preset.description!.isNotEmpty)
                    Text(
                      preset.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      '${preset.categoryCount} 类别 · ${preset.totalTagCount} 标签',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建选项区域
  Widget _buildOptionsSection(ThemeData theme) {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('包含完整数据'),
          subtitle: const Text('包含算法配置、类别、标签组等完整配置'),
          value: _includeFullData,
          onChanged: (value) {
            setState(() => _includeFullData = value ?? true);
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        CheckboxListTile(
          title: const Text('包含预览信息'),
          subtitle: const Text('包含类别数量、标签数量等统计信息'),
          value: _includePreview,
          onChanged: (value) {
            setState(() => _includePreview = value ?? true);
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  void _selectAll() {
    setState(() {
      _selectedPresetIds.addAll(widget.presets.map((p) => p.id));
    });
  }

  void _selectNone() {
    setState(() {
      _selectedPresetIds.clear();
    });
  }

  Future<void> _export() async {
    // 过滤选中的预设
    final selectedPresets = widget.presets
        .where((p) => _selectedPresetIds.contains(p.id))
        .toList();

    if (selectedPresets.isEmpty) {
      AppToast.warning(context, '请先选择要导出的预设');
      return;
    }

    // 如果是 JSON 格式，只能选择单个预设
    if (_exportFormat == PresetExportFormat.json &&
        selectedPresets.length > 1) {
      AppToast.warning(context, 'JSON 格式仅支持导出单个预设');
      return;
    }

    // 选择保存位置
    final String? result;
    final fileName = _generateDefaultFileName(selectedPresets);

    if (_exportFormat == PresetExportFormat.bundle) {
      // Bundle 格式选择文件保存位置
      result = await FilePicker.platform.saveFile(
        dialogTitle: '选择保存位置',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [kNaiv4presetbundleExtension],
      );
    } else if (_exportFormat == PresetExportFormat.json) {
      // JSON 格式选择文件保存位置
      result = await FilePicker.platform.saveFile(
        dialogTitle: '选择保存位置',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } else {
      // Encoding 格式选择文件保存位置
      result = await FilePicker.platform.saveFile(
        dialogTitle: '选择保存位置',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
    }

    if (result == null) return;

    setState(() {
      _isExporting = true;
      _progress = 0;
      _progressMessage = '准备导出...';
    });

    try {
      final service = ref.read(presetExportServiceProvider);
      final options = PresetExportOptions(
        format: _exportFormat,
        includeFullData: _includeFullData,
        includePreview: _includePreview,
      );

      String? exportedPath;

      if (selectedPresets.length == 1) {
        // 导出单个预设
        exportedPath = await service.exportSingle(
          selectedPresets.first,
          options: options,
        );
      } else {
        // 导出多个预设
        exportedPath = await service.export(
          selectedPresets,
          options: options,
          onProgress: ({required current, required currentItem, required total}) {
            setState(() {
              _progress = total > 0 ? current / total : 0;
              _progressMessage = '正在导出: $currentItem ($current/$total)';
            });
          },
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        if (exportedPath != null) {
          AppToast.success(context, '导出成功: $exportedPath');
        } else {
          AppToast.error(context, '导出失败');
        }
      }
    } catch (e, stack) {
      AppLogger.e('导出预设失败', e, stack, 'PresetExportDialog');
      if (mounted) {
        setState(() => _isExporting = false);
        AppToast.error(context, '导出失败: $e');
      }
    }
  }

  /// 生成默认文件名
  String _generateDefaultFileName(List<RandomPreset> presets) {
    final timestamp = DateTime.now();
    final formattedTime =
        '${timestamp.year}${_twoDigits(timestamp.month)}${_twoDigits(timestamp.day)}_'
        '${_twoDigits(timestamp.hour)}${_twoDigits(timestamp.minute)}';

    if (presets.length == 1) {
      final preset = presets.first;
      final sanitizedName = _sanitizeFileName(preset.name);
      return '${sanitizedName}_$formattedTime.${_exportFormat.fileExtension}';
    } else {
      return 'preset_bundle_${presets.length}_$formattedTime.${_exportFormat.fileExtension}';
    }
  }

  /// 清理文件名中的非法字符
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 将数字格式化为两位字符串
  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

/// 统计项组件
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 格式标签组件
class _FormatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _FormatBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
