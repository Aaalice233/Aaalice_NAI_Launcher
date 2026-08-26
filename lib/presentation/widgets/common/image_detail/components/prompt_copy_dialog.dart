import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/gallery/nai_image_metadata.dart';

/// 按提示词类别选择复制范围，默认排除容易泄露私密串的固定词和自动质量词。
class PromptCopyDialog extends StatefulWidget {
  const PromptCopyDialog({super.key, required this.metadata});

  final NaiImageMetadata metadata;

  static Future<String?> show(
    BuildContext context, {
    required NaiImageMetadata metadata,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => PromptCopyDialog(metadata: metadata),
    );
  }

  @override
  State<PromptCopyDialog> createState() => _PromptCopyDialogState();
}

class _PromptCopyDialogState extends State<PromptCopyDialog> {
  late bool _includeMainPrompt;
  late bool _includeCharacterPrompts;
  bool _includeQualityTags = false;
  bool _includeFixedTags = false;

  NaiImageMetadata get _metadata => widget.metadata;

  bool get _hasMainPrompt {
    final body = _metadata.hasSeparatedFields
        ? _metadata.mainPrompt
        : _metadata.prompt;
    return body.trim().isNotEmpty;
  }

  bool get _hasCharacterPrompts =>
      _metadata.characterPrompts.any((prompt) => prompt.trim().isNotEmpty);

  bool get _hasQualityTags =>
      _metadata.qualityTags.isNotEmpty ||
      _metadata.hasRecordedTransparentBackgroundTag;

  bool get _hasFixedTags =>
      _metadata.fixedPrefixTags.isNotEmpty ||
      _metadata.fixedSuffixTags.isNotEmpty;

  String get _selectedPrompt => _metadata.buildPositivePromptSelection(
    includeMainPrompt: _includeMainPrompt,
    includeCharacterPrompts: _includeCharacterPrompts,
    includeQualityTags: _includeQualityTags,
    includeFixedTags: _includeFixedTags,
  );

  @override
  void initState() {
    super.initState();
    _includeMainPrompt = _hasMainPrompt;
    _includeCharacterPrompts = _hasCharacterPrompts;
  }

  @override
  Widget build(BuildContext context) {
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
                      enabled: _hasCharacterPrompts,
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
          onPressed: _selectedPrompt.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedPrompt),
          icon: const Icon(Icons.copy, size: 17),
          label: Text(context.l10n.common_copy),
        ),
      ],
    );
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
