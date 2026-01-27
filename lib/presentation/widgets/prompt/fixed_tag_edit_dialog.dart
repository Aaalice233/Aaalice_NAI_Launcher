import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../providers/tag_library_page_provider.dart';
import '../autocomplete/autocomplete.dart';
import '../prompt/nai_syntax_controller.dart';

/// 固定词编辑对话框
class FixedTagEditDialog extends ConsumerStatefulWidget {
  /// 要编辑的条目，如果为 null 则为新建模式
  final FixedTagEntry? entry;

  const FixedTagEditDialog({super.key, this.entry});

  @override
  ConsumerState<FixedTagEditDialog> createState() => _FixedTagEditDialogState();
}

class _FixedTagEditDialogState extends ConsumerState<FixedTagEditDialog> {
  late final TextEditingController _nameController;
  late final NaiSyntaxController _contentController;
  late FixedTagPosition _position;
  late double _weight;
  late bool _enabled;
  bool _saveToLibrary = false;
  String? _selectedCategoryId; // 保存到词库的目标分类

  final _nameFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _contentController = NaiSyntaxController(text: entry?.content ?? '');
    _position = entry?.position ?? FixedTagPosition.prefix;
    _weight = entry?.weight ?? 1.0;
    _enabled = entry?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _nameFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          minWidth: 400,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Icon(
                      _isEditing ? Icons.edit : Icons.add,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEditing
                          ? context.l10n.fixedTags_edit
                          : context.l10n.fixedTags_add,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 名称输入
                Text(
                  context.l10n.fixedTags_name,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  decoration: InputDecoration(
                    hintText: context.l10n.fixedTags_nameHint,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    _contentFocusNode.requestFocus();
                  },
                ),

                const SizedBox(height: 16),

                // 内容输入 (带自动补全)
                Text(
                  context.l10n.fixedTags_content,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 120,
                  child: AutocompleteTextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    enableAutocomplete: true,
                    enableAutoFormat: true,
                    config: const AutocompleteConfig(
                      maxSuggestions: 15,
                      showTranslation: true,
                      showCategory: true,
                      autoInsertComma: true,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.fixedTags_contentHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(12),
                      helperText: context.l10n.fixedTags_syntaxHelp,
                      helperMaxLines: 2,
                    ),
                    maxLines: null,
                    expands: true,
                  ),
                ),

                const SizedBox(height: 16),

                // 位置选择
                Text(
                  context.l10n.fixedTags_position,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _PositionRadioButton(
                        label: context.l10n.fixedTags_prefix,
                        description: context.l10n.fixedTags_prefixDesc,
                        icon: Icons.arrow_forward,
                        isSelected: _position == FixedTagPosition.prefix,
                        color: theme.colorScheme.primary,
                        onTap: () =>
                            setState(() => _position = FixedTagPosition.prefix),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PositionRadioButton(
                        label: context.l10n.fixedTags_suffix,
                        description: context.l10n.fixedTags_suffixDesc,
                        icon: Icons.arrow_back,
                        isSelected: _position == FixedTagPosition.suffix,
                        color: theme.colorScheme.tertiary,
                        onTap: () =>
                            setState(() => _position = FixedTagPosition.suffix),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 权重调节
                Row(
                  children: [
                    Text(
                      context.l10n.fixedTags_weight,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_weight.toStringAsFixed(2)}x',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '0.5',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _weight,
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        label: _weight.toStringAsFixed(2),
                        onChanged: (value) {
                          setState(() => _weight = value);
                        },
                      ),
                    ),
                    Text(
                      '2.0',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 重置按钮
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: context.l10n.fixedTags_resetWeight,
                      onPressed: () => setState(() => _weight = 1.0),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),

                // 权重预览
                if (_weight != 1.0) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.fixedTags_weightPreview,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getWeightPreview(),
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // 保存到词库选项（仅新建时显示）
                if (!_isEditing) ...[
                  CheckboxListTile(
                    title: Text(
                      context.l10n.fixedTags_saveToLibrary,
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      context.l10n.fixedTags_saveToLibraryHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    value: _saveToLibrary,
                    onChanged: (value) {
                      setState(() => _saveToLibrary = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),

                  // 类别选择器（仅当保存到词库时显示）
                  if (_saveToLibrary) ...[
                    const SizedBox(height: 8),
                    _buildCategorySelector(theme),
                  ],

                  const SizedBox(height: 12),
                ],

                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.common_cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _canSave() ? _save : null,
                      child: Text(context.l10n.common_save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getWeightPreview() {
    final content = _contentController.text.isNotEmpty
        ? (_contentController.text.length > 30
            ? '${_contentController.text.substring(0, 30)}...'
            : _contentController.text)
        : 'your_content';
    return FixedTagEntry.applyWeight(content, _weight);
  }

  bool _canSave() {
    return _contentController.text.trim().isNotEmpty;
  }

  void _save() {
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) return;

    final result = widget.entry?.update(
          name: name,
          content: content,
          weight: _weight,
          position: _position,
          enabled: _enabled,
        ) ??
        FixedTagEntry.create(
          name: name,
          content: content,
          weight: _weight,
          position: _position,
          enabled: _enabled,
        );

    // 如果选中了"保存到词库"，同时添加到词库
    if (_saveToLibrary && !_isEditing) {
      ref.read(tagLibraryPageNotifierProvider.notifier).addEntry(
            name: name.isNotEmpty
                ? name
                : content.substring(
                    0,
                    content.length > 20 ? 20 : content.length,
                  ),
            content: content,
            categoryId: _selectedCategoryId,
          );
    }

    Navigator.of(context).pop(result);
  }

  /// 构建类别选择器
  Widget _buildCategorySelector(ThemeData theme) {
    final state = ref.watch(tagLibraryPageNotifierProvider);
    final categories = state.categories;

    // 构建分类选项列表
    final items = <DropdownMenuItem<String?>>[];

    // Root 选项
    items.add(
      DropdownMenuItem<String?>(
        value: null,
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(context.l10n.tagLibrary_rootCategory),
          ],
        ),
      ),
    );

    // 递归添加分类（带层级缩进）
    void addCategoryItems(String? parentId, int depth) {
      final children = categories.where((c) => c.parentId == parentId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      for (final category in children) {
        items.add(
          DropdownMenuItem<String?>(
            value: category.id,
            child: Row(
              children: [
                SizedBox(width: depth * 16.0),
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
        addCategoryItems(category.id, depth + 1);
      }
    }

    addCategoryItems(null, 0);

    return Container(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.fixedTags_saveToCategory,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String?>(
            value: _selectedCategoryId,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            items: items,
            onChanged: (value) {
              setState(() => _selectedCategoryId = value);
            },
            isExpanded: true,
          ),
        ],
      ),
    );
  }
}

/// 位置选择按钮
class _PositionRadioButton extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PositionRadioButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.1)
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color.withOpacity(0.5)
                  : theme.colorScheme.outlineVariant.withOpacity(0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? color : theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? color
                            : theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<bool>(
                value: true,
                groupValue: isSelected,
                onChanged: (_) => onTap(),
                activeColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
