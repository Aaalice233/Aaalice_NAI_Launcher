import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/random_preset.dart';
import '../../../data/services/preset_import_service.dart';

/// 预设冲突解决结果
class PresetConflictResult {
  /// 选择的冲突解决策略
  final ConflictResolution resolution;

  /// 重命名后的新名称（仅在 rename 时使用）
  final String? newName;

  /// 是否应用到所有后续冲突（批量导入时）
  final bool applyToAll;

  const PresetConflictResult({
    required this.resolution,
    this.newName,
    this.applyToAll = false,
  });
}

/// 预设冲突解决对话框
///
/// 用于在导入预设时检测到名称冲突时让用户选择解决方式：
/// - 跳过：不导入此预设
/// - 替换：用新预设替换现有预设
/// - 重命名：为新预设指定不同的名称
class PresetConflictDialog extends StatefulWidget {
  /// 导入的预设（新预设）
  final RandomPreset importingPreset;

  /// 现有的预设（冲突的预设）
  final RandomPreset existingPreset;

  /// 源文件名
  final String sourceFileName;

  /// 是否批量导入模式
  final bool isBatchImport;

  const PresetConflictDialog({
    super.key,
    required this.importingPreset,
    required this.existingPreset,
    required this.sourceFileName,
    this.isBatchImport = false,
  });

  /// 显示对话框的便捷方法
  static Future<PresetConflictResult?> show({
    required BuildContext context,
    required RandomPreset importingPreset,
    required RandomPreset existingPreset,
    required String sourceFileName,
    bool isBatchImport = false,
  }) {
    return showDialog<PresetConflictResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PresetConflictDialog(
        importingPreset: importingPreset,
        existingPreset: existingPreset,
        sourceFileName: sourceFileName,
        isBatchImport: isBatchImport,
      ),
    );
  }

  @override
  State<PresetConflictDialog> createState() => _PresetConflictDialogState();
}

class _PresetConflictDialogState extends State<PresetConflictDialog> {
  /// 当前选择的解决策略
  ConflictResolution _selectedResolution = ConflictResolution.rename;

  /// 重命名输入控制器
  late final TextEditingController _renameController;

  /// 重命名输入焦点节点
  late final FocusNode _renameFocusNode;

  /// 是否应用到所有
  bool _applyToAll = false;

  /// 重命名错误提示
  String? _renameError;

  @override
  void initState() {
    super.initState();
    // 生成默认的重命名建议
    final suggestedName = _generateRenameSuggestion(widget.importingPreset.name);
    _renameController = TextEditingController(text: suggestedName);
    _renameFocusNode = FocusNode();

    AppLogger.d(
      'PresetConflictDialog 初始化，冲突预设: ${widget.importingPreset.name}',
      'PresetConflictDialog',
    );
  }

  @override
  void dispose() {
    _renameController.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  /// 生成重命名建议
  String _generateRenameSuggestion(String baseName) {
    return '$baseName (新)';
  }

  /// 确认解决
  void _confirm() {
    // 如果选择了重命名，验证名称
    if (_selectedResolution == ConflictResolution.rename) {
      final newName = _renameController.text.trim();
      if (newName.isEmpty) {
        setState(() => _renameError = '名称不能为空');
        return;
      }
      if (newName.toLowerCase() == widget.existingPreset.name.toLowerCase()) {
        setState(() => _renameError = '名称不能与现有预设相同');
        return;
      }

      AppLogger.i(
        '预设冲突解决: rename to "$newName", applyToAll=$_applyToAll',
        'PresetConflictDialog',
      );

      Navigator.of(context).pop(PresetConflictResult(
        resolution: ConflictResolution.rename,
        newName: newName,
        applyToAll: _applyToAll,
      ));
      return;
    }

    AppLogger.i(
      '预设冲突解决: ${_selectedResolution.name}, applyToAll=$_applyToAll',
      'PresetConflictDialog',
    );

    Navigator.of(context).pop(PresetConflictResult(
      resolution: _selectedResolution,
      applyToAll: _applyToAll,
    ));
  }

  /// 跳过此预设
  void _skip() {
    AppLogger.i('跳过预设导入: ${widget.importingPreset.name}', 'PresetConflictDialog');
    Navigator.of(context).pop(PresetConflictResult(
      resolution: ConflictResolution.skip,
      applyToAll: _applyToAll,
    ));
  }

  /// 处理键盘事件
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      _confirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 480,
            minWidth: 360,
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

                // 冲突信息
                _buildConflictInfo(theme),
                const SizedBox(height: 24),

                // 解决选项
                _buildResolutionOptions(theme),
                const SizedBox(height: 24),

                // 批量导入选项
                if (widget.isBatchImport) ...[
                  _buildBatchOptions(theme),
                  const SizedBox(height: 20),
                ],

                // 底部按钮
                _buildFooter(theme),
              ],
            ),
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
          Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '预设名称冲突',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建冲突信息
  Widget _buildConflictInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 冲突说明
          Text(
            '以下预设名称发生冲突：',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // 现有预设
          _buildPresetInfoTile(
            theme,
            icon: Icons.folder,
            iconColor: theme.colorScheme.primary,
            label: '现有预设',
            preset: widget.existingPreset,
          ),

          const SizedBox(height: 8),

          // 分隔线
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_downward,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
              ),
              Expanded(
                child: Divider(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 导入的预设
          _buildPresetInfoTile(
            theme,
            icon: Icons.folder_outlined,
            iconColor: theme.colorScheme.secondary,
            label: '导入预设',
            preset: widget.importingPreset,
            sourceFile: widget.sourceFileName,
          ),
        ],
      ),
    );
  }

  /// 构建预设信息项
  Widget _buildPresetInfoTile(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required RandomPreset preset,
    String? sourceFile,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (preset.isDefault) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Colors.amber,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                preset.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${preset.categoryCount} 类别 · ${preset.totalTagCount} 标签',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (sourceFile != null)
                Text(
                  '来源: $sourceFile',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建解决选项
  Widget _buildResolutionOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择解决方式',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // 重命名选项
        _buildResolutionTile(
          theme,
          value: ConflictResolution.rename,
          icon: Icons.edit,
          title: '重命名导入的预设',
          subtitle: '为新预设指定一个不同的名称',
          showExtra: _selectedResolution == ConflictResolution.rename,
          extra: _buildRenameInput(theme),
        ),

        const SizedBox(height: 8),

        // 替换选项
        _buildResolutionTile(
          theme,
          value: ConflictResolution.replace,
          icon: Icons.swap_horiz,
          title: '替换现有预设',
          subtitle: '用新预设覆盖现有预设的设置',
        ),

        const SizedBox(height: 8),

        // 跳过选项
        _buildResolutionTile(
          theme,
          value: ConflictResolution.skip,
          icon: Icons.skip_next,
          title: '跳过此预设',
          subtitle: '不导入此预设，保留现有预设',
        ),
      ],
    );
  }

  /// 构建解决选项卡片
  Widget _buildResolutionTile(
    ThemeData theme, {
    required ConflictResolution value,
    required IconData icon,
    required String title,
    required String subtitle,
    bool showExtra = false,
    Widget? extra,
  }) {
    final isSelected = _selectedResolution == value;

    return InkWell(
      onTap: () => setState(() => _selectedResolution = value),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Radio<ConflictResolution>(
                  value: value,
                  groupValue: _selectedResolution,
                  onChanged: (selected) {
                    setState(() => _selectedResolution = selected!);
                  },
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: 22,
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
            if (showExtra && extra != null) ...[
              const SizedBox(height: 12),
              extra,
            ],
          ],
        ),
      ),
    );
  }

  /// 构建重命名输入框
  Widget _buildRenameInput(ThemeData theme) {
    return TextField(
      controller: _renameController,
      focusNode: _renameFocusNode,
      decoration: InputDecoration(
        labelText: '新名称',
        hintText: '输入新的预设名称',
        errorText: _renameError,
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _confirm(),
      onChanged: (value) {
        if (_renameError != null) {
          setState(() => _renameError = null);
        }
      },
    );
  }

  /// 构建批量导入选项
  Widget _buildBatchOptions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.batch_prediction,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '应用到后续所有冲突',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '使用此解决方式处理剩余的名称冲突',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: _applyToAll,
            onChanged: (value) {
              setState(() => _applyToAll = value ?? false);
              AppLogger.d(
                '批量导入选项改变: applyToAll=$_applyToAll',
                'PresetConflictDialog',
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 跳过按钮
        TextButton.icon(
          onPressed: _skip,
          icon: const Icon(Icons.skip_next),
          label: const Text('跳过'),
        ),
        const SizedBox(width: 8),

        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
        const SizedBox(width: 8),

        // 确认按钮
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.check),
          label: const Text('确认'),
        ),
      ],
    );
  }
}
