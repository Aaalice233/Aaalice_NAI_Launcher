import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_prompt_parser.dart';
import '../../../data/models/prompt/prompt_tag.dart';
import '../../../data/models/prompt/tag_template.dart';
import '../../providers/tag_template_provider.dart';
import '../common/themed_container.dart';

/// 标签模板面板
///
/// 显示用户保存的标签模板，支持插入模板到提示词、创建和删除模板
class TagTemplatePanel extends ConsumerStatefulWidget {
  /// 当前标签列表
  final List<PromptTag> currentTags;

  /// 标签变化回调
  final ValueChanged<List<PromptTag>> onTagsChanged;

  /// 当前选中的标签（用于创建模板）
  final List<PromptTag> selectedTags;

  /// 是否只读
  final bool readOnly;

  /// 是否紧凑模式
  final bool compact;

  const TagTemplatePanel({
    super.key,
    required this.currentTags,
    required this.onTagsChanged,
    this.selectedTags = const [],
    this.readOnly = false,
    this.compact = false,
  });

  @override
  ConsumerState<TagTemplatePanel> createState() => _TagTemplatePanelState();
}

class _TagTemplatePanelState extends ConsumerState<TagTemplatePanel> {
  /// 插入模板到当前提示词
  void _insertTemplate(TagTemplate template) {
    if (widget.readOnly) return;

    // 获取模板中的所有标签
    final templateTags = template.tags;

    // 将所有标签添加到当前提示词
    var newTags = List<PromptTag>.from(widget.currentTags);

    for (final tag in templateTags) {
      // 检查是否已存在相同文本的标签
      final exists = newTags.any((t) => t.text == tag.text);
      if (!exists) {
        newTags = NaiPromptParser.insertTag(
          newTags,
          newTags.length,
          tag.toSyntaxString(),
        );
      }
    }

    widget.onTagsChanged(newTags);

    // 触觉反馈
    HapticFeedback.lightImpact();

    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.tag_templateInserted(template.displayName)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 创建新模板
  void _createTemplate() {
    if (widget.readOnly) return;

    // 使用选中的标签，如果没有选中则使用所有标签
    final tagsToSave = widget.selectedTags.isNotEmpty
        ? widget.selectedTags
        : widget.currentTags;

    if (tagsToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.tag_templateNoTags),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _CreateTemplateDialog(
        initialTags: tagsToSave,
        onConfirm: (name, description) async {
          final result = await ref
              .read(tagTemplateNotifierProvider.notifier)
              .saveTemplate(
                name: name,
                tags: tagsToSave,
                description: description,
              );

          if (result == null) {
            // 保存失败（名称冲突）
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.tag_templateNameExists),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            // 保存成功
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.tag_templateSaved),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
  }

  /// 删除模板
  void _deleteTemplate(TagTemplate template) {
    if (widget.readOnly) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tag_templateDeleteTitle),
        content: Text(
          context.l10n.tag_templateDeleteMessage(template.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(tagTemplateNotifierProvider.notifier)
                  .deleteTemplate(template.id);
            },
            child: Text(
              context.l10n.common_delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templatesState = ref.watch(tagTemplateNotifierProvider);
    final templates = templatesState.templates;
    final isLoading = templatesState.isLoading;

    return ThemedContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          _buildHeader(context, templates.length),

          const SizedBox(height: 16),

          // 模板列表
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : templates.isEmpty
                    ? _buildEmptyState(context)
                    : _buildTemplatesList(context, templates),
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(BuildContext context, int count) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.bookmark_border,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.tag_templatesTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // 模板数量
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        const SizedBox(width: 8),
        // 创建按钮
        if (!widget.readOnly)
          IconButton(
            onPressed: _createTemplate,
            icon: const Icon(Icons.add),
            iconSize: 20,
            tooltip: context.l10n.tag_templateCreate,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 48,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.tag_templatesEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tag_templatesEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建模板列表
  Widget _buildTemplatesList(
    BuildContext context,
    List<TagTemplate> templates,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: templates.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final template = templates[index];
        return _buildTemplateItem(context, template);
      },
    );
  }

  /// 构建单个模板项
  Widget _buildTemplateItem(
    BuildContext context,
    TagTemplate template,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _insertTemplate(template),
        onLongPress: () => _deleteTemplate(template),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          child: Row(
            children: [
              // 模板图标
              Icon(
                Icons.bookmark,
                size: 16,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              const SizedBox(width: 12),

              // 模板信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 模板名称
                    Text(
                      template.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    // 模板描述
                    if (template.hasDescription) ...[
                      const SizedBox(height: 2),
                      Text(
                        template.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // 标签数量
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.tag_templateTagCount(template.tagCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // 插入提示
              Icon(
                Icons.add_circle_outline,
                size: 18,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(width: 4),

              // 更多操作提示
              Icon(
                Icons.more_vert,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 创建模板对话框
class _CreateTemplateDialog extends StatefulWidget {
  final List<PromptTag> initialTags;
  final Function(String name, String? description) onConfirm;

  const _CreateTemplateDialog({
    required this.initialTags,
    required this.onConfirm,
  });

  @override
  State<_CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<_CreateTemplateDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() {
      _isSaving = true;
    });

    widget.onConfirm(
      name,
      description.isEmpty ? null : description,
    );

    // 延迟关闭对话框，等待保存结果
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.l10n.tag_templateCreate),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 模板名称
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.tag_templateNameLabel,
                  hintText: context.l10n.tag_templateNameHint,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.tag_templateNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 模板描述
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.l10n.tag_templateDescLabel,
                  hintText: context.l10n.tag_templateDescHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 标签预览
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.tag_templatePreview,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.initialTags.take(10).map((tag) {
                        return Chip(
                          label: Text(
                            tag.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                    if (widget.initialTags.length > 10) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.tag_templateMoreTags(
                          widget.initialTags.length - 10,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.common_save),
        ),
      ],
    );
  }
}
