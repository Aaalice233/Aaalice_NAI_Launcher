import 'package:flutter/material.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/prompt/random_preset.dart';

/// 预设导入选项枚举
enum PresetImportOption {
  /// 作为整体导入（默认）- 保持 bundle 结构
  keepAsBundle,

  /// 拆分为独立条目 - 将每个预设作为独立条目导入
  split,

  /// 只导入选中的预设
  importSelected,
}

/// 预设文件导入结果
class PresetImportFileResult {
  /// 导入选项
  final PresetImportOption option;

  /// 选中的预设索引列表（importSelected 时使用）
  final List<int>? selectedIndices;

  const PresetImportFileResult({
    required this.option,
    this.selectedIndices,
  });
}

/// 预设文件导入选项对话框
///
/// 用于在导入预设文件时让用户选择导入方式：
/// - 作为整体导入：保持 bundle 结构，作为一个条目导入
/// - 拆分为独立条目：将 bundle 中的每个预设作为独立条目导入
/// - 选择要导入的预设：只导入用户选中的部分预设
class PresetImportFileDialog extends StatefulWidget {
  /// Bundle 文件名
  final String fileName;

  /// Bundle 内部预设列表
  final List<RandomPreset> presets;

  /// Bundle 创建时间（可选）
  final DateTime? createdAt;

  /// Bundle 中的预设数量
  int get presetCount => presets.length;

  const PresetImportFileDialog({
    super.key,
    required this.fileName,
    required this.presets,
    this.createdAt,
  });

  /// 显示对话框的便捷方法
  static Future<PresetImportFileResult?> show({
    required BuildContext context,
    required String fileName,
    required List<RandomPreset> presets,
    DateTime? createdAt,
  }) {
    return showDialog<PresetImportFileResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PresetImportFileDialog(
        fileName: fileName,
        presets: presets,
        createdAt: createdAt,
      ),
    );
  }

  @override
  State<PresetImportFileDialog> createState() => _PresetImportFileDialogState();
}

class _PresetImportFileDialogState extends State<PresetImportFileDialog> {
  /// 当前选中的导入选项
  PresetImportOption _selectedOption = PresetImportOption.keepAsBundle;

  /// 选中的预设索引集合（importSelected 时使用）
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // 默认全选所有预设
    _selectedIndices.addAll(
      List.generate(widget.presetCount, (index) => index),
    );
    AppLogger.d(
      'PresetImportFileDialog 初始化，file: ${widget.fileName}, '
      'presets: ${widget.presetCount}',
      'PresetImportFileDialog',
    );
  }

  /// 确认导入
  void _confirm() {
    final result = PresetImportFileResult(
      option: _selectedOption,
      selectedIndices: _selectedOption == PresetImportOption.importSelected
          ? (_selectedIndices.toList()..sort())
          : null,
    );

    AppLogger.i(
      '预设导入确认: option=${_selectedOption.name}, '
      'selectedCount=${result.selectedIndices?.length ?? "N/A"}',
      'PresetImportFileDialog',
    );

    Navigator.of(context).pop(result);
  }

  /// 取消导入
  void _cancel() {
    AppLogger.i('预设导入取消', 'PresetImportFileDialog');
    Navigator.of(context).pop();
  }

  /// 切换预设选择状态
  void _togglePresetSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
    AppLogger.d(
      '预设选择改变: index=$index, selected=${_selectedIndices.contains(index)}',
      'PresetImportFileDialog',
    );
  }

  /// 全选所有预设
  void _selectAll() {
    setState(() {
      _selectedIndices.addAll(
        List.generate(widget.presetCount, (index) => index),
      );
    });
  }

  /// 取消全选
  void _selectNone() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          minWidth: 400,
          maxHeight: 700,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              _buildHeader(theme),
              const SizedBox(height: 20),

              // 文件信息
              _buildFileInfo(theme),
              const SizedBox(height: 20),

              // 导入选项
              _buildImportOptions(theme),

              // 选择列表（仅在选择"选择要导入的预设"时显示）
              if (_selectedOption == PresetImportOption.importSelected) ...[
                const SizedBox(height: 16),
                _buildSelectionHeader(theme),
                const SizedBox(height: 12),
                Flexible(
                  child: _buildPresetSelectionList(theme),
                ),
              ],

              const SizedBox(height: 20),

              // 底部按钮
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.folder_zip,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '导入预设 Bundle',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancel,
          tooltip: '取消',
        ),
      ],
    );
  }

  /// 构建文件信息卡片
  Widget _buildFileInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.fileName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                theme,
                icon: Icons.folder_outlined,
                label: '${widget.presetCount} 个预设',
              ),
              const SizedBox(width: 12),
              if (widget.createdAt != null)
                _buildInfoChip(
                  theme,
                  icon: Icons.calendar_today,
                  label: _formatDate(widget.createdAt!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建信息标签
  Widget _buildInfoChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 构建导入选项区域
  Widget _buildImportOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择导入方式',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          theme,
          option: PresetImportOption.keepAsBundle,
          icon: Icons.folder_zip,
          title: '作为整体导入',
          subtitle: '保持 bundle 结构，作为一个条目导入库中',
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          theme,
          option: PresetImportOption.split,
          icon: Icons.splitscreen,
          title: '拆分为独立条目',
          subtitle: '将每个预设作为独立的库条目导入',
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          theme,
          option: PresetImportOption.importSelected,
          icon: Icons.checklist,
          title: '选择要导入的预设',
          subtitle: '只导入您选中的部分预设',
        ),
      ],
    );
  }

  /// 构建选项卡片
  Widget _buildOptionTile(
    ThemeData theme, {
    required PresetImportOption option,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedOption == option;

    return InkWell(
      onTap: () => setState(() => _selectedOption = option),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
        child: Row(
          children: [
            Radio<PresetImportOption>(
              value: option,
              groupValue: _selectedOption,
              onChanged: (value) {
                setState(() => _selectedOption = value!);
              },
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

  /// 构建选择列表头部
  Widget _buildSelectionHeader(ThemeData theme) {
    final allSelected = _selectedIndices.length == widget.presetCount;
    final noneSelected = _selectedIndices.isEmpty;

    return Row(
      children: [
        Text(
          '选择要导入的预设',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: allSelected ? null : _selectAll,
          child: const Text('全选'),
        ),
        TextButton(
          onPressed: noneSelected ? null : _selectNone,
          child: const Text('全不选'),
        ),
      ],
    );
  }

  /// 构建预设选择列表
  Widget _buildPresetSelectionList(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: widget.presetCount,
      itemBuilder: (context, index) {
        final preset = widget.presets[index];
        final isSelected = _selectedIndices.contains(index);

        return _buildPresetTile(
          theme,
          index: index,
          preset: preset,
          isSelected: isSelected,
        );
      },
    );
  }

  /// 构建单个预设列表项
  Widget _buildPresetTile(
    ThemeData theme, {
    required int index,
    required RandomPreset preset,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _togglePresetSelection(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withOpacity(0.6),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.25)
                : theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              // 选择框
              Checkbox(
                value: isSelected,
                onChanged: (_) => _togglePresetSelection(index),
              ),
              const SizedBox(width: 8),
              // 预设图标
              Icon(
                preset.isDefault ? Icons.star : Icons.folder_outlined,
                size: 24,
                color: preset.isDefault
                    ? Colors.amber
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              // 预设信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${preset.categoryCount} 类别 · ${preset.totalTagCount} 标签',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // 选中标记
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildFooter(ThemeData theme) {
    final bool canConfirm = _selectedOption != PresetImportOption.importSelected ||
        _selectedIndices.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 选中数量提示（仅在选择模式下显示）
        if (_selectedOption == PresetImportOption.importSelected) ...[
          Text(
            '已选择 ${_selectedIndices.length}/${widget.presetCount} 个',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 16),
        ],
        // 取消按钮
        TextButton(
          onPressed: _cancel,
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        // 确认按钮
        FilledButton.icon(
          onPressed: canConfirm ? _confirm : null,
          icon: const Icon(Icons.download),
          label: const Text('导入'),
        ),
      ],
    );
  }
}
