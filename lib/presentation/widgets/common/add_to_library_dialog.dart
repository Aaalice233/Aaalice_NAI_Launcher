import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/app_logger.dart';
import 'app_toast.dart';

/// 添加到词库对话框
///
/// 用于将提示词内容添加到本地词库
class AddToLibraryDialog extends ConsumerStatefulWidget {
  /// 要添加的内容
  final String content;

  /// 默认显示名称（可选）
  final String? defaultName;

  /// 来源标签（可选，用于分类）
  final String? sourceTag;

  const AddToLibraryDialog({
    super.key,
    required this.content,
    this.defaultName,
    this.sourceTag,
  });

  /// 显示对话框
  static Future<bool> show(
    BuildContext context, {
    required String content,
    String? defaultName,
    String? sourceTag,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddToLibraryDialog(
        content: content,
        defaultName: defaultName,
        sourceTag: sourceTag,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AddToLibraryDialog> createState() => _AddToLibraryDialogState();
}

class _AddToLibraryDialogState extends ConsumerState<AddToLibraryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagController;

  String? _selectedCategoryId;
  final List<String> _tags = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 生成默认名称（使用内容前几个词）
    final defaultName = widget.defaultName ?? _generateDefaultName(widget.content);
    _nameController = TextEditingController(text: defaultName);
    _contentController = TextEditingController(text: widget.content);
    _tagController = TextEditingController();

    // 如果有来源标签，添加到标签列表
    if (widget.sourceTag != null) {
      _tags.add(widget.sourceTag!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  /// 生成默认名称（使用内容前15个字符）
  String _generateDefaultName(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    // 截取前15个字符或第一个逗号前的内容
    final firstComma = trimmed.indexOf(',');
    if (firstComma > 0 && firstComma < 20) {
      return trimmed.substring(0, firstComma).trim();
    }
    if (trimmed.length > 15) {
      return '${trimmed.substring(0, 15)}...';
    }
    return trimmed;
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      AppToast.warning(context, '内容不能为空');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // TODO: 接入 TagLibraryProvider
      // 临时记录日志
      AppLogger.i(
        'Add to library: name=$name, content=${content.substring(0, content.length.clamp(0, 50))}..., '
        'categoryId=$_selectedCategoryId, tags=$_tags',
        'AddToLibraryDialog',
      );

      // 模拟保存
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        AppToast.info(context, '添加到词库功能即将推出');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '添加失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.library_add, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('添加到词库'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 内容预览
              Text(
                '内容预览',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                ),
                child: Text(
                  widget.content,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),

              // 显示名称
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '显示名称（可选）',
                  hintText: '输入名称以便识别',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _nameController.clear(),
                    tooltip: '清除',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 目标分类
              DropdownButtonFormField<String?>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: '目标分类',
                  prefixIcon: Icon(Icons.folder_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: null,
                    child: Text('未分类'),
                  ),
                  // TODO: 从 TagLibraryProvider 获取分类列表
                  // DropdownMenuItem(value: 'category_id', child: Text('分类名称')),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              ),
              const SizedBox(height: 16),

              // 标签
              TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: '添加标签',
                  hintText: '输入标签后按回车添加',
                  prefixIcon: const Icon(Icons.tag),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addTag,
                    tooltip: '添加标签',
                  ),
                ),
                onSubmitted: (_) => _addTag(),
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tags.map((tag) => Chip(
                    label: Text(tag, style: theme.textTheme.bodySmall),
                    deleteIcon: const Icon(Icons.clear, size: 16),
                    onDeleted: () => _removeTag(tag),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(_isSaving ? '保存中...' : l10n.common_save),
        ),
      ],
    );
  }
}
