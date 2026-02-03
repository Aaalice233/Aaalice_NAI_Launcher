import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/safe_dropdown.dart';
import '../../../widgets/common/themed_input.dart';
import '../../../widgets/prompt/nai_syntax_controller.dart';
import '../../../widgets/prompt/prompt_formatter_wrapper.dart';

/// 添加/编辑词库条目对话框
class EntryAddDialog extends ConsumerStatefulWidget {
  final List<TagLibraryCategory> categories;
  final String? initialCategoryId;

  /// 要编辑的条目，如果为 null 则为新建模式
  final TagLibraryEntry? entry;

  /// 初始提示词内容（用于从外部传入预选文本）
  final String? initialContent;

  /// 初始图像字节数据（用于从图像卡片传入预览图）
  final Uint8List? initialImageBytes;

  const EntryAddDialog({
    super.key,
    required this.categories,
    this.initialCategoryId,
    this.entry,
    this.initialContent,
    this.initialImageBytes,
  });

  /// 显示对话框的静态方法
  static Future<void> show(
    BuildContext context, {
    required List<TagLibraryCategory> categories,
    String? initialCategoryId,
    String? initialContent,
    Uint8List? initialImageBytes,
  }) {
    return showDialog(
      context: context,
      builder: (context) => EntryAddDialog(
        categories: categories,
        initialCategoryId: initialCategoryId,
        initialContent: initialContent,
        initialImageBytes: initialImageBytes,
      ),
    );
  }

  @override
  ConsumerState<EntryAddDialog> createState() => _EntryAddDialogState();
}

class _EntryAddDialogState extends ConsumerState<EntryAddDialog> {
  late final TextEditingController _nameController;
  late final NaiSyntaxController _contentController;
  late final TextEditingController _tagsController;
  final _nameFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  final _tagsFocusNode = FocusNode();

  String? _selectedCategoryId;
  String? _thumbnailPath;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    // 优先使用 initialContent，然后是 entry?.content，最后为空
    final initialContent = widget.initialContent ?? entry?.content ?? '';
    _nameController = TextEditingController(text: entry?.name ?? '');
    _contentController = NaiSyntaxController(text: initialContent);
    _tagsController = TextEditingController(text: entry?.tags.join(', ') ?? '');
    _selectedCategoryId = entry?.categoryId ?? widget.initialCategoryId;
    _thumbnailPath = entry?.thumbnail;

    // 监听内容变化，更新保存按钮状态
    _contentController.addListener(_onContentChanged);

    // 如果有初始图像字节数据，保存到临时文件
    if (widget.initialImageBytes != null && widget.entry == null) {
      _saveImageBytesToTemp(widget.initialImageBytes!);
    }
  }

  /// 将图像字节数据保存到临时文件
  Future<void> _saveImageBytesToTemp(Uint8List bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (mounted) {
        setState(() {
          _thumbnailPath = file.path;
        });
      }
    } catch (e) {
      debugPrint('保存临时图像失败: $e');
    }
  }

  void _onContentChanged() {
    setState(() {
      // 触发重建以更新保存按钮状态
    });
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _nameController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _nameFocusNode.dispose();
    _contentFocusNode.dispose();
    _tagsFocusNode.dispose();
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
                      _isEditing ? Icons.edit_outlined : Icons.add_box_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEditing
                          ? context.l10n.tagLibrary_editEntry
                          : context.l10n.tagLibrary_addEntry,
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
                  child: PromptFormatterWrapper(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    enableAutoFormat:
                        ref.watch(autoFormatPromptSettingsProvider),
                    child: AutocompleteWrapper.withAlias(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      ref: ref,
                      config: const AutocompleteConfig(
                        maxSuggestions: 15,
                        showTranslation: true,
                        showCategory: true,
                        autoInsertComma: true,
                      ),
                      child: ThemedInput(
                        controller: _contentController,
                        decoration: InputDecoration(
                          hintText: context.l10n.tagLibrary_contentHint,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        maxLines: null,
                        expands: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    context.l10n.fixedTags_syntaxHelp,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 2,
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
        ThemedInput(
          controller: _nameController,
          focusNode: _nameFocusNode,
          hintText: context.l10n.tagLibrary_nameHint,
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
        SafeDropdown<String?>(
          value: _selectedCategoryId,
          items: [
            DropdownMenuItem(
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
            ...widget.categories.map(
              (category) => DropdownMenuItem(
                value: category.id,
                child: Row(
                  children: [
                    Icon(
                      Icons.folder,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
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
        AutocompleteWrapper(
          controller: _tagsController,
          focusNode: _tagsFocusNode,
          strategy: LocalTagStrategy.create(
            ref,
            const AutocompleteConfig(
              maxSuggestions: 10,
              showTranslation: true,
              showCategory: true,
              autoInsertComma: true,
            ),
          ),
          child: ThemedInput(
            controller: _tagsController,
            hintText: context.l10n.tagLibrary_tagsHint,
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

  /// 确保缩略图存储在应用目录内
  /// 如果缩略图在外部路径，则复制到应用目录并返回新路径
  Future<String?> _ensureThumbnailInAppDir(String? thumbnailPath) async {
    if (thumbnailPath == null || thumbnailPath.isEmpty) {
      return null;
    }

    // 检查文件是否已存在于应用目录内
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailsDir = Directory(
      path.join(appDir.path, 'tag_library_thumbnails'),
    );

    // 如果路径已经在应用目录内，直接返回
    if (thumbnailPath.startsWith(thumbnailsDir.path)) {
      return thumbnailPath;
    }

    // 确保缩略图目录存在
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
    }

    // 复制文件到应用目录
    final sourceFile = File(thumbnailPath);
    if (!await sourceFile.exists()) {
      // 原文件不存在，返回 null（图片可能被删除了）
      return null;
    }

    final ext = path.extension(thumbnailPath);
    final newFileName = '${const Uuid().v4()}$ext';
    final newPath = path.join(thumbnailsDir.path, newFileName);

    await sourceFile.copy(newPath);
    return newPath;
  }

  /// 删除应用目录内的旧缩略图文件
  Future<void> _deleteOldThumbnail(String? oldThumbnailPath) async {
    if (oldThumbnailPath == null || oldThumbnailPath.isEmpty) {
      return;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = path.join(appDir.path, 'tag_library_thumbnails');

      // 只删除应用目录内的文件，避免误删外部文件
      if (oldThumbnailPath.startsWith(thumbnailsDir)) {
        final file = File(oldThumbnailPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      // 忽略删除失败，不影响保存流程
      debugPrint('删除旧缩略图失败: $e');
    }
  }

  Future<void> _save() async {
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

    // 获取旧的缩略图路径（用于后续清理）
    final String? oldThumbnailPath =
        _isEditing ? widget.entry?.thumbnail : null;

    // 处理缩略图：确保存储在应用目录内
    final String? savedThumbnailPath =
        await _ensureThumbnailInAppDir(_thumbnailPath);

    // 如果缩略图发生了变化，删除旧的
    if (oldThumbnailPath != null &&
        oldThumbnailPath != savedThumbnailPath &&
        oldThumbnailPath != _thumbnailPath) {
      await _deleteOldThumbnail(oldThumbnailPath);
    }

    final notifier = ref.read(tagLibraryPageNotifierProvider.notifier);

    if (_isEditing) {
      // 编辑模式：更新现有条目
      final updatedEntry = widget.entry!.copyWith(
        name: name,
        content: content,
        thumbnail: savedThumbnailPath,
        tags: tags,
        categoryId: _selectedCategoryId,
        updatedAt: DateTime.now(),
      );
      notifier.updateEntry(updatedEntry);
    } else {
      // 新建模式：添加新条目
      notifier.addEntry(
        name: name,
        content: content,
        thumbnail: savedThumbnailPath,
        tags: tags,
        categoryId: _selectedCategoryId,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
      // 显示保存成功提示
      AppToast.success(
        context,
        _isEditing
            ? context.l10n.tagLibrary_entryUpdated
            : context.l10n.tagLibrary_entrySaved,
      );
    }
  }
}
