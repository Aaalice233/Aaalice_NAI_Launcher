import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/default_presets.dart';
import '../../providers/auth_provider.dart';
import '../../providers/prompt_config_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/app_toast.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final currentTheme = ref.watch(themeNotifierProvider);
    final currentFont = ref.watch(fontNotifierProvider);
    final currentLocale = ref.watch(localeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_title),
      ),
      body: ListView(
        children: [
          // 账户信息
          _buildSectionHeader(theme, context.l10n.settings_account),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: authState.isAuthenticated
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                authState.isAuthenticated ? Icons.check : Icons.person,
                color: authState.isAuthenticated
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              authState.isLoading
                  ? context.l10n.common_loading
                  : (authState.isAuthenticated
                      ? (authState.email ?? context.l10n.auth_loggedIn)
                      : context.l10n.auth_notLoggedIn),
            ),
            subtitle: authState.isLoading
                ? Text(context.l10n.auth_checkingStatus)
                : (authState.isAuthenticated
                    ? Text(authState.email != null ? context.l10n.auth_loggedIn : context.l10n.auth_tokenConfigured)
                    : Text(context.l10n.auth_pleaseLogin)),
            trailing: authState.isAuthenticated
                ? TextButton(
                    onPressed: () => _showLogoutDialog(context, ref),
                    child: Text(context.l10n.auth_logout),
                  )
                : null,
          ),
          const Divider(),

          // 外观设置
          _buildSectionHeader(theme, context.l10n.settings_appearance),

          // 主题选择
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.settings_style),
            subtitle: Text(currentTheme.displayName),
            onTap: () => _showThemeDialog(context, ref, currentTheme),
          ),

          // 字体选择
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text(context.l10n.settings_font),
            subtitle: Text(currentFont.displayName),
            onTap: () => _showFontDialog(context, ref, currentFont),
          ),

          // 语言选择
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.l10n.settings_language),
            subtitle:
                Text(currentLocale.languageCode == 'zh' ? context.l10n.settings_languageChinese : context.l10n.settings_languageEnglish),
            onTap: () => _showLanguageDialog(context, ref, currentLocale),
          ),
          const Divider(),

          // 存储设置
          _buildSectionHeader(theme, context.l10n.settings_storage),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(context.l10n.settings_imageSavePath),
            subtitle: Text(context.l10n.settings_default),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              AppToast.info(context, context.l10n.common_featureInDev);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save_outlined),
            title: Text(context.l10n.settings_autoSave),
            subtitle: Text(context.l10n.settings_autoSaveSubtitle),
            value: false,
            onChanged: (value) {
              AppToast.info(context, context.l10n.common_featureInDev);
            },
          ),
          const Divider(),

          // 关于
          _buildSectionHeader(theme, context.l10n.settings_about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.appTitle),
            subtitle: Text(context.l10n.settings_version('1.0.0')),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(context.l10n.settings_openSource),
            subtitle: Text(context.l10n.settings_openSourceSubtitle),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse('https://github.com/Aaalice233/Aaalice_NAI_Launcher');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.auth_logoutConfirmTitle),
          content: Text(context.l10n.auth_logoutConfirmContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                ref.read(authNotifierProvider.notifier).logout();
                Navigator.pop(dialogContext);
              },
              child: Text(context.l10n.auth_logout),
            ),
          ],
        );
      },
    );
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    AppStyle currentTheme,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.settings_selectStyle),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AppStyle.values.map((style) {
                return RadioListTile<AppStyle>(
                  title: Text(style.displayName),
                  subtitle: Text(style.description),
                  value: style,
                  groupValue: currentTheme,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeNotifierProvider.notifier).setTheme(value);
                      Navigator.pop(dialogContext);
                    }
                  },
                );
              }).toList(),
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

  void _showFontDialog(
    BuildContext context,
    WidgetRef ref,
    FontConfig currentFont,
  ) {
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
                  error: (err, stack) => Center(child: Text(context.l10n.settings_loadFailed(err.toString()))),
                  data: (fontGroups) {
                    return ListView.builder(
                      itemCount: fontGroups.length,
                      itemBuilder: (context, groupIndex) {
                        final groupName = fontGroups.keys.elementAt(groupIndex);
                        final fonts = fontGroups[groupName]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 分组标题
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                              child: Text(
                                '$groupName (${fonts.length})',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Radio<FontConfig>(
                                        value: font,
                                        groupValue: currentFont,
                                        onChanged: (value) {
                                          if (value != null) {
                                            ref
                                                .read(
                                                  fontNotifierProvider.notifier,
                                                )
                                                .setFont(value);
                                            Navigator.pop(dialogContext);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          font.displayName,
                                          style: TextStyle(
                                            fontFamily: font.fontFamily.isEmpty
                                                ? null
                                                : font.fontFamily,
                                            fontSize: 16,
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondaryContainer,
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
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: Icon(
                                            Icons.check,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            size: 20,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            if (groupIndex < fontGroups.length - 1)
                              const Divider(height: 1),
                          ],
                        );
                      },
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

  void _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    Locale currentLocale,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.settings_selectLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(context.l10n.settings_languageChinese),
                value: 'zh',
                groupValue: currentLocale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(localeNotifierProvider.notifier).setLocale(value);
                    _updateDefaultPresetLocalization(ref, value);
                    Navigator.pop(dialogContext);
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(context.l10n.settings_languageEnglish),
                value: 'en',
                groupValue: currentLocale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(localeNotifierProvider.notifier).setLocale(value);
                    _updateDefaultPresetLocalization(ref, value);
                    Navigator.pop(dialogContext);
                  }
                },
              ),
            ],
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

  /// 更新默认预设的本地化名称
  void _updateDefaultPresetLocalization(WidgetRef ref, String languageCode) {
    final names = languageCode == 'zh'
        ? const DefaultPresetNames(
            presetName: '默认预设',
            character: '角色',
            artist: '画师',
            expression: '表情',
            clothing: '服装',
            action: '动作',
            background: '背景',
            shot: '镜头',
            composition: '构图',
            specialStyle: '特殊风格',
          )
        : const DefaultPresetNames(
            presetName: 'Default Preset',
            character: 'Character',
            artist: 'Artist',
            expression: 'Expression',
            clothing: 'Clothing',
            action: 'Action',
            background: 'Background',
            shot: 'Shot',
            composition: 'Composition',
            specialStyle: 'Special Style',
          );

    ref.read(promptConfigNotifierProvider.notifier).updateDefaultPresetLocalization(names);
  }
}
