import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../providers/tag_library_provider.dart';
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
    final defaultName =
        widget.defaultName ?? _generateDefaultName(widget.content);
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
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      AppToast.warning(context, context.l10n.toast_contentCannotBeEmpty);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 获取 notifier 和当前词库
      final notifier = ref.read(tagLibraryNotifierProvider.notifier);
      final currentLibrary = ref.read(tagLibraryNotifierProvider).library;

      if (currentLibrary == null) {
        throw Exception(context.l10n.toast_libraryNotLoaded);
      }

      // 解析内容（支持逗号分隔的多个标签）
      final tagNames = content
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (tagNames.isEmpty) {
        throw Exception(context.l10n.toast_noValidTagContent);
      }

      // 确定目标分类
      final targetCategory = _selectedCategoryId != null
          ? TagSubCategory.values.firstWhere(
              (c) => c.name == _selectedCategoryId,
              orElse: () => TagSubCategory.other,
            )
          : TagSubCategory.other;

      // 获取当前分类的标签列表
      final currentTags = currentLibrary.getCategory(targetCategory);
      final existingNames = currentTags.map((t) => t.tag.toLowerCase()).toSet();

      // 创建新标签列表（过滤重复）
      final newTags = <WeightedTag>[];
      var addedCount = 0;
      var duplicateCount = 0;

      for (final tagName in tagNames) {
        final normalizedName = tagName.toLowerCase();
        if (existingNames.contains(normalizedName)) {
          duplicateCount++;
          continue;
        }

        final newTag = WeightedTag(
          tag: tagName,
          weight: 5,
          source: TagSource.custom,
        );
        newTags.add(newTag);
        existingNames.add(normalizedName);
        addedCount++;
      }

      if (newTags.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context,
            duplicateCount > 0
                ? context.l10n.toast_allTagsAlreadyExist
                : context.l10n.toast_noAddableTags,
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      // 合并新旧标签
      final updatedTags = [...currentTags, ...newTags];
      final updatedLibrary = currentLibrary.setCategory(
        targetCategory,
        updatedTags,
      );

      // 保存词库
      await notifier.saveLibrary(updatedLibrary);

      AppLogger.i(
        'Added $addedCount tags to library (category: ${targetCategory.name}, '
            'duplicates skipped: $duplicateCount)',
        'AddToLibraryDialog',
      );

      if (mounted) {
        if (duplicateCount > 0) {
          AppToast.success(
            context,
            context.l10n.toast_addedTagsSkippedDuplicates(
              addedCount,
              duplicateCount,
            ),
          );
        } else {
          AppToast.success(context, context.l10n.toast_addedToLibrary);
        }
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to add to library', e, stackTrace);
      if (mounted) {
        AppToast.error(context, context.l10n.toast_addFailed(e.toString()));
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
          Text(l10n.tagLibrary_addToLibrary),
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
                l10n.tagLibrary_contentPreview,
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
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
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
                  labelText: l10n.addGroup_displayNameLabel,
                  hintText: l10n.addToLibrary_displayNameHint,
                  prefixIcon: const Icon(Icons.label_outline),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _nameController.clear(),
                    tooltip: l10n.common_clear,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 目标分类
              Consumer(
                builder: (context, ref, child) {
                  const categories = TagSubCategory.values;

                  return DropdownButtonFormField<String?>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: l10n.addGroup_targetCategoryLabel,
                      prefixIcon: const Icon(Icons.folder_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.tagLibrary_uncategorized),
                      ),
                      ...categories.map((category) {
                        return DropdownMenuItem(
                          value: category.name,
                          child: Text(
                            TagSubCategoryHelper.getDisplayName(
                              category,
                              locale: l10n.localeName,
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // 标签
              TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: l10n.tag_addTag,
                  hintText: l10n.addToLibrary_tagHint,
                  prefixIcon: const Icon(Icons.tag),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addTag,
                    tooltip: l10n.tag_addTag,
                  ),
                ),
                onSubmitted: (_) => _addTag(),
              ),
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag, style: theme.textTheme.bodySmall),
                          deleteIcon: const Icon(Icons.clear, size: 16),
                          onDeleted: () => _removeTag(tag),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
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
          label: Text(_isSaving ? l10n.common_saving : l10n.common_save),
        ),
      ],
    );
  }
}
