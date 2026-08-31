import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../../data/models/gallery/nai_prompt_export_codec.dart';

/// Reuses the image-metadata prompt categories for both privacy-safe positive
/// copying and complete/custom prompt export.
class PromptCopyDialog extends StatefulWidget {
  const PromptCopyDialog._({required this.metadata, required this.exportMode});

  final NaiImageMetadata metadata;
  final bool exportMode;

  static Future<String?> show(
    BuildContext context, {
    required NaiImageMetadata metadata,
  }) => showDialog<String>(
    context: context,
    builder: (_) => PromptCopyDialog._(metadata: metadata, exportMode: false),
  );

  static Future<String?> showExport(
    BuildContext context, {
    required NaiImageMetadata metadata,
  }) => showDialog<String>(
    context: context,
    builder: (_) => PromptCopyDialog._(metadata: metadata, exportMode: true),
  );

  @override
  State<PromptCopyDialog> createState() => _PromptCopyDialogState();
}

class _PromptCopyDialogState extends State<PromptCopyDialog> {
  late NaiImageMetadata _metadata;
  var _includeMainPrompt = true;
  var _includeCharacterPrompts = true;
  var _includeQualityTags = false;
  var _includeFixedTags = false;
  late NaiPromptCopySelection _exportSelection;

  @override
  void initState() {
    super.initState();
    _metadata = widget.metadata;
    _includeMainPrompt = _hasMainPrompt;
    _includeCharacterPrompts = _hasCharacters;
    _exportSelection = NaiPromptCopySelection.all(_metadata);
  }

  bool get _hasMainPrompt {
    final body = _metadata.hasSeparatedFields
        ? _metadata.mainPrompt
        : _metadata.prompt;
    return body.trim().isNotEmpty;
  }

  bool get _hasCharacters =>
      _metadata.characterPrompts.any((prompt) => prompt.trim().isNotEmpty);
  bool get _hasQualityTags => NaiPromptExportCodec.hasQualityTags(_metadata);
  bool get _hasFixedTags => NaiPromptExportCodec.hasFixedPositive(_metadata);

  bool get _canCopy => widget.exportMode
      ? _exportSelection.hasSelection
      : (_includeMainPrompt && _hasMainPrompt) ||
            (_includeCharacterPrompts && _hasCharacters) ||
            (_includeQualityTags && _hasQualityTags) ||
            (_includeFixedTags && _hasFixedTags);

  String _buildPrompt() => _metadata.buildPositivePromptSelection(
    includeMainPrompt: _includeMainPrompt,
    includeCharacterPrompts: _includeCharacterPrompts,
    includeQualityTags: _includeQualityTags,
    includeFixedTags: _includeFixedTags,
  );

  void _copy() {
    final result = widget.exportMode
        ? NaiPromptExportCodec.encode(_metadata, selection: _exportSelection)
        : _buildPrompt();
    if (result.isEmpty) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.exportMode) return _buildSafeDialog(context);
    return AlertDialog(
      title: Text(context.l10n.promptCopy_exportTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: SingleChildScrollView(child: _buildExportOptions()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
        FilledButton.icon(
          onPressed: _canCopy ? _copy : null,
          icon: const Icon(Icons.copy, size: 18),
          label: Text(context.l10n.common_copy),
        ),
      ],
    );
  }

  Widget _buildSafeDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fixedCount =
        _metadata.fixedPrefixTags.length + _metadata.fixedSuffixTags.length;
    final qualityCount =
        _metadata.qualityTags.length +
        (_metadata.hasRecordedTransparentBackgroundTag ? 1 : 0);

    return AlertDialog(
      icon: Icon(Icons.privacy_tip_outlined, color: colorScheme.primary),
      title: Text(context.l10n.detail_copyPromptTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.detail_copyPromptDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PromptCategoryTile(
                      icon: Icons.subject,
                      title: context.l10n.detail_promptCategoryMain,
                      subtitle: context.l10n.detail_promptCategoryMainHint,
                      value: _includeMainPrompt,
                      enabled: _hasMainPrompt,
                      onChanged: (value) =>
                          setState(() => _includeMainPrompt = value),
                    ),
                    const Divider(height: 1),
                    _PromptCategoryTile(
                      icon: Icons.people_outline,
                      title: context.l10n.detail_promptCategoryCharacters,
                      subtitle:
                          context.l10n.detail_promptCategoryCharactersHint,
                      count: _metadata.characterPrompts.length,
                      value: _includeCharacterPrompts,
                      enabled: _hasCharacters,
                      onChanged: (value) =>
                          setState(() => _includeCharacterPrompts = value),
                    ),
                    const Divider(height: 1),
                    _PromptCategoryTile(
                      icon: Icons.auto_awesome_outlined,
                      title: context.l10n.detail_promptCategoryQuality,
                      subtitle: context.l10n.detail_promptCategoryQualityHint,
                      count: qualityCount,
                      value: _includeQualityTags,
                      enabled: _hasQualityTags,
                      onChanged: (value) =>
                          setState(() => _includeQualityTags = value),
                    ),
                    const Divider(height: 1),
                    _PromptCategoryTile(
                      icon: Icons.push_pin_outlined,
                      title: context.l10n.detail_promptCategoryFixed,
                      subtitle: context.l10n.detail_promptCategoryFixedHint,
                      count: fixedCount,
                      value: _includeFixedTags,
                      enabled: _hasFixedTags,
                      warning: true,
                      onChanged: (value) =>
                          setState(() => _includeFixedTags = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.detail_copyPromptDefaultHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
        FilledButton.icon(
          onPressed: _canCopy ? _copy : null,
          icon: const Icon(Icons.copy, size: 17),
          label: Text(context.l10n.common_copy),
        ),
      ],
    );
  }

  Widget _buildExportOptions() {
    final characterCount = NaiPromptExportCodec.characterCount(_metadata);
    final positiveCharacters = {
      for (var index = 0; index < characterCount; index++)
        if (NaiPromptExportCodec.characterPositive(_metadata, index).isNotEmpty)
          index,
    };
    final negativeCharacters = {
      for (var index = 0; index < characterCount; index++)
        if (NaiPromptExportCodec.characterNegative(_metadata, index).isNotEmpty)
          index,
    };
    final hasMainPositive = NaiPromptExportCodec.mainPositive(
      _metadata,
    ).isNotEmpty;
    final hasMainNegative = NaiPromptExportCodec.mainNegative(
      _metadata,
    ).isNotEmpty;
    final hasFixedPositive = NaiPromptExportCodec.hasFixedPositive(_metadata);
    final hasFixedNegative = NaiPromptExportCodec.hasFixedNegative(_metadata);
    final hasQuality = NaiPromptExportCodec.hasQualityTags(_metadata);
    final positiveValues = <bool>[
      if (hasMainPositive) _exportSelection.mainPositive,
      if (hasFixedPositive) _exportSelection.fixedPositive,
      if (hasQuality) _exportSelection.qualityTags,
      for (final index in positiveCharacters)
        _exportSelection.characterPositiveIndices.contains(index),
    ];
    final negativeValues = <bool>[
      if (hasMainNegative) _exportSelection.mainNegative,
      if (hasFixedNegative) _exportSelection.fixedNegative,
      for (final index in negativeCharacters)
        _exportSelection.characterNegativeIndices.contains(index),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (positiveValues.isNotEmpty) ...[
          _parentTile(
            label: context.l10n.promptCopy_allPositive,
            values: positiveValues,
            onChanged: (value) => _setAllPositive(
              value,
              positiveCharacters,
              hasMainPositive: hasMainPositive,
              hasFixedPositive: hasFixedPositive,
              hasQuality: hasQuality,
            ),
          ),
          if (hasMainPositive)
            _childTile(
              label: context.l10n.promptCopy_mainPositive,
              value: _exportSelection.mainPositive,
              onChanged: (value) =>
                  _update(_exportSelection.copyWith(mainPositive: value)),
            ),
          if (hasFixedPositive)
            _childTile(
              label: context.l10n.promptCopy_fixedPositive,
              value: _exportSelection.fixedPositive,
              onChanged: (value) =>
                  _update(_exportSelection.copyWith(fixedPositive: value)),
            ),
          if (hasQuality)
            _childTile(
              label: context.l10n.detail_promptCategoryQuality,
              value: _exportSelection.qualityTags,
              onChanged: (value) =>
                  _update(_exportSelection.copyWith(qualityTags: value)),
            ),
          for (final index in positiveCharacters)
            _childTile(
              label: context.l10n.promptCopy_characterPositive(index + 1),
              value: _exportSelection.characterPositiveIndices.contains(index),
              onChanged: (value) => _setCharacterPositive(index, value),
            ),
        ],
        if (negativeValues.isNotEmpty) ...[
          if (positiveValues.isNotEmpty) const Divider(height: 24),
          _parentTile(
            label: context.l10n.promptCopy_allNegative,
            values: negativeValues,
            onChanged: (value) => _setAllNegative(
              value,
              negativeCharacters,
              hasMainNegative: hasMainNegative,
              hasFixedNegative: hasFixedNegative,
            ),
          ),
          if (hasMainNegative)
            _childTile(
              label: context.l10n.promptCopy_mainNegative,
              value: _exportSelection.mainNegative,
              onChanged: (value) =>
                  _update(_exportSelection.copyWith(mainNegative: value)),
            ),
          if (hasFixedNegative)
            _childTile(
              label: context.l10n.promptCopy_fixedNegative,
              value: _exportSelection.fixedNegative,
              onChanged: (value) =>
                  _update(_exportSelection.copyWith(fixedNegative: value)),
            ),
          for (final index in negativeCharacters)
            _childTile(
              label: context.l10n.promptCopy_characterNegative(index + 1),
              value: _exportSelection.characterNegativeIndices.contains(index),
              onChanged: (value) => _setCharacterNegative(index, value),
            ),
        ],
      ],
    );
  }

  Widget _parentTile({
    required String label,
    required List<bool> values,
    required ValueChanged<bool> onChanged,
  }) {
    final selectedCount = values.where((value) => value).length;
    return CheckboxListTile(
      value: selectedCount == 0
          ? false
          : selectedCount == values.length
          ? true
          : null,
      tristate: true,
      onChanged: (_) => onChanged(selectedCount != values.length),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _childTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => CheckboxListTile(
    value: value,
    onChanged: (next) => onChanged(next ?? value),
    title: Text(label),
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: const EdgeInsetsDirectional.only(start: 24),
    dense: true,
  );

  void _setAllPositive(
    bool value,
    Set<int> characterIndices, {
    required bool hasMainPositive,
    required bool hasFixedPositive,
    required bool hasQuality,
  }) => _update(
    _exportSelection.copyWith(
      mainPositive: hasMainPositive && value,
      fixedPositive: hasFixedPositive && value,
      qualityTags: hasQuality && value,
      characterPositiveIndices: value ? characterIndices : const {},
    ),
  );

  void _setAllNegative(
    bool value,
    Set<int> characterIndices, {
    required bool hasMainNegative,
    required bool hasFixedNegative,
  }) => _update(
    _exportSelection.copyWith(
      mainNegative: hasMainNegative && value,
      fixedNegative: hasFixedNegative && value,
      characterNegativeIndices: value ? characterIndices : const {},
    ),
  );

  void _setCharacterPositive(int index, bool value) {
    final indices = {..._exportSelection.characterPositiveIndices};
    value ? indices.add(index) : indices.remove(index);
    _update(_exportSelection.copyWith(characterPositiveIndices: indices));
  }

  void _setCharacterNegative(int index, bool value) {
    final indices = {..._exportSelection.characterNegativeIndices};
    value ? indices.add(index) : indices.remove(index);
    _update(_exportSelection.copyWith(characterNegativeIndices: indices));
  }

  void _update(NaiPromptCopySelection selection) {
    setState(() => _exportSelection = selection);
  }
}

class _PromptCategoryTile extends StatelessWidget {
  const _PromptCategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.count,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int? count;
  final bool value;
  final bool enabled;
  final bool warning;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = warning ? colorScheme.tertiary : colorScheme.primary;

    return CheckboxListTile(
      value: enabled && value,
      onChanged: enabled ? (value) => onChanged(value ?? false) : null,
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: Icon(
        icon,
        size: 20,
        color: enabled ? accent : colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        enabled ? subtitle : context.l10n.detail_promptCategoryUnavailable,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      activeColor: accent,
      dense: true,
    );
  }
}
