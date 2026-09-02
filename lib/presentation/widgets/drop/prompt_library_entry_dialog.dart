import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../data/models/tag_library/tag_library_category.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/window_size_class.dart';
import '../../providers/tag_library_page_provider.dart';
import '../common/adaptive_dialog_frame.dart';
import '../common/app_toast.dart';
import '../common/safe_dropdown.dart';

/// 写入图像 Prompt 选区时支持的明确操作。
enum PromptLibraryWriteMode { create, append, overwrite }

enum PromptAppendSeparator { commaSpace, newline, none }

String appendPromptSnippet(
  String existingContent,
  String snippet,
  PromptAppendSeparator separator,
) {
  if (existingContent.isEmpty) return snippet;
  if (snippet.isEmpty) return existingContent;

  final joiner = switch (separator) {
    PromptAppendSeparator.commaSpace => ', ',
    PromptAppendSeparator.newline => '\n',
    PromptAppendSeparator.none => '',
  };
  return '$existingContent$joiner$snippet';
}

String availablePromptLibraryName(
  String preferredName,
  List<TagLibraryEntry> entries,
) {
  final normalizedPreferredName = preferredName.trim();
  final normalizedNames = entries
      .map((entry) => entry.name.trim().toLowerCase())
      .toSet();
  if (!normalizedNames.contains(normalizedPreferredName.toLowerCase())) {
    return normalizedPreferredName;
  }

  var suffix = 2;
  while (normalizedNames.contains(
    '$normalizedPreferredName $suffix'.toLowerCase(),
  )) {
    suffix++;
  }
  return '$normalizedPreferredName $suffix';
}

String suggestedPromptLibraryName(String content, String fallbackName) {
  final candidate = content.trim();
  if (candidate.isNotEmpty &&
      !candidate.contains('\n') &&
      !candidate.contains(',') &&
      candidate.characters.length <= 32) {
    return candidate;
  }
  return fallbackName;
}

class PromptLibraryEntryDialog extends ConsumerStatefulWidget {
  final String initialContent;
  final String fallbackName;

  const PromptLibraryEntryDialog({
    super.key,
    required this.initialContent,
    required this.fallbackName,
    this.scrollController,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String content,
    required String fallbackName,
  }) {
    return AdaptivePresenter.showForm<bool>(
      context: context,
      titleBuilder: (dialogContext) => Row(
        children: [
          Icon(
            Icons.library_add_outlined,
            color: Theme.of(dialogContext).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dialogContext.l10n.drop_promptLibraryTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      builder: (dialogContext, scrollController) => PromptLibraryEntryDialog(
        initialContent: content,
        fallbackName: fallbackName,
        scrollController: scrollController,
      ),
    );
  }

  final ScrollController? scrollController;

  @override
  ConsumerState<PromptLibraryEntryDialog> createState() =>
      _PromptLibraryEntryDialogState();
}

class _PromptLibraryEntryDialogState
    extends ConsumerState<PromptLibraryEntryDialog> {
  static const _rootCategoryValue = '__root__';

  late final TextEditingController _nameController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;
  final _nameFocusNode = FocusNode();

  PromptLibraryWriteMode _mode = PromptLibraryWriteMode.create;
  PromptAppendSeparator _separator = PromptAppendSeparator.commaSpace;
  String? _targetEntryId;
  String? _selectedCategoryId;
  bool _showMore = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final library = ref.read(tagLibraryPageNotifierProvider);
    final preferredName = suggestedPromptLibraryName(
      widget.initialContent,
      widget.fallbackName,
    );
    _nameController = TextEditingController(
      text: availablePromptLibraryName(preferredName, library.entries),
    );
    _contentController = TextEditingController(text: widget.initialContent);
    _tagsController = TextEditingController();
    final selectedCategoryId = library.selectedCategoryId;
    _selectedCategoryId =
        library.categories.any((category) => category.id == selectedCategoryId)
        ? selectedCategoryId
        : null;
    _nameController.addListener(_onFormChanged);
    _contentController.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _contentController.removeListener(_onFormChanged);
    _nameController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  TagLibraryEntry? _targetEntry(List<TagLibraryEntry> entries) {
    for (final entry in entries) {
      if (entry.id == _targetEntryId) return entry;
    }
    return null;
  }

  TagLibraryEntry? _exactDuplicate(List<TagLibraryEntry> entries) {
    if (_mode != PromptLibraryWriteMode.create) return null;
    final content = _contentController.text;
    for (final entry in entries) {
      if (entry.content == content) return entry;
    }
    return null;
  }

  bool _hasNameConflict(List<TagLibraryEntry> entries) {
    if (_mode != PromptLibraryWriteMode.create) return false;
    final name = _nameController.text.trim().toLowerCase();
    if (name.isEmpty) return false;
    return entries.any((entry) => entry.name.trim().toLowerCase() == name);
  }

  bool _canSave(List<TagLibraryEntry> entries) {
    if (_saving || _contentController.text.trim().isEmpty) return false;
    if (_mode == PromptLibraryWriteMode.create) {
      return _nameController.text.trim().isNotEmpty &&
          !_hasNameConflict(entries) &&
          _exactDuplicate(entries) == null;
    }
    return _targetEntry(entries) != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = ref.watch(tagLibraryPageNotifierProvider);
    final entries = library.entries.sortedByName();
    final targetEntry = _targetEntry(entries);
    final duplicate = _exactDuplicate(entries);
    final hasNameConflict = _hasNameConflict(entries);

    return PopScope(
      canPop: !_saving,
      child: AdaptiveDialogFrame(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        reservedVerticalSpace: 0,
        horizontalMargin: 0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useCompactLayout = WindowSizeClass.fromWidth(
              constraints.maxWidth,
            ).isCompact;
            return SingleChildScrollView(
              key: const ValueKey('prompt-library-form-scroll'),
              controller: widget.scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.all(useCompactLayout ? 16 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.drop_promptLibraryWriteMode,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PromptLibraryWriteMode>(
                    key: const ValueKey('prompt-library-write-mode'),
                    direction: useCompactLayout
                        ? Axis.vertical
                        : Axis.horizontal,
                    segments: [
                      ButtonSegment(
                        value: PromptLibraryWriteMode.create,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(context.l10n.drop_promptLibraryCreate),
                      ),
                      ButtonSegment(
                        value: PromptLibraryWriteMode.append,
                        icon: const Icon(Icons.playlist_add, size: 18),
                        label: Text(context.l10n.drop_promptLibraryAppend),
                      ),
                      ButtonSegment(
                        value: PromptLibraryWriteMode.overwrite,
                        icon: const Icon(Icons.find_replace, size: 18),
                        label: Text(context.l10n.drop_promptLibraryOverwrite),
                      ),
                    ],
                    selected: {_mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() {
                        _mode = selection.single;
                        _targetEntryId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_mode == PromptLibraryWriteMode.create) ...[
                    Text(
                      context.l10n.tagLibrary_entryName,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('prompt-library-name'),
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: context.l10n.tagLibrary_entryNameHint,
                        errorText: hasNameConflict
                            ? context.l10n.drop_promptLibraryNameConflict
                            : null,
                        helperText: context.l10n.drop_promptLibraryAliasHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.tagLibrary_category,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SafeDropdown<String>(
                      value: _selectedCategoryId ?? _rootCategoryValue,
                      items: [
                        DropdownMenuItem(
                          value: _rootCategoryValue,
                          child: Text(context.l10n.tagLibrary_rootCategory),
                        ),
                        ...library.categories.map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              library.categories.getPathString(category.id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value == _rootCategoryValue
                              ? null
                              : value;
                        });
                      },
                    ),
                  ] else ...[
                    Text(
                      context.l10n.drop_promptLibraryTarget,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SafeDropdown<String>(
                      value: _targetEntryId,
                      hintText: context.l10n.drop_promptLibrarySelectTarget,
                      items: entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.id,
                              child: Text(
                                entry.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _targetEntryId = value);
                      },
                    ),
                    if (_mode == PromptLibraryWriteMode.append) ...[
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.drop_promptLibrarySeparator,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SafeDropdown<PromptAppendSeparator>(
                        value: _separator,
                        items: [
                          DropdownMenuItem(
                            value: PromptAppendSeparator.commaSpace,
                            child: Text(
                              context.l10n.drop_promptLibrarySeparatorComma,
                            ),
                          ),
                          DropdownMenuItem(
                            value: PromptAppendSeparator.newline,
                            child: Text(
                              context.l10n.drop_promptLibrarySeparatorNewline,
                            ),
                          ),
                          DropdownMenuItem(
                            value: PromptAppendSeparator.none,
                            child: Text(
                              context.l10n.drop_promptLibrarySeparatorNone,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _separator = value);
                          }
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        context.l10n.tagLibrary_content,
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        context.l10n.drop_promptLibraryCharacterCount(
                          _contentController.text.characters.length,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('prompt-library-content'),
                    controller: _contentController,
                    minLines: 3,
                    maxLines: 7,
                    decoration: InputDecoration(
                      alignLabelWithHint: true,
                      helperText:
                          context.l10n.drop_promptLibraryExactContentHint,
                    ),
                  ),
                  if (_mode == PromptLibraryWriteMode.append &&
                      targetEntry != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.drop_promptLibraryResultPreview,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          appendPromptSnippet(
                            targetEntry.content,
                            _contentController.text,
                            _separator,
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                  if (duplicate != null) ...[
                    const SizedBox(height: 12),
                    _InlineMessage(
                      icon: Icons.info_outline,
                      text: context.l10n.drop_promptLibraryDuplicate(
                        duplicate.displayName,
                      ),
                      color: theme.colorScheme.tertiary,
                    ),
                  ],
                  if (_mode == PromptLibraryWriteMode.overwrite &&
                      targetEntry != null) ...[
                    const SizedBox(height: 12),
                    _InlineMessage(
                      icon: Icons.warning_amber_rounded,
                      text: context.l10n.drop_promptLibraryOverwriteWarning(
                        targetEntry.displayName,
                      ),
                      color: theme.colorScheme.error,
                    ),
                  ],
                  if (_mode == PromptLibraryWriteMode.create) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _showMore = !_showMore),
                      icon: Icon(
                        _showMore ? Icons.expand_less : Icons.expand_more,
                      ),
                      label: Text(context.l10n.drop_promptLibraryMore),
                    ),
                    if (_showMore) ...[
                      const SizedBox(height: 4),
                      TextField(
                        controller: _tagsController,
                        decoration: InputDecoration(
                          labelText: context.l10n.tagLibrary_tags,
                          hintText: context.l10n.tagLibrary_tagsHint,
                          helperText: context.l10n.tagLibrary_tagsHelper,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  _DialogActions(
                    useVerticalLayout: useCompactLayout,
                    saving: _saving,
                    canSave: _canSave(entries),
                    saveLabel: _mode == PromptLibraryWriteMode.overwrite
                        ? context.l10n.drop_promptLibraryConfirmOverwrite
                        : context.l10n.tagLibrary_confirmAdd,
                    cancelLabel: context.l10n.common_cancel,
                    onCancel: () => Navigator.of(context).pop(false),
                    onSave: () => _save(entries, targetEntry),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _save(
    List<TagLibraryEntry> entries,
    TagLibraryEntry? targetEntry,
  ) async {
    if (!_canSave(entries)) return;
    setState(() => _saving = true);

    try {
      final notifier = ref.read(tagLibraryPageNotifierProvider.notifier);
      final requestedName = _nameController.text.trim();
      late final String expectedContent;
      switch (_mode) {
        case PromptLibraryWriteMode.create:
          final tags = _tagsController.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toSet()
              .toList();
          expectedContent = _contentController.text;
          await notifier.addEntry(
            name: _nameController.text,
            content: expectedContent,
            tags: tags,
            categoryId: _selectedCategoryId,
            preserveContentWhitespace: true,
            failOnPersistenceError: true,
          );
        case PromptLibraryWriteMode.append:
          if (targetEntry == null) return;
          expectedContent = appendPromptSnippet(
            targetEntry.content,
            _contentController.text,
            _separator,
          );
          await notifier.updateEntry(
            targetEntry.copyWith(
              content: expectedContent,
              updatedAt: DateTime.now(),
            ),
            failOnPersistenceError: true,
          );
        case PromptLibraryWriteMode.overwrite:
          if (targetEntry == null) return;
          expectedContent = _contentController.text;
          await notifier.updateEntry(
            targetEntry.copyWith(
              content: expectedContent,
              updatedAt: DateTime.now(),
            ),
            failOnPersistenceError: true,
          );
      }

      final state = ref.read(tagLibraryPageNotifierProvider);
      final saved = _mode == PromptLibraryWriteMode.create
          ? state.entries.any(
              (entry) =>
                  entry.name.trim().toLowerCase() ==
                      requestedName.toLowerCase() &&
                  entry.content == expectedContent,
            )
          : state.entries.any(
              (entry) =>
                  entry.id == targetEntry!.id &&
                  entry.content == expectedContent,
            );
      if (!saved) {
        if (mounted) {
          AppToast.error(
            context,
            state.error ?? context.l10n.drop_promptLibrarySaveFailed,
          );
        }
        return;
      }

      if (!mounted) return;
      AppToast.success(context, context.l10n.drop_promptLibrarySaved);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          '${context.l10n.drop_promptLibrarySaveFailed}: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DialogActions extends StatelessWidget {
  final bool useVerticalLayout;
  final bool saving;
  final bool canSave;
  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _DialogActions({
    required this.useVerticalLayout,
    required this.saving,
    required this.canSave,
    required this.cancelLabel,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cancelButton = TextButton(
      onPressed: saving ? null : onCancel,
      child: Text(cancelLabel),
    );
    final saveButton = FilledButton(
      onPressed: canSave ? onSave : null,
      child: saving
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
              ),
            )
          : Text(saveLabel),
    );

    if (useVerticalLayout) {
      return Column(
        key: const ValueKey('prompt-library-actions-vertical'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cancelButton, const SizedBox(height: 8), saveButton],
      );
    }

    return Wrap(
      key: const ValueKey('prompt-library-actions-horizontal'),
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [cancelButton, saveButton],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InlineMessage({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
