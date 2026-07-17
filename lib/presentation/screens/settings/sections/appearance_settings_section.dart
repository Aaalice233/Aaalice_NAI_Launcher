import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/font_provider.dart';
import '../../../providers/font_scale_provider.dart';
import '../../../providers/generation_layout_mode_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../themes/app_theme.dart';
import '../../../widgets/common/themed_divider.dart';
import '../widgets/settings_card.dart';

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

    return SettingsCard(
      title: context.l10n.settings_appearance,
      icon: Icons.palette_outlined,
      child: Column(
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
            subtitle: Text(_languageLabel(context, currentLocale.languageCode)),
            onTap: () => _showLanguageDialog(context, currentLocale),
          ),

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

          // 悬浮球背景图片（自原队列设置迁入）
          const _FloatingButtonBackgroundTile(),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, AppStyle currentTheme) {
    // grungeCollage 已是 enum 第一个，无需手动排序
    const sortedStyles = AppStyle.values;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.settings_selectStyle),
          content: SizedBox(
            width: 300,
            height: 400,
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

  void _showFontDialog(BuildContext context, FontConfig currentFont) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (consumerContext, ref, child) {
            final allFontsAsync = ref.watch(allFontsProvider);

            return AlertDialog(
              title: Text(context.l10n.settings_selectFont),
              content: SizedBox(
                width: 500,
                height: 600,
                child: allFontsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text(
                      context.l10n.settings_loadFailed(err.toString()),
                    ),
                  ),
                  data: (fontGroups) {
                    return RadioGroup<FontConfig>(
                      groupValue: currentFont,
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(fontNotifierProvider.notifier)
                              .setFont(value);
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: ListView.builder(
                        itemCount: fontGroups.length,
                        itemBuilder: (context, groupIndex) {
                          final groupName = fontGroups.keys.elementAt(
                            groupIndex,
                          );
                          final fonts = fontGroups[groupName]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 分组标题
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                                child: Text(
                                  '$groupName (${fonts.length})',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              // 字体列表
                              ...fonts.map((font) {
                                final isSelected = font == currentFont;
                                return InkWell(
                                  onTap: () {
                                    ref
                                        .read(fontNotifierProvider.notifier)
                                        .setFont(font);
                                    Navigator.pop(dialogContext);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Radio<FontConfig>(value: font),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            font.displayName,
                                            style: TextStyle(
                                              fontFamily:
                                                  font.fontFamily.isEmpty
                                                  ? null
                                                  : font.fontFamily,
                                              fontSize: 16,
                                              color: isSelected
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer
                                                  : null,
                                            ),
                                            maxLines: 1,
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
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Google',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                              ),
                                            ),
                                          ),
                                        if (isSelected)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            child: Icon(
                                              Icons.check,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                              size: 20,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              if (groupIndex < fontGroups.length - 1)
                                const ThemedDivider(height: 1),
                            ],
                          );
                        },
                      ),
                    );
                  },
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
      },
    );
  }

  void _showLanguageDialog(BuildContext context, Locale currentLocale) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.settings_selectLanguage),
          content: RadioGroup<String>(
            groupValue: currentLocale.languageCode,
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
                  value: 'zh',
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
          title: Text(context.l10n.settings_generationLayout),
          content: SizedBox(
            width: 300,
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
                      context.l10n.settings_generationLayout_classicDescription,
                    ),
                    value: GenerationLayoutMode.classic,
                  ),
                  RadioListTile<GenerationLayoutMode>(
                    title: Text(
                      context.l10n.settings_generationLayout_webStyle,
                    ),
                    subtitle: Text(
                      context
                          .l10n.settings_generationLayout_webStyleDescription,
                    ),
                    value: GenerationLayoutMode.webStyle,
                  ),
                ],
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

  String _languageLabel(BuildContext context, String languageCode) {
    switch (languageCode) {
      case 'zh':
        return context.l10n.settings_languageChinese;
      case 'ja':
        return context.l10n.settings_languageJapanese;
      default:
        return context.l10n.settings_languageEnglish;
    }
  }

  void _showFontScaleDialog(BuildContext context, double currentScale) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final textTheme = theme.textTheme;
            final scalePercent = (currentScale * 100).round();

            return AlertDialog(
              title: Text(context.l10n.settings_fontScale),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 预览区域
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

                    // 滑块区域
                    Row(
                      children: [
                        Text(
                          '80%',
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: theme.colorScheme.primary,
                              inactiveTrackColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              thumbColor: theme.colorScheme.primary,
                              overlayColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                            ),
                            child: Slider(
                              value: currentScale,
                              min: 0.8,
                              max: 1.5,
                              divisions: 7,
                              label: '$scalePercent%',
                              onChanged: (value) {
                                setState(() {
                                  currentScale = value;
                                });
                                ref
                                    .read(fontScaleNotifierProvider.notifier)
                                    .setFontScale(value);
                              },
                            ),
                          ),
                        ),
                        Text(
                          '150%',
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 当前值显示
                    Center(
                      child: Text(
                        '$scalePercent%',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // 重置按钮
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      currentScale = 1.0;
                    });
                    ref.read(fontScaleNotifierProvider.notifier).reset();
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.settings_fontScale_reset),
                ),
                // 完成按钮
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.settings_fontScale_done),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 悬浮球背景图片设置行
class _FloatingButtonBackgroundTile extends ConsumerStatefulWidget {
  const _FloatingButtonBackgroundTile();

  @override
  ConsumerState<_FloatingButtonBackgroundTile> createState() =>
      _FloatingButtonBackgroundTileState();
}

class _FloatingButtonBackgroundTileState
    extends ConsumerState<_FloatingButtonBackgroundTile> {
  String? _backgroundImagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final storage = ref.read(localStorageServiceProvider);
        setState(() {
          _backgroundImagePath = storage.getFloatingButtonBackgroundImage();
        });
      }
    });
  }

  Future<void> _selectBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final storage = ref.read(localStorageServiceProvider);
        await storage.setFloatingButtonBackgroundImage(path);
        setState(() {
          _backgroundImagePath = path;
        });
        ref.invalidate(localStorageServiceProvider);
      }
    }
  }

  Future<void> _clearBackgroundImage() async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.setFloatingButtonBackgroundImage(null);
    setState(() {
      _backgroundImagePath = null;
    });
    ref.invalidate(localStorageServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.settings_floatingButtonBackground),
                Text(
                  _backgroundImagePath != null
                      ? l10n.settings_floatingButtonBackgroundCustom
                      : l10n.settings_floatingButtonBackgroundDefault,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (_backgroundImagePath != null)
                  Text(
                    _backgroundImagePath!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_backgroundImagePath != null)
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: ClipOval(
                child: Image.file(
                  File(_backgroundImagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          if (_backgroundImagePath != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: l10n.settings_clearBackground,
              onPressed: _clearBackgroundImage,
            ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.folder_open, size: 18),
            label: Text(l10n.settings_selectImage),
            onPressed: _selectBackgroundImage,
          ),
        ],
      ),
    );
  }
}
