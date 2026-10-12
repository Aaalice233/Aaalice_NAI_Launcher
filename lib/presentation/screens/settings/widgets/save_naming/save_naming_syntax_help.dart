import 'package:flutter/material.dart';

import '../../../../../core/save_naming/image_save_naming.dart';
import '../../../../../core/save_naming/save_name_context.dart';
import '../../../../../core/save_naming/save_name_template.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/content_sized_adaptive_form.dart';
import '../../../../themes/design_tokens.dart';
import '../settings_card.dart';
import 'save_naming_messages.dart';

const List<String> _exampleFileNames = [
  '{prompt|tags:3}{seed|pre: s-}',
  '{characters|max:2|join:_}_{time}',
  '{date}_{index|pad:3}',
];

const String _exampleFolder = '{modelname}/{year}-{month}';

Future<void> showSaveNamingSyntaxHelp(
  BuildContext context, {
  required SaveNameContext sample,
}) => AdaptivePresenter.showForm<void>(
  context: context,
  title: context.l10n.settings_saveNamingSyntaxHelp,
  dialogWidth: 640,
  headerScrollsWithContent: true,
  builder: (context, scrollController) => ContentSizedAdaptiveForm(
    scrollController: scrollController,
    scrollViewKey: const ValueKey('save-naming-help-scroll'),
    padding: const EdgeInsets.all(DesignTokens.spacingMd),
    content: [_SaveNamingSyntaxHelpBody(sample: sample)],
  ),
);

class _SaveNamingSyntaxHelpBody extends StatelessWidget {
  const _SaveNamingSyntaxHelpBody({required this.sample});

  final SaveNameContext sample;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final textFilters = [
      for (final kind in SaveNameFilterKind.values)
        if (!kind.characterOnly) kind,
    ];
    final characterFilters = [
      for (final kind in SaveNameFilterKind.values)
        if (kind.characterOnly) kind,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.settings_saveNamingSyntaxIntro),
        const SizedBox(height: DesignTokens.spacingXs),
        SelectableText(
          '{token|filter:arg|filter}',
          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
        ),
        const SizedBox(height: DesignTokens.spacingMd),
        _HelpGroup(
          groupKey: 'fields',
          title: l10n.settings_saveNamingSyntaxFields,
          icon: Icons.data_object,
          rows: [
            for (final token in SaveNameToken.values)
              (
                code: '{${token.id}}',
                description: l10n.saveNameTokenDescription(token),
              ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacingMd),
        _HelpGroup(
          groupKey: 'filters',
          title: l10n.settings_saveNamingSyntaxFilters,
          icon: Icons.filter_alt_outlined,
          rows: [
            for (final kind in textFilters)
              (
                code: saveNameFilterSyntax(kind),
                description: l10n.saveNameFilterDescription(kind),
              ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacingMd),
        _HelpGroup(
          groupKey: 'character-filters',
          title: l10n.settings_saveNamingSyntaxCharacterFilters,
          icon: Icons.people_outline,
          rows: [
            for (final kind in characterFilters)
              (
                code: saveNameFilterSyntax(kind),
                description: l10n.saveNameFilterDescription(kind),
              ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacingMd),
        _HelpGroup(
          groupKey: 'examples',
          title: l10n.settings_saveNamingSyntaxExamples,
          icon: Icons.lightbulb_outline,
          rows: [
            for (final template in _exampleFileNames)
              (
                code: template,
                description:
                    '${ImageSaveNaming(fileNameTemplate: template).fileStem(sample)}.png',
              ),
            (
              code: _exampleFolder,
              description:
                  '${const ImageSaveNaming(folderTemplate: _exampleFolder).folderSegments(sample).join('/')}/',
            ),
          ],
        ),
      ],
    );
  }
}

class _HelpGroup extends StatelessWidget {
  const _HelpGroup({
    required this.groupKey,
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String groupKey;
  final String title;
  final IconData icon;
  final List<({String code, String description})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsCard(
      key: ValueKey('save-naming-help-$groupKey'),
      title: title,
      icon: icon,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.spacingMd,
          0,
          DesignTokens.spacingMd,
          DesignTokens.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) const SizedBox(height: DesignTokens.spacingXs),
              SelectableText(
                row.code,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                row.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
