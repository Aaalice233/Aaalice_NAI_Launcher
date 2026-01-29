import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/tag_library/tag_library_category.dart';
import '../../providers/tag_library_page_provider.dart';
import '../common/image_picker_card/image_picker_card.dart';
import '../common/themed_input.dart';

/// 收藏到词库弹窗
///
/// 用于将角色的提示词快速收藏到词库
class AddToLibraryDialog extends ConsumerStatefulWidget {
  /// 默认名称
  final String defaultName;

  /// 提示词内容
  final String content;

  const AddToLibraryDialog({
    super.key,
    required this.defaultName,
    required this.content,
  });

  /// 显示收藏弹窗
  static Future<bool?> show(
    BuildContext context, {
    required String name,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AddToLibraryDialog(
        defaultName: name,
        content: content,
      ),
    );
  }

  @override
  ConsumerState<AddToLibraryDialog> createState() => _AddToLibraryDialogState();
}

class _AddToLibraryDialogState extends ConsumerState<AddToLibraryDialog> {
  late TextEditingController _nameController;
  String? _selectedCategoryId;
  String? _thumbnailPath;
  Uint8List? _thumbnailBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(tagLibraryPageNotifierProvider.notifier).addEntry(
            name: name,
            content: widget.content,
            thumbnail: _thumbnailPath,
            categoryId: _selectedCategoryId,
            isFavorite: true,
          );

      HapticFeedback.lightImpact();

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(tagLibraryPageCategoriesProvider);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部
            _buildHeader(theme, colorScheme, l10n),
            // 内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 预览图 + 名称/分类 横向布局
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 左侧预览图
                          _buildThumbnailSection(theme, colorScheme, l10n),
                          const SizedBox(width: 16),
                          // 右侧表单
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 名称输入
                                _buildNameField(theme, colorScheme, l10n),
                                const SizedBox(height: 12),
                                // 分类选择
                                _buildCategoryField(
                                  theme,
                                  colorScheme,
                                  l10n,
                                  categories,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 内容预览
                    _buildContentPreview(theme, colorScheme, l10n),
                  ],
                ),
              ),
            ),
            // 底部按钮
            _buildFooter(theme, colorScheme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.favorite,
              size: 18,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.tagLibrary_addToLibrary,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: l10n.common_close,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailSection(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return SizedBox(
      width: 100,
      child: ImagePickerCard(
        icon: Icons.add_photo_alternate_outlined,
        label: l10n.tagLibrary_selectImage,
        hintText: '(可选)',
        height: 100,
        selectedImage: _thumbnailBytes,
        selectedPath: _thumbnailPath,
        onImageSelected: (bytes, fileName, path) {
          setState(() {
            _thumbnailBytes = bytes;
            _thumbnailPath = path;
          });
        },
        onClear: () {
          setState(() {
            _thumbnailBytes = null;
            _thumbnailPath = null;
          });
        },
      ),
    );
  }

  Widget _buildNameField(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tagLibrary_entryName,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        ThemedInput(
          controller: _nameController,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: l10n.tagLibrary_entryNameHint,
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
    List<TagLibraryCategory> categories,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tagLibrary_category,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedCategoryId,
              isExpanded: true,
              borderRadius: BorderRadius.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              hint: Text(
                l10n.tagLibrary_rootCategory,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.tagLibrary_rootCategory),
                ),
                ...categories.rootCategories.sortedByOrder().map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
              ],
              onChanged: (value) {
                setState(() => _selectedCategoryId = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentPreview(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tagLibrary_contentPreview,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxHeight: 120),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: SingleChildScrollView(
            child: Text(
              widget.content.isNotEmpty ? widget.content : '(空)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.content.isNotEmpty
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.common_cancel),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.favorite, size: 18),
            label: Text(l10n.tagLibrary_confirmAdd),
          ),
        ],
      ),
    );
  }
}
