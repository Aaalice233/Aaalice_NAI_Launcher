import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/app_logger.dart';

/// Vibe 导入命名结果
class VibeImportResult {
  /// 用户输入的名称
  final String name;

  /// 是否应用到后续所有文件（批量导入时）
  final bool applyToAll;

  const VibeImportResult({
    required this.name,
    this.applyToAll = false,
  });
}

/// Vibe 导入命名对话框
///
/// 用于在导入 Vibe 时让用户确认或修改名称
/// 支持单文件导入和批量导入模式
class VibeImportNamingDialog extends StatefulWidget {
  /// 建议名称（来自文件名）
  final String suggestedName;

  /// 预览缩略图（可选）
  final Uint8List? thumbnail;

  /// 是否批量导入模式
  final bool isBatchImport;

  /// 是否存在名称冲突
  final bool hasNameConflict;

  const VibeImportNamingDialog({
    super.key,
    required this.suggestedName,
    this.thumbnail,
    this.isBatchImport = false,
    this.hasNameConflict = false,
  });

  /// 显示对话框的便捷方法
  static Future<VibeImportResult?> show({
    required BuildContext context,
    required String suggestedName,
    Uint8List? thumbnail,
    bool isBatchImport = false,
    bool hasNameConflict = false,
  }) {
    return showDialog<VibeImportResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VibeImportNamingDialog(
        suggestedName: suggestedName,
        thumbnail: thumbnail,
        isBatchImport: isBatchImport,
        hasNameConflict: hasNameConflict,
      ),
    );
  }

  @override
  State<VibeImportNamingDialog> createState() => _VibeImportNamingDialogState();
}

class _VibeImportNamingDialogState extends State<VibeImportNamingDialog> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  bool _applyToAll = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.suggestedName);
    _nameFocusNode = FocusNode();

    // 延迟聚焦和全选，确保渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });

    AppLogger.d(
      'VibeImportNamingDialog 初始化，建议名称: ${widget.suggestedName}',
      'VibeImportNamingDialog',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  /// 验证名称
  bool _validateName(String name) {
    if (name.trim().isEmpty) {
      setState(() => _errorText = '名称不能为空');
      return false;
    }
    setState(() => _errorText = null);
    return true;
  }

  /// 确认导入
  void _confirm() {
    final name = _nameController.text.trim();
    if (!_validateName(name)) {
      return;
    }

    AppLogger.i(
      'Vibe 导入确认: name=$name, applyToAll=$_applyToAll',
      'VibeImportNamingDialog',
    );

    Navigator.of(context).pop(
      VibeImportResult(
        name: name,
        applyToAll: _applyToAll,
      ),
    );
  }

  /// 跳过当前文件
  void _skip() {
    AppLogger.i('跳过当前 Vibe 导入', 'VibeImportNamingDialog');
    Navigator.of(context).pop(null);
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
            maxWidth: 400,
            minWidth: 320,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                _buildHeader(theme),
                const SizedBox(height: 24),

                // 缩略图预览
                if (widget.thumbnail != null) ...[
                  _buildThumbnailPreview(theme),
                  const SizedBox(height: 24),
                ],

                // 名称输入框
                _buildNameInput(theme),
                const SizedBox(height: 16),

                // 批量导入选项
                if (widget.isBatchImport) ...[
                  _buildBatchOptions(theme),
                  const SizedBox(height: 16),
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
          Icons.edit_note,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '命名 Vibe',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.hasNameConflict)
          Tooltip(
            message: '该名称已存在，将被覆盖',
            child: Icon(
              Icons.warning_amber,
              color: theme.colorScheme.error,
              size: 20,
            ),
          ),
      ],
    );
  }

  /// 构建缩略图预览
  Widget _buildThumbnailPreview(ThemeData theme) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          widget.thumbnail!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            AppLogger.w(
              '缩略图加载失败: $error',
              'VibeImportNamingDialog',
            );
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  '预览加载失败',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建名称输入框
  Widget _buildNameInput(ThemeData theme) {
    return TextField(
      controller: _nameController,
      focusNode: _nameFocusNode,
      decoration: InputDecoration(
        labelText: '名称',
        hintText: '输入 Vibe 名称',
        errorText: _errorText,
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _confirm(),
      onChanged: (value) {
        if (_errorText != null) {
          setState(() => _errorText = null);
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
                  '应用到后续所有文件',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '使用此命名规则处理剩余文件',
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
                'VibeImportNamingDialog',
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
        // 跳过按钮（仅批量导入时显示）
        if (widget.isBatchImport) ...[
          TextButton.icon(
            onPressed: _skip,
            icon: const Icon(Icons.skip_next),
            label: Text(context.l10n.vibe_import_skip),
          ),
          const SizedBox(width: 8),
        ],
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
          label: Text(context.l10n.vibe_import_confirm),
        ),
      ],
    );
  }
}
