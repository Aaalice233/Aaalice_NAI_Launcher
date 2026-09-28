import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/thumbnail_image_normalizer.dart';
import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../prompt_assistant/providers/prompt_assistant_history_provider.dart';
import '../../../prompt_assistant/widgets/prompt_assistant_overlay.dart';
import '../../../widgets/prompt/prompt_editor_control_row.dart';
import '../../../prompt_assistant/widgets/prompt_assistant_quick_settings.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../widgets/autocomplete/autocomplete.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/safe_dropdown.dart';
import '../../../widgets/common/themed_input.dart';
import '../../../widgets/prompt/nai_syntax_controller.dart';
import '../../../widgets/prompt/prompt_formatter_wrapper.dart';
import '../../../widgets/prompt/tag_mode_prompt_field.dart';
import 'thumbnail_crop_dialog.dart';
import 'thumbnail_selection_preview.dart';

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

  /// 初始条目名称（用于从拖拽图片创建时预填文件名）
  final String? initialName;
  final ScrollController? _scrollController;

  const EntryAddDialog._({
    required this.categories,
    required this.initialCategoryId,
    required this.entry,
    required this.initialContent,
    required this.initialImageBytes,
    required this.initialName,
    required ScrollController scrollController,
  }) : _scrollController = scrollController;

  /// 显示对话框的静态方法
  static Future<void> show(
    BuildContext context, {
    required List<TagLibraryCategory> categories,
    String? initialCategoryId,
    TagLibraryEntry? entry,
    String? initialContent,
    Uint8List? initialImageBytes,
    String? initialName,
  }) {
    Widget title(BuildContext dialogContext) =>
        _EntryAddDialogTitle(editing: entry != null);

    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: title,
      dialogWidth: 700,
      maxCenteredHeight: 680,
      builder: (dialogContext, scrollController) => EntryAddDialog._(
        categories: categories,
        initialCategoryId: initialCategoryId,
        entry: entry,
        initialContent: initialContent,
        initialImageBytes: initialImageBytes,
        initialName: initialName,
        scrollController: scrollController,
      ),
    );
  }

  @override
  ConsumerState<EntryAddDialog> createState() => _EntryAddDialogState();
}

class _EntryAddDialogTitle extends StatelessWidget {
  const _EntryAddDialogTitle({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          editing ? Icons.edit_outlined : Icons.add_box_outlined,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            editing
                ? context.l10n.tagLibrary_editEntry
                : context.l10n.tagLibrary_addEntry,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryAddDialogState extends ConsumerState<EntryAddDialog> {
  late final TextEditingController _nameController;
  late final NaiSyntaxController _contentController;
  late final TextEditingController _tagsController;
  late final String _assistantSessionId;
  Object get _modeId =>
      widget.entry == null ? _contentController : _assistantSessionId;
  final _nameFocusNode = FocusNode();
  final _contentFocusNode = FocusNode();
  final _tagsFocusNode = FocusNode();
  final _ownedScrollController = ScrollController();

  ScrollController get _scrollController =>
      widget._scrollController ?? _ownedScrollController;

  String? _selectedCategoryId;
  String? _thumbnailPath;
  final Set<String> _temporaryThumbnailPaths = {};
  int _thumbnailImportRevision = 0;

  // 预览图显示范围调整参数
  double _thumbnailOffsetX = 0.0;
  double _thumbnailOffsetY = 0.0;
  double _thumbnailScale = 1.0;

  bool get _isEditing => widget.entry != null;

  void _syncSyntaxHighlightSettings() {
    _contentController.highlightEnabled = ref.watch(
      highlightEmphasisSettingsProvider,
    );
    _contentController.numericEmphasisEnabled = ImageModels.isV4Model(
      ref.watch(
        generationParamsNotifierProvider.select((params) => params.model),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    // 优先使用 initialContent，然后是 entry?.content，最后为空
    final initialContent = widget.initialContent ?? entry?.content ?? '';
    // 优先使用 entry?.name，然后是 initialName，最后为空
    final initialName = entry?.name ?? widget.initialName ?? '';
    _nameController = TextEditingController(text: initialName);
    _contentController = NaiSyntaxController(text: initialContent);
    _tagsController = TextEditingController(text: entry?.tags.join(', ') ?? '');
    _assistantSessionId = PromptHistorySessionIds.tagLibraryEntry(
      entry?.id ?? 'draft-${identityHashCode(this)}',
    );
    _selectedCategoryId = entry?.categoryId ?? widget.initialCategoryId;
    _thumbnailPath = entry?.thumbnail;

    // 如果是编辑模式，加载已保存的显示范围设置
    if (widget.entry != null) {
      _thumbnailOffsetX = widget.entry!.thumbnailOffsetX;
      _thumbnailOffsetY = widget.entry!.thumbnailOffsetY;
      _thumbnailScale = widget.entry!.thumbnailScale;
    }

    // 监听内容变化，更新保存按钮状态
    _contentController.addListener(_onContentChanged);

    // 如果有初始图像字节数据，保存到临时文件
    if (widget.initialImageBytes != null && widget.entry == null) {
      unawaited(_initializeThumbnail(widget.initialImageBytes!));
    }
  }

  Future<void> _initializeThumbnail(Uint8List bytes) async {
    try {
      await _saveImageBytesToTemp(bytes);
    } catch (e) {
      debugPrint('保存临时图像失败: $e');
    }
  }

  /// 统一转换为 PNG，避免 TIFF、TGA 等格式无法由 Flutter 直接预览。
  Future<void> _saveImageBytesToTemp(Uint8List bytes) async {
    final importRevision = ++_thumbnailImportRevision;
    final normalizedBytes = await compute(normalizeThumbnailImageToPng, bytes);
    final tempDir = await getTemporaryDirectory();
    final fileName = 'temp_${const Uuid().v4()}.png';
    final file = File(path.join(tempDir.path, fileName));
    await file.writeAsBytes(normalizedBytes);

    if (!mounted || importRevision != _thumbnailImportRevision) {
      await _deleteTemporaryThumbnail(file.path);
      return;
    }

    final previousPath = _thumbnailPath;
    _temporaryThumbnailPaths.add(file.path);
    setState(() {
      _thumbnailPath = file.path;
    });

    if (previousPath != null && _temporaryThumbnailPaths.remove(previousPath)) {
      unawaited(_deleteTemporaryThumbnail(previousPath));
    }
  }

  void _clearThumbnail() {
    final previousPath = _thumbnailPath;
    _thumbnailImportRevision++;
    setState(() => _thumbnailPath = null);
    if (previousPath != null && _temporaryThumbnailPaths.remove(previousPath)) {
      unawaited(_deleteTemporaryThumbnail(previousPath));
    }
  }

  Future<void> _deleteTemporaryThumbnail(String thumbnailPath) async {
    try {
      final file = File(thumbnailPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('删除临时预览图失败: $e');
    }
  }

  void _onContentChanged() {
    setState(() {
      // 触发重建以更新保存按钮状态
    });
  }

  @override
  void dispose() {
    _thumbnailImportRevision++;
    for (final thumbnailPath in _temporaryThumbnailPaths) {
      unawaited(_deleteTemporaryThumbnail(thumbnailPath));
    }
    _temporaryThumbnailPaths.clear();
    _contentController.removeListener(_onContentChanged);
    _nameController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _nameFocusNode.dispose();
    _contentFocusNode.dispose();
    _tagsFocusNode.dispose();
    _ownedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncSyntaxHighlightSettings();
    return _buildContent(Theme.of(context));
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: ScrollbarTheme(
            data: ScrollbarTheme.of(context).copyWith(
              thumbColor: WidgetStatePropertyAll(
                theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
              ),
              mainAxisMargin: 12,
              crossAxisMargin: 4,
            ),
            child: Scrollbar(
              controller: _scrollController,
              interactive: true,
              thickness: 3,
              radius: const Radius.circular(3),
              child: ListView(
                key: const Key('entry-add-dialog-scroll'),
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked =
                          constraints.maxWidth < 560 ||
                          MediaQuery.textScalerOf(context).scale(1) >= 2;
                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildThumbnailSection(theme, expand: true),
                            const SizedBox(height: 24),
                            _buildFormSection(theme),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildThumbnailSection(theme),
                          const SizedBox(width: 24),
                          Expanded(child: _buildFormSection(theme)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.tagLibrary_content,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    key: const Key('entry-add-dialog-content-editor'),
                    constraints: const BoxConstraints(minHeight: 176),
                    child: TagModePromptField(
                      sessionId: _modeId,
                      fitContent: true,
                      showModeSwitch: false,
                      assistant: Positioned.fill(
                        child: PromptAssistantOverlay(
                          placement: PromptAssistantPlacement.viewport,
                          sessionId: _assistantSessionId,
                          controller: _contentController,
                          iconOnly: true,
                          tagModeSessionId: _modeId,
                          supportsTagMode: true,
                          stripFixedTagsFromInput: false,
                          onOpenSettings: () =>
                              PromptAssistantQuickSettings.show(context),
                        ),
                      ),
                      controller: _contentController,
                      sourceFocusNode: _contentFocusNode,
                      child: PromptFormatterWrapper(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        enableAutoFormat: ref.watch(
                          autoFormatPromptSettingsProvider,
                        ),
                        child: AutocompleteWrapper.withAlias(
                          controller: _contentController.displayController,
                          focusNode: _contentFocusNode,
                          ref: ref,
                          expands: false,
                          config: const AutocompleteConfig(
                            showTranslation: true,
                            showCategory: true,
                            autoInsertComma: true,
                          ),
                          child: ThemedInput(
                            controller: _contentController.displayController,
                            contextMenuBuilder: _contentController
                                .displayController
                                .buildContextMenu,
                            focusNode: _contentFocusNode,
                            decoration: InputDecoration(
                              hintText: context.l10n.tagLibrary_contentHint,
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                60,
                              ),
                            ),
                            maxLines: null,
                            minLines: 4,
                            expands: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: _buildPromptFooter(theme),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 320 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 2;
                final cancel = TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.common_cancel),
                );
                final save = FilledButton(
                  onPressed: _canSave() ? _save : null,
                  child: Text(context.l10n.common_save),
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [save, cancel],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [cancel, const SizedBox(width: 8), save],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptFooter(ThemeData theme) => Container(
    key: const ValueKey('entry-add-dialog-content-footer'),
    width: double.infinity,
    padding: const EdgeInsets.only(left: 12, right: 4),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(6),
    ),
    child: PromptEditorControlRow(
      sessionId: _modeId,
      leading: Text(
        context.l10n.tagLibrary_characterNegativeSyntaxHelp,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.62),
          fontSize: 12,
        ),
      ),
    ),
  );
  Widget _buildThumbnailSection(ThemeData theme, {bool expand = false}) {
    return SizedBox(
      key: const Key('entry-add-dialog-thumbnail-section'),
      width: expand ? double.infinity : 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.tagLibrary_thumbnail,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final previewSize = constraints.maxWidth.clamp(0, 220).toDouble();
              return Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox.square(
                  key: const ValueKey('entry-thumbnail-square-preview'),
                  dimension: previewSize,
                  child: GestureDetector(
                    onTap: _thumbnailPath != null
                        ? _showThumbnailOptions
                        : _selectThumbnail,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _thumbnailPath != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: ThumbnailSelectionPreview(
                                    imagePath: _thumbnailPath!,
                                    offsetX: _thumbnailOffsetX,
                                    offsetY: _thumbnailOffsetY,
                                    scale: _thumbnailScale,
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
                                      minimumSize: Size.square(
                                        context
                                            .interactionPolicy
                                            .minimumControlExtent,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: _clearThumbnail,
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
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.tagLibrary_thumbnailHint,
            style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 名称
        Text(context.l10n.tagLibrary_name, style: theme.textTheme.labelLarge),
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
        Text(context.l10n.tagLibrary_tags, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        AutocompleteWrapper(
          controller: _tagsController,
          focusNode: _tagsFocusNode,
          config: const AutocompleteConfig(
            showTranslation: true,
            showCategory: true,
            autoInsertComma: true,
          ),
          child: ThemedInput(
            controller: _tagsController,
            focusNode: _tagsFocusNode,
            hintText: context.l10n.tagLibrary_tagsHint,
            helperText: context.l10n.tagLibrary_tagsHelper,
          ),
        ),
      ],
    );
  }

  /// 显示预览图选项菜单
  void _showThumbnailOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: Text(context.l10n.tagLibrary_selectNewImage),
              onTap: () {
                Navigator.pop(context);
                _selectThumbnail();
              },
            ),
            ListTile(
              leading: const Icon(Icons.crop_free),
              title: Text(context.l10n.tagLibrary_adjustDisplayRange),
              onTap: () {
                Navigator.pop(context);
                _openCropDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 打开缩略图裁剪调整对话框
  Future<void> _openCropDialog() async {
    await showThumbnailCropDialog(
      context: context,
      imagePath: _thumbnailPath!,
      initialOffsetX: _thumbnailOffsetX,
      initialOffsetY: _thumbnailOffsetY,
      initialScale: _thumbnailScale,
      onConfirm: (result) {
        setState(() {
          _thumbnailOffsetX = result.offsetX;
          _thumbnailOffsetY = result.offsetY;
          _thumbnailScale = result.scale;
        });
      },
    );
  }

  Future<void> _selectThumbnail() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedThumbnailImageExtensions,
        allowMultiple: false,
      );
      if (result == null) return;

      final selectedFile = result.files.single;
      final bytes =
          selectedFile.bytes ??
          (selectedFile.path == null
              ? null
              : await File(selectedFile.path!).readAsBytes());
      if (bytes == null) {
        throw const FileSystemException('无法读取所选图像');
      }

      await _saveImageBytesToTemp(bytes);
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.imagePicker_fileSelectionFailed(e.toString()),
        );
      }
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
    final String? oldThumbnailPath = _isEditing
        ? widget.entry?.thumbnail
        : null;

    // 处理缩略图：确保存储在应用目录内
    final String? savedThumbnailPath = await _ensureThumbnailInAppDir(
      _thumbnailPath,
    );

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
        thumbnailOffsetX: _thumbnailOffsetX,
        thumbnailOffsetY: _thumbnailOffsetY,
        thumbnailScale: _thumbnailScale,
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
        thumbnailOffsetX: _thumbnailOffsetX,
        thumbnailOffsetY: _thumbnailOffsetY,
        thumbnailScale: _thumbnailScale,
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
