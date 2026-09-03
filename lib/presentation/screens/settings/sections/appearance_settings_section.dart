import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_locale.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/font_scale_provider.dart';
import '../../../providers/generation_layout_mode_provider.dart';
import '../../../providers/history_click_behavior_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../themes/app_theme.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../widgets/common/adaptive_dialog_frame.dart';
import '../../../widgets/common/themed_divider.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_page_layout.dart';

/// 外观设置板块
///
/// 包含主题选择、字体选择、语言选择三个设置项。
class AppearanceSettingsSection extends ConsumerStatefulWidget {
  const AppearanceSettingsSection({super.key});

  @override
  ConsumerState<AppearanceSettingsSection> createState() =>
      _AppearanceSettingsSectionState();
}

class _AppearanceSettingsSectionState
    extends ConsumerState<AppearanceSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeNotifierProvider);
    final currentFont = ref.watch(fontNotifierProvider);
    final currentLocale = ref.watch(localeNotifierProvider);
    final fontScale = ref.watch(fontScaleNotifierProvider);
    final layoutMode = ref.watch(generationLayoutModeNotifierProvider);
    final historyClickBehavior = ref.watch(
      historyClickBehaviorNotifierProvider,
    );

    return SettingsPageLayout(
      title: context.l10n.settings_appearance,
      children: [
        SettingsCard(
          title: context.l10n.settings_appearanceInterfaceSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 主题选择
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(context.l10n.settings_style),
                subtitle: Text(
                  currentTheme == AppStyle.grungeCollage
                      ? context.l10n.settings_defaultPreset
                      : currentTheme.displayName,
                ),
                onTap: () => _showThemeDialog(context, currentTheme),
              ),

              // 字体选择
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: Text(context.l10n.settings_font),
                subtitle: Text(currentFont.displayName),
                onTap: () => _showFontDialog(context, currentFont),
              ),

              // 字体大小选择
              ListTile(
                leading: const Icon(Icons.format_size),
                title: Text(context.l10n.settings_fontScale),
                subtitle: Text(context.l10n.settings_fontScale_description),
                trailing: Text('${(fontScale * 100).round()}%'),
                onTap: () => _showFontScaleDialog(context, fontScale),
              ),

              // 语言选择
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.l10n.settings_language),
                subtitle: Text(_languageLabel(context, currentLocale)),
                onTap: () => _showLanguageDialog(context, currentLocale),
              ),
            ],
          ),
        ),
        SettingsCard(
          title: context.l10n.settings_appearanceWorkflowSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 生成页布局选择
              ListTile(
                leading: const Icon(Icons.view_sidebar_outlined),
                title: Text(context.l10n.settings_generationLayout),
                subtitle: Text(
                  layoutMode == GenerationLayoutMode.webStyle
                      ? context.l10n.settings_generationLayout_webStyle
                      : context.l10n.settings_generationLayout_classic,
                ),
                onTap: () => _showGenerationLayoutDialog(context, layoutMode),
              ),

              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(context.l10n.settings_historyClickBehavior),
                subtitle: Text(
                  historyClickBehavior == HistoryClickBehavior.selectPreview
                      ? context.l10n.settings_historyClickBehavior_linked
                      : context.l10n.settings_historyClickBehavior_classic,
                ),
                onTap: () => _showHistoryClickBehaviorDialog(
                  context,
                  historyClickBehavior,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showThemeDialog(BuildContext context, AppStyle currentTheme) {
    // grungeCollage 已是 enum 第一个，无需手动排序
    const sortedStyles = AppStyle.values;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(context.l10n.settings_selectStyle),
          content: AdaptiveDialogFrame(
            maxWidth: 300,
            maxHeight: 400,
            reservedVerticalSpace: 220,
            scaleReservedVerticalSpace: true,
            child: RadioGroup<AppStyle>(
              groupValue: currentTheme,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeNotifierProvider.notifier).setTheme(value);
                  Navigator.pop(dialogContext);
                }
              },
              child: ListView(
                shrinkWrap: true,
                children: sortedStyles.map((style) {
                  // grungeCollage 使用多语言的"默认"
                  final displayName = style == AppStyle.grungeCollage
                      ? context.l10n.settings_defaultPreset
                      : style.displayName;
                  return RadioListTile<AppStyle>(
                    title: Text(displayName),
                    value: style,
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.common_cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFontDialog(BuildContext context, FontConfig currentFont) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.settings_selectFont,
      sideSheetWidth: 560,
      builder: (panelContext, scrollController) => _FontPickerContent(
        currentFont: currentFont,
        scrollController: scrollController,
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, Locale currentLocale) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(context.l10n.settings_selectLanguage),
          content: RadioGroup<String>(
            groupValue: appLocaleCode(currentLocale),
            onChanged: (value) {
              if (value != null) {
                ref.read(localeNotifierProvider.notifier).setLocale(value);
                Navigator.pop(dialogContext);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text(context.l10n.settings_languageChinese),
                  value: simplifiedChineseLocaleCode,
                ),
                RadioListTile<String>(
                  title: Text(context.l10n.settings_languageTraditionalChinese),
                  value: traditionalChineseLocaleCode,
                ),
                RadioListTile<String>(
                  title: Text(context.l10n.settings_languageEnglish),
                  value: 'en',
                ),
                RadioListTile<String>(
                  title: Text(context.l10n.settings_languageJapanese),
                  value: 'ja',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.common_cancel),
            ),
          ],
        );
      },
    );
  }

  void _showGenerationLayoutDialog(
    BuildContext context,
    GenerationLayoutMode currentMode,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(context.l10n.settings_generationLayout),
          content: AdaptiveDialogFrame(
            maxWidth: 300,
            maxHeight: 420,
            reservedVerticalSpace: 220,
            scaleReservedVerticalSpace: true,
            child: SingleChildScrollView(
              child: RadioGroup<GenerationLayoutMode>(
                groupValue: currentMode,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(generationLayoutModeNotifierProvider.notifier)
                        .setMode(value);
                    Navigator.pop(dialogContext);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<GenerationLayoutMode>(
                      title: Text(
                        context.l10n.settings_generationLayout_classic,
                      ),
                      subtitle: Text(
                        context
                            .l10n
                            .settings_generationLayout_classicDescription,
                      ),
                      value: GenerationLayoutMode.classic,
                    ),
                    RadioListTile<GenerationLayoutMode>(
                      title: Text(
                        context.l10n.settings_generationLayout_webStyle,
                      ),
                      subtitle: Text(
                        context
                            .l10n
                            .settings_generationLayout_webStyleDescription,
                      ),
                      value: GenerationLayoutMode.webStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.common_cancel),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showHistoryClickBehaviorDialog(
    BuildContext context,
    HistoryClickBehavior currentBehavior,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(context.l10n.settings_historyClickBehavior),
          content: AdaptiveDialogFrame(
            maxWidth: 360,
            maxHeight: 420,
            reservedVerticalSpace: 220,
            scaleReservedVerticalSpace: true,
            child: SingleChildScrollView(
              child: RadioGroup<HistoryClickBehavior>(
                groupValue: currentBehavior,
                onChanged: (value) async {
                  if (value == null) return;
                  await ref
                      .read(historyClickBehaviorNotifierProvider.notifier)
                      .setBehavior(value);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<HistoryClickBehavior>(
                      title: Text(
                        context.l10n.settings_historyClickBehavior_classic,
                      ),
                      subtitle: Text(
                        context
                            .l10n
                            .settings_historyClickBehavior_classicDescription,
                      ),
                      value: HistoryClickBehavior.openDetail,
                    ),
                    RadioListTile<HistoryClickBehavior>(
                      title: Text(
                        context.l10n.settings_historyClickBehavior_linked,
                      ),
                      subtitle: Text(
                        context
                            .l10n
                            .settings_historyClickBehavior_linkedDescription,
                      ),
                      value: HistoryClickBehavior.selectPreview,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.common_cancel),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _languageLabel(BuildContext context, Locale locale) {
    switch (appLocaleCode(locale)) {
      case simplifiedChineseLocaleCode:
        return context.l10n.settings_languageChinese;
      case traditionalChineseLocaleCode:
        return context.l10n.settings_languageTraditionalChinese;
      case 'ja':
        return context.l10n.settings_languageJapanese;
      default:
        return context.l10n.settings_languageEnglish;
    }
  }

  Future<void> _showFontScaleDialog(BuildContext context, double currentScale) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      title: context.l10n.settings_fontScale,
      sideSheetWidth: 420,
      builder: (panelContext, scrollController) => _FontScaleEditor(
        initialScale: currentScale,
        scrollController: scrollController,
      ),
    );
  }
}

class _FontPickerContent extends ConsumerWidget {
  const _FontPickerContent({
    required this.currentFont,
    required this.scrollController,
  });

  final FontConfig currentFont;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFontsAsync = ref.watch(allFontsProvider);
    return RadioGroup<FontConfig>(
      groupValue: currentFont,
      onChanged: (font) => _selectFont(context, ref, font),
      child: allFontsAsync.when(
        loading: () => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: const [
            SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (error, stackTrace) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Text(context.l10n.settings_loadFailed(error.toString())),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.common_cancel),
              ),
            ),
          ],
        ),
        data: (fontGroups) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          children: [
            for (final groupEntry in fontGroups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Text(
                  '${groupEntry.key} (${groupEntry.value.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final font in groupEntry.value)
                _FontPickerTile(
                  font: font,
                  selected: font == currentFont,
                  onTap: () => _selectFont(context, ref, font),
                ),
              if (groupEntry.key != fontGroups.keys.last)
                const ThemedDivider(height: 1),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.common_cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectFont(BuildContext context, WidgetRef ref, FontConfig? font) {
    if (font == null) return;
    ref.read(fontNotifierProvider.notifier).setFont(font);
    Navigator.pop(context);
  }
}

class _FontPickerTile extends StatelessWidget {
  const _FontPickerTile({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final FontConfig font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? colors.primaryContainer : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Radio<FontConfig>(value: font),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  font.displayName,
                  style: TextStyle(
                    fontFamily: font.fontFamily.isEmpty
                        ? null
                        : font.fontFamily,
                    fontSize: 16,
                    color: selected ? colors.onPrimaryContainer : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (font.source == FontSource.google)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Google',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
              if (selected)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Icon(
                    Icons.check,
                    color: colors.onPrimaryContainer,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontScaleEditor extends ConsumerStatefulWidget {
  const _FontScaleEditor({
    required this.initialScale,
    required this.scrollController,
  });

  final double initialScale;
  final ScrollController scrollController;

  @override
  ConsumerState<_FontScaleEditor> createState() => _FontScaleEditorState();
}

class _FontScaleEditorState extends ConsumerState<_FontScaleEditor> {
  late double _scale = widget.initialScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scalePercent = (_scale * 100).round();

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.settings_fontScale_previewSmall,
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.settings_fontScale_previewMedium,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.settings_fontScale_previewLarge,
                style: textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: _scale,
            min: FontScaleNotifier.minScale,
            max: FontScaleNotifier.maxScale,
            divisions: 7,
            label: '$scalePercent%',
            onChanged: (value) {
              setState(() => _scale = value);
              ref.read(fontScaleNotifierProvider.notifier).setFontScale(value);
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '80%',
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '150%',
                textAlign: TextAlign.end,
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '$scalePercent%',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() => _scale = FontScaleNotifier.defaultScale);
                ref.read(fontScaleNotifierProvider.notifier).reset();
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.settings_fontScale_reset),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.settings_fontScale_done),
            ),
          ],
        ),
      ],
    );
  }
}
