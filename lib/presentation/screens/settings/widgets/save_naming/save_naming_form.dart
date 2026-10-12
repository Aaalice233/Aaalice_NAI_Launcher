import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/save_naming/image_save_naming.dart';
import '../../../../../core/save_naming/save_name_context.dart';
import '../../../../../core/save_naming/save_name_template.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../adaptive/adaptive_form_footer.dart';
import '../../../../adaptive/content_sized_adaptive_form.dart';
import '../../../../themes/design_tokens.dart';
import '../settings_card.dart';
import 'save_naming_messages.dart';
import 'save_naming_preview_sample.dart';
import 'save_naming_rule_section.dart';
import 'save_naming_syntax_help.dart';

/// 编辑子文件夹与文件名规则；取消或关闭时返回 null。
Future<ImageSaveNaming?> showSaveNamingForm(
  BuildContext context, {
  required ImageSaveNaming initial,
}) => AdaptivePresenter.showForm<ImageSaveNaming>(
  context: context,
  title: context.l10n.settings_saveNaming,
  dialogWidth: 640,
  headerScrollsWithContent: true,
  builder: (context, scrollController) =>
      SaveNamingForm(initial: initial, scrollController: scrollController),
);

const List<SaveNameToken> _folderTokens = [
  SaveNameToken.date,
  SaveNameToken.year,
  SaveNameToken.month,
  SaveNameToken.day,
  SaveNameToken.model,
  SaveNameToken.modelName,
  SaveNameToken.type,
  SaveNameToken.characters,
  SaveNameToken.prompt,
  SaveNameToken.seed,
  SaveNameToken.resolution,
];

const List<SaveNameToken> _fileNameTokens = [
  SaveNameToken.prompt,
  SaveNameToken.seed,
  SaveNameToken.date,
  SaveNameToken.time,
  SaveNameToken.characters,
  SaveNameToken.model,
  SaveNameToken.modelName,
  SaveNameToken.resolution,
  SaveNameToken.width,
  SaveNameToken.height,
  SaveNameToken.type,
  SaveNameToken.imageIndex,
  SaveNameToken.imageId,
  SaveNameToken.year,
  SaveNameToken.month,
  SaveNameToken.day,
];

class SaveNamingForm extends ConsumerStatefulWidget {
  const SaveNamingForm({
    super.key,
    required this.initial,
    required this.scrollController,
  });

  final ImageSaveNaming initial;
  final ScrollController scrollController;

  @override
  ConsumerState<SaveNamingForm> createState() => _SaveNamingFormState();
}

class _SaveNamingFormState extends ConsumerState<SaveNamingForm> {
  late final TextEditingController _folderController;
  late final TextEditingController _fileNameController;
  final FocusNode _folderFocus = FocusNode();
  final FocusNode _fileNameFocus = FocusNode();
  late String _folderKey;
  late String _fileNameKey;
  late final SaveNamingPreviewSample _fallbackSample;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final folderPreset = SaveFolderPreset.match(initial.folderTemplate);
    final fileNamePreset = SaveFileNamePreset.match(initial.fileNameTemplate);
    _folderKey = folderPreset?.name ?? SaveNamingRuleSection.customKey;
    _fileNameKey = fileNamePreset?.name ?? SaveNamingRuleSection.customKey;
    _folderController = TextEditingController(text: initial.folderTemplate);
    _fileNameController = TextEditingController(text: initial.fileNameTemplate);
    _fallbackSample = SaveNamingPreviewSample.builtIn(DateTime.now());
  }

  @override
  void dispose() {
    _folderController.dispose();
    _fileNameController.dispose();
    _folderFocus.dispose();
    _fileNameFocus.dispose();
    super.dispose();
  }

  String get _folderTemplate => _folderKey == SaveNamingRuleSection.customKey
      ? _folderController.text
      : SaveFolderPreset.values.byName(_folderKey).template;

  String get _fileNameTemplate =>
      _fileNameKey == SaveNamingRuleSection.customKey
      ? _fileNameController.text
      : SaveFileNamePreset.values.byName(_fileNameKey).template;

  String? _folderError(AppLocalizations l10n) {
    final error = SaveNameTemplate.validate(_folderTemplate);
    return error == null ? null : l10n.saveNameTemplateError(error);
  }

  String? _fileNameError(AppLocalizations l10n) {
    if (_fileNameTemplate.trim().isEmpty) {
      return l10n.settings_saveNamingFileNameEmpty;
    }
    final error = SaveNameTemplate.validate(_fileNameTemplate);
    return error == null ? null : l10n.saveNameTemplateError(error);
  }

  // 切到自定义时以当前生效的预设为起点，免得从空白开始写。
  void _selectFolder(String key) => setState(() {
    if (key == SaveNamingRuleSection.customKey &&
        _folderKey != SaveNamingRuleSection.customKey) {
      _folderController.text = _folderTemplate;
    }
    _folderKey = key;
  });

  void _selectFileName(String key) => setState(() {
    if (key == SaveNamingRuleSection.customKey &&
        _fileNameKey != SaveNamingRuleSection.customKey) {
      _fileNameController.text = _fileNameTemplate;
    }
    _fileNameKey = key;
  });

  void _restoreDefaults() => setState(() {
    _folderKey = SaveFolderPreset.byDate.name;
    _fileNameKey = SaveFileNamePreset.timeSeed.name;
  });

  void _save() => Navigator.of(context).pop(
    ImageSaveNaming(
      folderTemplate: _folderTemplate,
      fileNameTemplate: _fileNameTemplate,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sample =
        ref.watch(saveNamingPreviewSampleProvider).value ?? _fallbackSample;
    final folderError = _folderError(l10n);
    final fileNameError = _fileNameError(l10n);
    final valid = folderError == null && fileNameError == null;
    final naming = ImageSaveNaming(
      folderTemplate: _folderTemplate,
      fileNameTemplate: _fileNameTemplate,
    );
    return ContentSizedAdaptiveForm(
      scrollController: widget.scrollController,
      scrollViewKey: const ValueKey('save-naming-form-scroll'),
      padding: const EdgeInsets.all(DesignTokens.spacingMd),
      content: [
        SaveNamingRuleSection(
          sectionKey: 'folder',
          title: l10n.settings_saveNamingFolderSection,
          icon: Icons.folder_outlined,
          options: [
            for (final preset in SaveFolderPreset.values)
              SaveNamingOption(
                key: preset.name,
                label: _folderPresetLabel(l10n, preset),
                example: preset == SaveFolderPreset.none
                    ? l10n.settings_saveNamingFolderNoneExample
                    : _folderExample(
                        ImageSaveNaming(folderTemplate: preset.template),
                        sample.context,
                      ),
              ),
          ],
          selectedKey: _folderKey,
          onSelected: _selectFolder,
          customExample: folderError == null
              ? _folderExample(naming, sample.context)
              : '',
          templateLabel: l10n.settings_saveNamingFolderTemplate,
          templateHelper: l10n.settings_saveNamingFolderTemplateHelper,
          controller: _folderController,
          focusNode: _folderFocus,
          errorText: folderError,
          onTemplateChanged: (_) => setState(() {}),
          insertableTokens: _folderTokens,
        ),
        const SizedBox(height: DesignTokens.spacingMd),
        SaveNamingRuleSection(
          sectionKey: 'file-name',
          title: l10n.settings_saveNamingFileNameSection,
          icon: Icons.insert_drive_file_outlined,
          options: [
            for (final preset in SaveFileNamePreset.values)
              SaveNamingOption(
                key: preset.name,
                label: _fileNamePresetLabel(l10n, preset),
                example:
                    '${ImageSaveNaming(fileNameTemplate: preset.template).fileStem(sample.context)}.png',
              ),
          ],
          selectedKey: _fileNameKey,
          onSelected: _selectFileName,
          customExample: fileNameError == null
              ? '${naming.fileStem(sample.context)}.png'
              : '',
          templateLabel: l10n.settings_saveNamingFileNameTemplate,
          templateHelper: l10n.settings_saveNamingFileNameTemplateHelper,
          controller: _fileNameController,
          focusNode: _fileNameFocus,
          errorText: fileNameError,
          onTemplateChanged: (_) => setState(() {}),
          insertableTokens: _fileNameTokens,
        ),
        const SizedBox(height: DesignTokens.spacingMd),
        _PreviewSection(
          naming: valid ? naming : null,
          sample: sample,
          onShowHelp: () =>
              showSaveNamingSyntaxHelp(context, sample: sample.context),
        ),
      ],
      footer: AdaptiveFormFooter(
        leading: [
          TextButton(
            key: const ValueKey('save-naming-restore-defaults'),
            onPressed: _restoreDefaults,
            child: Text(l10n.settings_saveNamingRestoreDefaults),
          ),
        ],
        primary: FilledButton(
          onPressed: valid ? _save : null,
          child: Text(context.l10n.common_save),
        ),
      ),
    );
  }
}

String _folderExample(ImageSaveNaming naming, SaveNameContext sample) {
  final segments = naming.folderSegments(sample);
  return segments.isEmpty ? '' : '${segments.join('/')}/';
}

String _folderPresetLabel(AppLocalizations l10n, SaveFolderPreset preset) =>
    switch (preset) {
      SaveFolderPreset.byDate => l10n.settings_saveNamingFolderByDate,
      SaveFolderPreset.byMonth => l10n.settings_saveNamingFolderByMonth,
      SaveFolderPreset.byYearMonth => l10n.settings_saveNamingFolderByYearMonth,
      SaveFolderPreset.none => l10n.settings_saveNamingFolderNone,
    };

String _fileNamePresetLabel(AppLocalizations l10n, SaveFileNamePreset preset) =>
    switch (preset) {
      SaveFileNamePreset.timeSeed => l10n.settings_saveNamingFileTimeSeed,
      SaveFileNamePreset.dateTimeSeed =>
        l10n.settings_saveNamingFileDateTimeSeed,
      SaveFileNamePreset.promptSeed => l10n.settings_saveNamingFilePromptSeed,
    };

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.naming,
    required this.sample,
    required this.onShowHelp,
  });

  /// 模板有错误时为 null，此时不显示路径。
  final ImageSaveNaming? naming;
  final SaveNamingPreviewSample sample;
  final VoidCallback onShowHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final naming = this.naming;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SettingsCard(
      key: const ValueKey('save-naming-preview'),
      title: l10n.settings_saveNamingPreview,
      icon: Icons.visibility_outlined,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.spacingMd,
          0,
          DesignTokens.spacingMd,
          DesignTokens.spacingXs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (naming != null)
              SelectableText(
                naming.resolve(sample.context).relativeFileName,
                key: const ValueKey('save-naming-preview-path'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: DesignTokens.spacingXxs),
            Text(
              sample.fromLatestImage
                  ? l10n.settings_saveNamingPreviewLatest
                  : l10n.settings_saveNamingPreviewSample,
              style: secondary,
            ),
            if (naming != null && naming.omitsDate) ...[
              const SizedBox(height: DesignTokens.spacingXs),
              Row(
                key: const ValueKey('save-naming-omits-date-hint'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: DesignTokens.iconSm,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: DesignTokens.spacingXs),
                  Expanded(
                    child: Text(
                      l10n.settings_saveNamingOmitsDateHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: DesignTokens.spacingXs),
            Text(l10n.settings_saveNamingAppliesToNewHint, style: secondary),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('save-naming-syntax-help'),
                onPressed: onShowHelp,
                icon: const Icon(Icons.help_outline),
                label: Text(l10n.settings_saveNamingSyntaxHelp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
