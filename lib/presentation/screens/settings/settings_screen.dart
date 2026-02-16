import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/constants/storage_keys.dart';
import '../../providers/image_save_settings_provider.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/backup_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_manager_provider.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_divider.dart';
import '../../widgets/settings/account_detail_tile.dart';
import '../../widgets/settings/account_profile_sheet.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentTheme = ref.watch(themeNotifierProvider);
    final currentFont = ref.watch(fontNotifierProvider);
    final currentLocale = ref.watch(localeNotifierProvider);
    final saveSettings = ref.watch(imageSaveSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_title),
      ),
      body: ListView(
        children: [
          // 账户信息
          _buildSectionHeader(theme, context.l10n.settings_account),
          AccountDetailTile(
            onEdit: () => _showProfileSheet(context, ref),
            onLogin: () => _navigateToLogin(context),
          ),
          const ThemedDivider(),

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
            subtitle: Text(
              currentLocale.languageCode == 'zh'
                  ? context.l10n.settings_languageChinese
                  : context.l10n.settings_languageEnglish,
            ),
            onTap: () => _showLanguageDialog(context, ref, currentLocale),
          ),
          const ThemedDivider(),

          // 存储设置
          _buildSectionHeader(theme, context.l10n.settings_storage),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(context.l10n.settings_imageSavePath),
            subtitle: Text(
              saveSettings.getDisplayPath(context.l10n.settings_default),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (saveSettings.hasCustomPath)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: context.l10n.common_reset,
                    onPressed: () async {
                      await ref
                          .read(imageSaveSettingsNotifierProvider.notifier)
                          .resetToDefault();
                      if (context.mounted) {
                        AppToast.success(
                          context,
                          context.l10n.settings_pathReset,
                        );
                      }
                    },
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _selectSaveDirectory(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save_outlined),
            title: Text(context.l10n.settings_autoSave),
            subtitle: Text(context.l10n.settings_autoSaveSubtitle),
            value: saveSettings.autoSave,
            onChanged: (value) async {
              await ref
                  .read(imageSaveSettingsNotifierProvider.notifier)
                  .setAutoSave(value);
            },
          ),
          const ThemedDivider(),

          // 队列设置
          _buildSectionHeader(theme, '队列'),
          _buildQueueSettings(context, ref),
          const ThemedDivider(),

          // 数据备份
          _buildSectionHeader(theme, '数据备份'),
          _buildBackupSettings(context, ref),
          const ThemedDivider(),

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
              final uri = Uri.parse(
                'https://github.com/Aaalice233/Aaalice_NAI_Launcher',
              );
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
            height: 400,
            child: ListView(
              shrinkWrap: true,
              children: AppStyle.values.map((style) {
                return RadioListTile<AppStyle>(
                  title: Text(style.displayName),
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
                  error: (err, stack) => Center(
                    child: Text(
                      context.l10n.settings_loadFailed(err.toString()),
                    ),
                  ),
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
                                                .onPrimaryContainer,
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

  Future<void> _selectSaveDirectory(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: context.l10n.settings_selectFolder,
      );

      if (result != null && context.mounted) {
        await ref
            .read(imageSaveSettingsNotifierProvider.notifier)
            .setCustomPath(result);

        if (context.mounted) {
          AppToast.success(context, context.l10n.settings_pathSaved);
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  /// 显示账号资料编辑底部面板
  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authNotifierProvider);
    final accountId = authState.accountId;

    if (accountId == null) {
      AppToast.info(context, '请先登录');
      return;
    }

    final accounts = ref.read(accountManagerNotifierProvider).accounts;
    final account = accounts.where((a) => a.id == accountId).firstOrNull;

    if (account == null) {
      AppToast.info(context, '未找到账号信息');
      return;
    }

    AccountProfileBottomSheet.show(
      context: context,
      account: account,
    );
  }

  /// 导航到登录页面
  void _navigateToLogin(BuildContext context) {
    // TODO: 实现登录导航
    AppToast.info(context, '请前往登录页面');
  }

  /// 构建队列设置
  Widget _buildQueueSettings(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(localStorageServiceProvider);
    final retryCount = storage.getSetting<int>(
          StorageKeys.queueRetryCount,
          defaultValue: 10,
        ) ??
        10;
    final retryInterval = storage.getSetting<double>(
          StorageKeys.queueRetryInterval,
          defaultValue: 1.0,
        ) ??
        1.0;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.replay_outlined),
          title: const Text('重试次数'),
          subtitle: Text('生成失败时最多重试 $retryCount 次'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: retryCount > 1
                    ? () async {
                        await storage.setSetting(
                          StorageKeys.queueRetryCount,
                          retryCount - 1,
                        );
                        ref.invalidate(localStorageServiceProvider);
                      }
                    : null,
              ),
              Text('$retryCount'),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: retryCount < 30
                    ? () async {
                        await storage.setSetting(
                          StorageKeys.queueRetryCount,
                          retryCount + 1,
                        );
                        ref.invalidate(localStorageServiceProvider);
                      }
                    : null,
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('重试间隔'),
          subtitle: Text('每次重试间隔 ${retryInterval.toStringAsFixed(1)} 秒'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: retryInterval > 0.5
                    ? () async {
                        await storage.setSetting(
                          StorageKeys.queueRetryInterval,
                          retryInterval - 0.5,
                        );
                        ref.invalidate(localStorageServiceProvider);
                      }
                    : null,
              ),
              Text('${retryInterval.toStringAsFixed(1)}s'),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: retryInterval < 10.0
                    ? () async {
                        await storage.setSetting(
                          StorageKeys.queueRetryInterval,
                          retryInterval + 0.5,
                        );
                        ref.invalidate(localStorageServiceProvider);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建备份设置
  Widget _buildBackupSettings(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(localStorageServiceProvider);
    final autoBackupEnabled = storage.getSetting<bool>(
          StorageKeys.autoBackupEnabled,
          defaultValue: false,
        ) ??
        false;
    final autoBackupInterval = storage.getSetting<int>(
          StorageKeys.autoBackupInterval,
          defaultValue: 7,
        ) ??
        7;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('备份数据'),
          subtitle: const Text('导出所有数据到备份文件'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleBackup(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.restore_outlined),
          title: const Text('恢复数据'),
          subtitle: const Text('从备份文件恢复数据'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleRestore(context, ref),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.schedule_outlined),
          title: const Text('自动备份'),
          subtitle: const Text('定期自动备份数据'),
          value: autoBackupEnabled,
          onChanged: (value) async {
            await storage.setSetting(
              StorageKeys.autoBackupEnabled,
              value,
            );
            ref.invalidate(localStorageServiceProvider);
          },
        ),
        if (autoBackupEnabled)
          ListTile(
            leading: const Icon(Icons.timelapse_outlined),
            title: const Text('备份间隔'),
            subtitle: Text('每 $autoBackupInterval 天自动备份'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: autoBackupInterval > 1
                      ? () async {
                          await storage.setSetting(
                            StorageKeys.autoBackupInterval,
                            autoBackupInterval - 1,
                          );
                          ref.invalidate(localStorageServiceProvider);
                        }
                      : null,
                ),
                Text('$autoBackupInterval'),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: autoBackupInterval < 30
                      ? () async {
                          await storage.setSetting(
                            StorageKeys.autoBackupInterval,
                            autoBackupInterval + 1,
                          );
                          ref.invalidate(localStorageServiceProvider);
                        }
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 处理备份操作
  Future<void> _handleBackup(BuildContext context, WidgetRef ref) async {
    try {
      final backupService = ref.read(backupServiceProvider);
      final result = await backupService.exportBackup();

      if (!context.mounted) return;

      if (result.success) {
        AppToast.success(
          context,
          '备份成功：${result.metadata?.itemCount ?? 0} 项数据已导出',
        );
      } else {
        AppToast.error(
          context,
          '备份失败：${result.error ?? '未知错误'}',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, '备份失败：$e');
    }
  }

  /// 处理恢复操作
  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: '选择备份文件',
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (!context.mounted) return;
        AppToast.error(context, '无法访问所选文件');
        return;
      }

      if (!context.mounted) return;

      // 显示确认对话框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('确认恢复'),
            content: const Text(
              '恢复数据将覆盖当前的所有设置和数据。\n\n建议在恢复前先备份当前数据。\n\n是否继续？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.common_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('恢复'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !context.mounted) return;

      final backupService = ref.read(backupServiceProvider);
      final restoreResult = await backupService.importBackup(filePath);

      if (!context.mounted) return;

      if (restoreResult.success) {
        AppToast.success(
          context,
          '恢复成功：${restoreResult.restoredItems} 项数据已恢复',
        );
      } else {
        AppToast.error(
          context,
          '恢复失败：${restoreResult.error ?? '未知错误'}',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, '恢复失败：$e');
    }
  }
}
