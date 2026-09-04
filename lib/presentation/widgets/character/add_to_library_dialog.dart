import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/tag_library/tag_library_category.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/tag_library_page_provider.dart';
import '../common/app_toast.dart';
import '../common/image_picker_card/image_picker_card.dart';
import '../common/themed_input.dart';
import '../common/translated_tag_text.dart';

/// 收藏到词库弹窗
///
/// 用于将角色的提示词快速收藏到词库
class AddToLibraryDialog extends ConsumerStatefulWidget {
  /// 默认名称
  final String defaultName;

  /// 提示词内容
  final String content;
  final ScrollController? scrollController;

  const AddToLibraryDialog({
    super.key,
    required this.defaultName,
    required this.content,
    this.scrollController,
  });

  /// 显示收藏弹窗
  static Future<bool?> show(
    BuildContext context, {
    required String name,
    required String content,
  }) {
    return AdaptivePresenter.showForm<bool>(
      context: context,
      titleBuilder: (context) => Text(
        context.l10n.tagLibrary_addToLibrary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      width: 520,
      builder: (context, scrollController) => AddToLibraryDialog(
        defaultName: name,
        content: content,
        scrollController: scrollController,
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
      await ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .addEntry(
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
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(tagLibraryPageCategoriesProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 400 ||
                      MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                  final form = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameField(theme, colorScheme, l10n),
                      const SizedBox(height: 12),
                      _buildCategoryField(theme, colorScheme, l10n, categories),
                    ],
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _buildThumbnailSection(
                            theme,
                            colorScheme,
                            l10n,
                          ),
                        ),
                        const SizedBox(height: 16),
                        form,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildThumbnailSection(theme, colorScheme, l10n),
                        const SizedBox(width: 16),
                        Expanded(child: form),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildContentPreview(theme, colorScheme, l10n),
            ],
          ),
        ),
        _buildFooter(theme, colorScheme, l10n),
      ],
    );
  }

  Widget _buildThumbnailSection(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 2;
    return SizedBox(
      width: largeText ? 160 : 100,
      child: ImagePickerCard(
        icon: Icons.add_photo_alternate_outlined,
        label: l10n.tagLibrary_selectImage,
        hintText: '(${l10n.common_optional})',
        height: largeText ? 160 : 100,
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
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
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
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: widget.content.isEmpty
                ? Text(
                    l10n.common_emptyValue,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : TranslatedPromptText(
                    widget.content,
                    selectable: false,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) >= 2;
          final cancel = TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.common_cancel),
          );
          final submit = FilledButton.icon(
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
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [submit, cancel],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [cancel, const SizedBox(width: 12), submit],
          );
        },
      ),
    );
  }
}
