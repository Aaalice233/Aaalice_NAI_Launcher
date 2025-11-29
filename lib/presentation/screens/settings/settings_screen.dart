import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
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
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 账户信息
          _buildSectionHeader(theme, '账户'),
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
                  ? '加载中...'
                  : (authState.isAuthenticated
                      ? (authState.email ?? '已登录')
                      : '未登录'),
            ),
            subtitle: authState.isLoading
                ? const Text('正在检查登录状态')
                : (authState.isAuthenticated
                    ? Text(authState.email != null ? '已登录' : 'Token 已配置')
                    : const Text('请登录以使用全部功能')),
            trailing: authState.isAuthenticated
                ? TextButton(
                    onPressed: () => _showLogoutDialog(context, ref),
                    child: const Text('退出'),
                  )
                : null,
          ),
          const Divider(),

          // 外观设置
          _buildSectionHeader(theme, '外观'),

          // 主题选择
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('风格'),
            subtitle: Text(currentTheme.displayName),
            onTap: () => _showThemeDialog(context, ref, currentTheme),
          ),

          // 字体选择
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('字体'),
            subtitle: Text(currentFont.displayName),
            onTap: () => _showFontDialog(context, ref, currentFont),
          ),

          // 语言选择
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('语言'),
            subtitle:
                Text(currentLocale.languageCode == 'zh' ? '中文' : 'English'),
            onTap: () => _showLanguageDialog(context, ref, currentLocale),
          ),
          const Divider(),

          // 存储设置
          _buildSectionHeader(theme, '存储'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('图片保存位置'),
            subtitle: const Text('默认'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              AppToast.info(context, '功能开发中...');
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save_outlined),
            title: const Text('自动保存'),
            subtitle: const Text('生成后自动保存图片'),
            value: false,
            onChanged: (value) {
              AppToast.info(context, '功能开发中...');
            },
          ),
          const Divider(),

          // 关于
          _buildSectionHeader(theme, '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('NAI Launcher'),
            subtitle: Text('版本 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('开源项目'),
            subtitle: const Text('查看源代码和文档'),
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
      builder: (context) {
        return AlertDialog(
          title: const Text('退出登录'),
          content: const Text('确定要退出登录吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(authNotifierProvider.notifier).logout();
                Navigator.pop(context);
              },
              child: const Text('退出'),
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
      builder: (context) {
        return AlertDialog(
          title: const Text('选择风格'),
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
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
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
          builder: (context, ref, child) {
            final allFontsAsync = ref.watch(allFontsProvider);

            return AlertDialog(
              title: const Text('选择字体'),
              content: SizedBox(
                width: 500,
                height: 600,
                child: allFontsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('加载失败: $err')),
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
                  child: const Text('取消'),
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
      builder: (context) {
        return AlertDialog(
          title: const Text('选择语言'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('中文'),
                value: 'zh',
                groupValue: currentLocale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(localeNotifierProvider.notifier).setLocale(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('English'),
                value: 'en',
                groupValue: currentLocale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(localeNotifierProvider.notifier).setLocale(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }
}
