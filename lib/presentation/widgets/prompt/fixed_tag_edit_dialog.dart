import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../providers/image_generation_provider.dart';
import '../../themes/core/input_surface_style.dart';
import '../../providers/tag_library_page_provider.dart';
import '../autocomplete/autocomplete.dart';
import '../common/prefix_suffix_switch.dart';
import '../common/themed_input.dart';
import '../common/themed_slider.dart';
import '../prompt/nai_syntax_controller.dart';
import '../prompt/prompt_formatter_wrapper.dart';

/// 固定词编辑对话框
class FixedTagEditDialog extends ConsumerStatefulWidget {
  /// 要编辑的条目，如果为 null 则为新建模式
  final FixedTagEntry? entry;
  final FixedTagPromptType initialPromptType;

  const FixedTagEditDialog({
    super.key,
    this.entry,
    this.initialPromptType = FixedTagPromptType.positive,
  });

  @override
  ConsumerState<FixedTagEditDialog> createState() => _FixedTagEditDialogState();
}

class _FixedTagEditDialogState extends ConsumerState<FixedTagEditDialog> {
  late final TextEditingController _nameController;
  late final NaiSyntaxController _contentController;
  late FixedTagPosition _position;
  late FixedTagPromptType _promptType;
  late double _weight;
  late bool _enabled;
  bool _saveToLibrary = false;
  String? _selectedCategoryId;

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
    _promptType = entry?.promptType ?? widget.initialPromptType;
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
    _contentController.highlightEnabled = ref.watch(
      highlightEmphasisSettingsProvider,
    );
    _contentController.numericEmphasisEnabled = ImageModels.isV4Model(
      ref.watch(
        generationParamsNotifierProvider.select((params) => params.model),
      ),
    );

    final mediaSize = MediaQuery.sizeOf(context);
    final isWide = mediaSize.width >= 760;
    final dialogWidth = isWide
        ? 860.0
        : (mediaSize.width - 32).clamp(0.0, 560.0).toDouble();
    final dialogHeight = (mediaSize.height - (isWide ? 48 : 32))
        .clamp(0.0, 680.0)
        .toDouble();

    return Dialog(
      insetPadding: EdgeInsets.all(isWide ? 24 : 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: isWide ? _buildWideBody(theme) : _buildNarrowBody(theme),
            ),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
        child: Row(
          children: [
            Icon(
              _isEditing ? Icons.edit_outlined : Icons.add,
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
      ),
    );
  }

  Widget _buildWideBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildEditorPane(theme, expanded: true)),
          const SizedBox(width: 32),
          SizedBox(
            width: 250,
            child: SingleChildScrollView(child: _buildSettingsPane(theme)),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowBody(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEditorPane(theme, expanded: false),
          const SizedBox(height: 28),
          _buildSettingsPane(theme),
        ],
      ),
    );
  }

  Widget _buildEditorPane(ThemeData theme, {required bool expanded}) {
    final promptEditor = _buildPromptEditor();
    return Column(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.entry?.sourceEntryId != null) ...[
          _buildLibraryLinkBanner(theme),
          const SizedBox(height: 16),
        ],
        Text(context.l10n.fixedTags_name, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        ThemedInput(
          controller: _nameController,
          focusNode: _nameFocusNode,
          hintText: context.l10n.fixedTags_nameHint,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _contentFocusNode.requestFocus(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              context.l10n.fixedTags_content,
              style: theme.textTheme.labelLarge,
            ),
            const Spacer(),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contentController,
              builder: (context, value, child) => Text(
                '${value.text.characters.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (expanded)
          Expanded(child: promptEditor)
        else
          SizedBox(height: 280, child: promptEditor),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            context.l10n.fixedTags_syntaxHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 12,
            ),
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryLinkBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_alt, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.fixedTags_linkedFromLibrary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptEditor() {
    return PromptFormatterWrapper(
      controller: _contentController,
      focusNode: _contentFocusNode,
      enableAutoFormat: ref.watch(autoFormatPromptSettingsProvider),
      child: AutocompleteWrapper.withAlias(
        controller: _contentController,
        focusNode: _contentFocusNode,
        ref: ref,
        expands: true,
        config: const AutocompleteConfig(
          showTranslation: true,
          showCategory: true,
          autoInsertComma: true,
        ),
        child: ThemedInput(
          controller: _contentController,
          focusNode: _contentFocusNode,
          decoration: InputDecoration(
            hintText: context.l10n.fixedTags_contentHint,
            contentPadding: const EdgeInsets.all(12),
          ),
          maxLines: null,
          expands: true,
        ),
      ),
    );
  }

  Widget _buildSettingsPane(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.fixedTags_scope, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<FixedTagPromptType>(
            segments: [
              ButtonSegment(
                value: FixedTagPromptType.positive,
                label: Text(context.l10n.fixedTags_positive),
              ),
              ButtonSegment(
                value: FixedTagPromptType.negative,
                label: Text(context.l10n.fixedTags_negative),
              ),
            ],
            selected: {_promptType},
            onSelectionChanged: (selection) {
              setState(() => _promptType = selection.first);
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.fixedTags_position,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Center(
          child: PrefixSuffixSwitch(
            value: _position,
            onChanged: (value) => setState(() => _position = value),
            prefixLabel: context.l10n.fixedTags_prefix,
            suffixLabel: context.l10n.fixedTags_suffix,
          ),
        ),
        const SizedBox(height: 20),
        _buildWeightControl(theme),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.l10n.fixedTags_enabled,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          dense: true,
        ),
        if (!_isEditing) ...[
          const SizedBox(height: 8),
          _buildSaveToLibrary(theme),
        ],
      ],
    );
  }

  Widget _buildWeightControl(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.l10n.fixedTags_weight,
              style: theme.textTheme.labelLarge,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_weight.toStringAsFixed(2)}x',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('0.5', style: theme.textTheme.bodySmall),
            const SizedBox(width: 8),
            Expanded(
              child: ThemedSlider(
                value: _weight,
                min: 0.5,
                max: 2.0,
                divisions: 30,
                onChanged: (value) => setState(() => _weight = value),
              ),
            ),
            const SizedBox(width: 8),
            Text('2.0', style: theme.textTheme.bodySmall),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: context.l10n.fixedTags_resetWeight,
              onPressed: () => setState(() => _weight = 1.0),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (_weight != 1.0) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contentController,
              builder: (context, value, child) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.fixedTags_weightPreview,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getWeightPreview(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveToLibrary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _saveToLibrary
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _saveToLibrary
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _saveToLibrary = !_saveToLibrary),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Checkbox(
                  value: _saveToLibrary,
                  onChanged: (value) =>
                      setState(() => _saveToLibrary = value ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.bookmark_add_outlined,
                  size: 18,
                  color: _saveToLibrary
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.fixedTags_saveToLibrary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: _saveToLibrary
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                      Text(
                        context.l10n.fixedTags_saveToLibraryHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_saveToLibrary) ...[
            const SizedBox(height: 10),
            _buildCompactCategorySelector(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.common_cancel),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contentController,
              builder: (context, value, child) => FilledButton(
                onPressed: value.text.trim().isNotEmpty ? _save : null,
                child: Text(context.l10n.common_save),
              ),
            ),
          ],
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

  void _save() {
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) return;

    final result =
        widget.entry?.update(
          name: name,
          content: content,
          weight: _weight,
          position: _position,
          promptType: _promptType,
          enabled: _enabled,
        ) ??
        FixedTagEntry.create(
          name: name,
          content: content,
          weight: _weight,
          position: _position,
          promptType: _promptType,
          enabled: _enabled,
        );

    if (_saveToLibrary && !_isEditing) {
      ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .addEntry(
            name: name.isNotEmpty
                ? name
                : content.substring(
                    0,
                    content.length > 20 ? 20 : content.length,
                  ),
            content: content,
            categoryId: _selectedCategoryId,
          );
      ref.invalidate(tagLibraryPageNotifierProvider);
    }

    Navigator.of(context).pop(result);
  }

  Widget _buildCompactCategorySelector(ThemeData theme) {
    final state = ref.watch(tagLibraryPageNotifierProvider);
    final categories = state.categories;
    final items = <DropdownMenuItem<String?>>[];

    items.add(
      DropdownMenuItem<String?>(
        value: null,
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.tagLibrary_rootCategory,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );

    void addCategoryItems(String? parentId, int depth) {
      final children = categories.where((c) => c.parentId == parentId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      for (final category in children) {
        items.add(
          DropdownMenuItem<String?>(
            value: category.id,
            child: Row(
              children: [
                SizedBox(width: (depth * 14.0).clamp(0.0, 56.0).toDouble()),
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.fixedTags_saveToCategory,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: _selectedCategoryId,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            isDense: true,
            filled: true,
            fillColor: inputSurfaceFillColor(theme.colorScheme),
          ),
          items: items,
          onChanged: (value) => setState(() => _selectedCategoryId = value),
          isExpanded: true,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
