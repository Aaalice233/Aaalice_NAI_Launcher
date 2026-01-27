import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/prompt/nai_syntax_controller.dart';

/// 添加/编辑词库条目对话框
class EntryAddDialog extends ConsumerStatefulWidget {
  final List<TagLibraryCategory> categories;
  final String? initialCategoryId;

  const EntryAddDialog({
    super.key,
    required this.categories,
    this.initialCategoryId,
  });

  @override
  ConsumerState<EntryAddDialog> createState() => _EntryAddDialogState();
}

class _EntryAddDialogState extends ConsumerState<EntryAddDialog> {
  late final TextEditingController _nameController;
  late final NaiSyntaxController _contentController;
  late final TextEditingController _tagsController;
  final _nameFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();

  String? _selectedCategoryId;
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _contentController = NaiSyntaxController();
    _tagsController = TextEditingController();
    _selectedCategoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
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
          maxWidth: 700,
          minWidth: 500,
          maxHeight: 700,
        ),
        child: SingleChildScrollView(
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
                      Icons.add_box_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.tagLibrary_addEntry,
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

                const SizedBox(height: 24),

                // 主要内容区域 - 两列布局
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧 - 预览图
                    _buildThumbnailSection(theme),
                    const SizedBox(width: 24),

                    // 右侧 - 表单
                    Expanded(
                      child: _buildFormSection(theme),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 提示词内容
                Text(
                  context.l10n.tagLibrary_content,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
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
                      hintText: context.l10n.tagLibrary_contentHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(12),
                      helperText: context.l10n.fixedTags_syntaxHelp,
                      helperMaxLines: 2,
                    ),
                    maxLines: null,
                    expands: true,
                  ),
                ),

                const SizedBox(height: 24),

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

  Widget _buildThumbnailSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.tagLibrary_thumbnail,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectThumbnail,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
            ),
            child: _thumbnailPath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          File(_thumbnailPath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filled(
                          icon: const Icon(Icons.close, size: 16),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(24, 24),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            setState(() => _thumbnailPath = null);
                          },
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 36,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.tagLibrary_selectImage,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.tagLibrary_thumbnailHint,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 名称
        Text(
          context.l10n.tagLibrary_name,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          decoration: InputDecoration(
            hintText: context.l10n.tagLibrary_nameHint,
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

        // 分类
        Text(
          context.l10n.tagLibrary_category,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: _selectedCategoryId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(context.l10n.tagLibrary_rootCategory),
                ],
              ),
            ),
            ...widget.categories.map(
              (category) => DropdownMenuItem(
                value: category.id,
                child: Row(
                  children: [
                    const Icon(Icons.folder, size: 18),
                    const SizedBox(width: 8),
                    Text(category.displayName),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => _selectedCategoryId = value);
          },
        ),

        const SizedBox(height: 16),

        // 标签
        Text(
          context.l10n.tagLibrary_tags,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tagsController,
          decoration: InputDecoration(
            hintText: context.l10n.tagLibrary_tagsHint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            helperText: context.l10n.tagLibrary_tagsHelper,
          ),
        ),
      ],
    );
  }

  Future<void> _selectThumbnail() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _thumbnailPath = result.files.single.path;
      });
    }
  }

  bool _canSave() {
    return _contentController.text.trim().isNotEmpty;
  }

  void _save() {
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();
    final tagsText = _tagsController.text.trim();
    final tags = tagsText.isNotEmpty
        ? tagsText
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList()
        : <String>[];

    if (content.isEmpty) return;

    ref.read(tagLibraryPageNotifierProvider.notifier).addEntry(
          name: name,
          content: content,
          thumbnail: _thumbnailPath,
          tags: tags,
          categoryId: _selectedCategoryId,
        );

    Navigator.of(context).pop();
  }
}
