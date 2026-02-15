import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/proxy_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/hive_storage_helper.dart';
import '../../../core/utils/vibe_library_path_helper.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../data/models/settings/proxy_settings.dart';
import '../../providers/image_save_settings_provider.dart';
import '../../providers/proxy_settings_provider.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../themes/app_theme.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_divider.dart';
import '../../widgets/settings/account_detail_tile.dart';
import '../../widgets/settings/account_profile_sheet.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'widgets/data_source_cache_settings.dart';
import 'widgets/shortcut_settings_panel.dart';

/// 构建标准输入框装饰
InputDecoration _buildSettingsInputDecoration(ThemeData theme,
    {String? labelText, String? hintText}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
    ),
  );
}

/// 构建标准滑条主题
SliderThemeData _buildSettingsSliderTheme(BuildContext context) {
  return SliderTheme.of(context).copyWith(
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
  );
}

/// 设置页面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 0;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTheme = ref.watch(themeNotifierProvider);
    final currentFont = ref.watch(fontNotifierProvider);
    final currentLocale = ref.watch(localeNotifierProvider);
    final saveSettings = ref.watch(imageSaveSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_title),
        // 滚动后变暗色
        backgroundColor:
            _isScrolled ? theme.colorScheme.surfaceContainerHighest : null,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        controller: _scrollController,
        children: [
          // 账户信息
          _buildSectionHeader(theme, context.l10n.settings_account),
          AccountDetailTile(
            onEdit: () => _showProfileSheet(context),
            onLogin: () => _navigateToLogin(context),
          ),
          const ThemedDivider(),

          // 外观设置
          _buildSectionHeader(theme, context.l10n.settings_appearance),

          // 主题选择
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.l10n.settings_style),
            subtitle: Text(
              currentTheme == AppStyle.retroWave
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

          // 语言选择
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.l10n.settings_language),
            subtitle: Text(
              currentLocale.languageCode == 'zh'
                  ? context.l10n.settings_languageChinese
                  : context.l10n.settings_languageEnglish,
            ),
            onTap: () => _showLanguageDialog(context, currentLocale),
          ),

          // 快捷键设置
          ListTile(
            leading: const Icon(Icons.keyboard_outlined),
            title: const Text('快捷键'),
            subtitle: const Text('自定义键盘快捷键'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ShortcutSettingsPanel.show(context),
          ),
          const ThemedDivider(),

          // 存储设置
          _buildSectionHeader(theme, context.l10n.settings_storage),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(context.l10n.settings_imageSavePath),
            subtitle: Text(
              saveSettings
                  .getDisplayPath('默认 (Documents/NAI_Launcher/images/)'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 20),
                  tooltip: '打开文件夹',
                  onPressed: () async {
                    try {
                      String path;
                      if (saveSettings.hasCustomPath) {
                        path = saveSettings.customPath!;
                      } else {
                        final docDir = await getApplicationDocumentsDirectory();
                        path =
                            '${docDir.path}${Platform.pathSeparator}NAI_Launcher${Platform.pathSeparator}images';
                      }
                      await launchUrl(
                        Uri.directory(path),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      AppLogger.e('打开文件夹失败', e);
                    }
                  },
                ),
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
            onTap: () => _selectSaveDirectory(context),
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
          // Vibe库保存路径设置
          const _VibeLibraryPathTile(),
          // Hive 数据存储路径设置
          const _HiveStoragePathTile(),
          const ThemedDivider(),

          // 网络设置
          _buildSectionHeader(theme, context.l10n.settings_network),
          const _NetworkSettingsSection(),
          const ThemedDivider(),

          // 网络数据缓存
          _buildSectionHeader(theme, '数据源缓存管理'),
          const DataSourceCacheSettings(),
          const ThemedDivider(),

          // 队列设置
          _buildSectionHeader(theme, '队列'),
          const _QueueSettingsSection(),
          const ThemedDivider(),

          // 通知设置
          _buildSectionHeader(theme, context.l10n.settings_notification),
          const _NotificationSettingsSection(),
          const ThemedDivider(),

          // 关于
          _buildSectionHeader(theme, context.l10n.settings_about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.app_title),
            subtitle: Text(context.l10n.settings_version('Beta2.1')),
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
    AppStyle currentTheme,
  ) {
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
                              const ThemedDivider(height: 1),
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

  Future<void> _selectSaveDirectory(BuildContext context) async {
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
  void _showProfileSheet(BuildContext context) {
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
    AppToast.info(context, '请前往登录页面');
  }
}

/// 队列设置分组
class _QueueSettingsSection extends ConsumerStatefulWidget {
  const _QueueSettingsSection();

  @override
  ConsumerState<_QueueSettingsSection> createState() =>
      _QueueSettingsSectionState();
}

class _QueueSettingsSectionState extends ConsumerState<_QueueSettingsSection> {
  late TextEditingController _retryCountController;
  late TextEditingController _retryIntervalController;
  String? _backgroundImagePath;

  @override
  void initState() {
    super.initState();
    _retryCountController = TextEditingController();
    _retryIntervalController = TextEditingController();
    _loadBackgroundImage();
  }

  void _loadBackgroundImage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final storage = ref.read(localStorageServiceProvider);
        setState(() {
          _backgroundImagePath = storage.getFloatingButtonBackgroundImage();
        });
      }
    });
  }

  @override
  void dispose() {
    _retryCountController.dispose();
    _retryIntervalController.dispose();
    super.dispose();
  }

  void _updateRetryCount(int value) async {
    final storage = ref.read(localStorageServiceProvider);
    final clampedValue = value.clamp(1, 30);
    await storage.setSetting(StorageKeys.queueRetryCount, clampedValue);
    ref.invalidate(localStorageServiceProvider);
  }

  void _updateRetryInterval(double value) async {
    final storage = ref.read(localStorageServiceProvider);
    final clampedValue = value.clamp(0.5, 10.0);
    await storage.setSetting(StorageKeys.queueRetryInterval, clampedValue);
    ref.invalidate(localStorageServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    // 同步输入框文本（仅当未聚焦时更新，避免编辑中被覆盖）
    if (_retryCountController.text != '$retryCount') {
      _retryCountController.text = '$retryCount';
    }
    if (_retryIntervalController.text != retryInterval.toStringAsFixed(1)) {
      _retryIntervalController.text = retryInterval.toStringAsFixed(1);
    }

    return Column(
      children: [
        // 重试次数设置 - 单行布局
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 图标
              const Icon(Icons.replay_outlined),
              const SizedBox(width: 16),
              // 标题
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('重试次数'),
                    Text(
                      '最多 $retryCount 次',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 减少按钮
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: retryCount > 1
                    ? () => _updateRetryCount(retryCount - 1)
                    : null,
              ),
              // 滑条
              Expanded(
                child: SliderTheme(
                  data: _buildSettingsSliderTheme(context),
                  child: Slider(
                    value: retryCount.toDouble(),
                    min: 1,
                    max: 30,
                    onChanged: (value) => _updateRetryCount(value.round()),
                  ),
                ),
              ),
              // 增加按钮
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: retryCount < 30
                    ? () => _updateRetryCount(retryCount + 1)
                    : null,
              ),
              const SizedBox(width: 4),
              // 数字输入框
              SizedBox(
                width: 56,
                child: ThemedInput(
                  controller: _retryCountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: _buildSettingsInputDecoration(theme),
                  onSubmitted: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      _updateRetryCount(parsed);
                    } else {
                      _retryCountController.text = '$retryCount';
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              const Text('次'),
            ],
          ),
        ),
        // 重试间隔设置 - 单行布局
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 图标
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 16),
              // 标题
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('重试间隔'),
                    Text(
                      '${retryInterval.toStringAsFixed(1)} 秒',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 减少按钮
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: retryInterval > 0.5
                    ? () => _updateRetryInterval(retryInterval - 0.5)
                    : null,
              ),
              // 滑条
              Expanded(
                child: SliderTheme(
                  data: _buildSettingsSliderTheme(context),
                  child: Slider(
                    value: retryInterval,
                    min: 0.5,
                    max: 10.0,
                    onChanged: (value) =>
                        _updateRetryInterval((value * 2).round() / 2),
                  ),
                ),
              ),
              // 增加按钮
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
                onPressed: retryInterval < 10.0
                    ? () => _updateRetryInterval(retryInterval + 0.5)
                    : null,
              ),
              const SizedBox(width: 4),
              // 数字输入框
              SizedBox(
                width: 56,
                child: ThemedInput(
                  controller: _retryIntervalController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: _buildSettingsInputDecoration(theme),
                  onSubmitted: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      _updateRetryInterval(parsed);
                    } else {
                      _retryIntervalController.text =
                          retryInterval.toStringAsFixed(1);
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              const Text('秒'),
            ],
          ),
        ),

        // 悬浮球背景图片设置
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: const Text('悬浮球背景'),
          subtitle: Text(
            _backgroundImagePath != null ? '已设置自定义背景' : '默认样式',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 预览图
              if (_backgroundImagePath != null)
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
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
              // 清除按钮
              if (_backgroundImagePath != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: '清除背景',
                  onPressed: _clearBackgroundImage,
                ),
              // 选择按钮
              FilledButton.tonalIcon(
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('选择图片'),
                onPressed: _selectBackgroundImage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 选择背景图片
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

  /// 清除背景图片
  Future<void> _clearBackgroundImage() async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.setFloatingButtonBackgroundImage(null);
    setState(() {
      _backgroundImagePath = null;
    });
    ref.invalidate(localStorageServiceProvider);
  }
}

/// 网络设置分组
class _NetworkSettingsSection extends ConsumerStatefulWidget {
  const _NetworkSettingsSection();

  @override
  ConsumerState<_NetworkSettingsSection> createState() =>
      _NetworkSettingsSectionState();
}

class _NetworkSettingsSectionState
    extends ConsumerState<_NetworkSettingsSection> {
  bool _isTesting = false;
  String? _testResult;

  // 手动代理输入控制器
  final _hostController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proxySettings = ref.watch(proxySettingsNotifierProvider);
    final detectedProxy = ref.watch(detectedSystemProxyProvider);
    final l10n = context.l10n;

    // 初始化手动代理输入框
    if (_hostController.text.isEmpty && proxySettings.manualHost != null) {
      _hostController.text = proxySettings.manualHost!;
    }
    if (_portController.text.isEmpty && proxySettings.manualPort != null) {
      _portController.text = proxySettings.manualPort.toString();
    }

    return Column(
      children: [
        // 启用代理开关
        SwitchListTile(
          secondary: const Icon(Icons.wifi_tethering),
          title: Text(l10n.settings_enableProxy),
          subtitle: Text(
            proxySettings.enabled
                ? '${l10n.settings_proxyEnabled}: ${proxySettings.effectiveProxyAddress ?? l10n.settings_proxyNotDetected}'
                : l10n.settings_proxyDisabled,
          ),
          value: proxySettings.enabled,
          onChanged: (value) async {
            await ref
                .read(proxySettingsNotifierProvider.notifier)
                .setEnabled(value);
            if (mounted) {
              AppToast.info(
                // ignore: use_build_context_synchronously
                context,
                l10n.settings_proxyRestartHint,
              );
            }
          },
        ),

        // 代理模式选择（仅在启用时显示）
        if (proxySettings.enabled) ...[
          ListTile(
            leading: const Icon(Icons.settings_ethernet),
            title: Text(l10n.settings_proxyMode),
            subtitle: Text(
              proxySettings.mode == ProxyMode.auto
                  ? '${l10n.settings_proxyModeAuto} (${detectedProxy ?? l10n.settings_proxyNotDetected})'
                  : l10n.settings_proxyModeManual,
            ),
            trailing: SegmentedButton<ProxyMode>(
              segments: [
                ButtonSegment(
                  value: ProxyMode.auto,
                  label: Text(l10n.settings_auto),
                ),
                ButtonSegment(
                  value: ProxyMode.manual,
                  label: Text(l10n.settings_manual),
                ),
              ],
              selected: {proxySettings.mode},
              onSelectionChanged: (set) async {
                await ref
                    .read(proxySettingsNotifierProvider.notifier)
                    .setMode(set.first);
              },
            ),
          ),

          // 手动模式输入框
          if (proxySettings.mode == ProxyMode.manual)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ThemedInput(
                      controller: _hostController,
                      decoration: InputDecoration(
                        labelText: l10n.settings_proxyHost,
                        hintText: '127.0.0.1',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _saveManualProxy(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: ThemedInput(
                      controller: _portController,
                      decoration: InputDecoration(
                        labelText: l10n.settings_proxyPort,
                        hintText: '7890',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _saveManualProxy(),
                    ),
                  ),
                ],
              ),
            ),

          // 测试连接按钮
          ListTile(
            leading: const Icon(Icons.network_check),
            title: Text(l10n.settings_testConnection),
            subtitle: Text(_testResult ?? l10n.settings_testConnectionHint),
            trailing: _isTesting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: _testProxyConnection,
                  ),
          ),
        ],
      ],
    );
  }

  /// 保存手动代理设置
  void _saveManualProxy() {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();

    if (host.isNotEmpty && portText.isNotEmpty) {
      final port = int.tryParse(portText);
      if (port != null && port > 0 && port <= 65535) {
        ref.read(proxySettingsNotifierProvider.notifier).setManualProxy(
              host,
              port,
            );
      }
    }
  }

  /// 测试代理连接
  Future<void> _testProxyConnection() async {
    final proxySettings = ref.read(proxySettingsNotifierProvider);
    final proxyAddress = proxySettings.effectiveProxyAddress;
    final l10n = context.l10n;

    if (proxyAddress == null || proxyAddress.isEmpty) {
      setState(() {
        _testResult = l10n.settings_proxyNotDetected;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final result = await ProxyService.testProxyConnection(proxyAddress);

      if (mounted) {
        setState(() {
          _isTesting = false;
          if (result.success) {
            _testResult = l10n.settings_testSuccess(result.latencyMs ?? 0);
          } else {
            _testResult =
                l10n.settings_testFailed(result.errorMessage ?? 'Unknown');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testResult = l10n.settings_testFailed(e.toString());
        });
      }
    }
  }
}

/// 音效设置部分
class _NotificationSettingsSection extends ConsumerWidget {
  const _NotificationSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsNotifierProvider);
    final notifier = ref.read(notificationSettingsNotifierProvider.notifier);
    final l10n = context.l10n;

    return Column(
      children: [
        // 音效开关
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_outlined),
          title: Text(l10n.settings_notificationSound),
          subtitle: Text(l10n.settings_notificationSoundSubtitle),
          value: settings.soundEnabled,
          onChanged: (value) => notifier.setSoundEnabled(value),
        ),

        // 自定义音效（仅在音效开启时显示）
        if (settings.soundEnabled)
          ListTile(
            leading: const Icon(Icons.audiotrack_outlined),
            title: Text(l10n.settings_notificationCustomSound),
            subtitle: Text(
              settings.customSoundPath != null
                  ? settings.customSoundPath!.split(Platform.pathSeparator).last
                  : l10n.settings_notificationSelectSound,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (settings.customSoundPath != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: l10n.settings_notificationResetSound,
                    onPressed: () => notifier.setCustomSoundPath(null),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _selectCustomSound(context, notifier),
          ),
      ],
    );
  }

  Future<void> _selectCustomSound(
    BuildContext context,
    NotificationSettingsNotifier notifier,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
    );
    if (result != null && result.files.single.path != null) {
      await notifier.setCustomSoundPath(result.files.single.path);
    }
  }
}

/// Vibe库保存路径设置项
class _VibeLibraryPathTile extends StatefulWidget {
  const _VibeLibraryPathTile();

  @override
  State<_VibeLibraryPathTile> createState() => _VibeLibraryPathTileState();
}

class _VibeLibraryPathTileState extends State<_VibeLibraryPathTile> {
  final _pathHelper = VibeLibraryPathHelper.instance;

  Future<void> _selectVibeLibraryDirectory(BuildContext context) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择Vibe库保存文件夹',
      );

      if (result != null && context.mounted) {
        await _pathHelper.setPath(result);
        await _pathHelper.ensurePathExists(result);
        setState(() {});

        if (context.mounted) {
          AppToast.success(context, 'Vibe库路径已保存');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '选择文件夹失败: ${e.toString()}');
      }
    }
  }

  Future<void> _resetToDefault(BuildContext context) async {
    await _pathHelper.resetToDefault();
    setState(() {});

    if (context.mounted) {
      AppToast.success(context, '已重置为默认路径');
    }
  }

  @override
  Widget build(BuildContext context) {
    final customPath = _pathHelper.getCustomPath();
    final hasCustomPath = _pathHelper.hasCustomPath;

    return ListTile(
      leading: const Icon(Icons.style_outlined),
      title: const Text('Vibe 库保存路径'),
      subtitle: FutureBuilder<String>(
        future: _pathHelper.getPath(),
        builder: (context, snapshot) {
          final displayPath = hasCustomPath
              ? (customPath ?? '')
              : (snapshot.data != null
                  ? '${snapshot.data!} (默认)'
                  : '默认 (Documents/NAI_Launcher/vibes/)');
          return Text(
            displayPath,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.folder_open, size: 20),
            tooltip: '打开文件夹',
            onPressed: () async {
              try {
                final path = await _pathHelper.getPath();
                await launchUrl(
                  Uri.directory(path),
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                AppLogger.e('打开文件夹失败', e);
              }
            },
          ),
          if (hasCustomPath)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '重置为默认',
              onPressed: () => _resetToDefault(context),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _selectVibeLibraryDirectory(context),
    );
  }
}

/// Hive 数据存储路径设置 Tile
class _HiveStoragePathTile extends StatefulWidget {
  const _HiveStoragePathTile();

  @override
  State<_HiveStoragePathTile> createState() => _HiveStoragePathTileState();
}

class _HiveStoragePathTileState extends State<_HiveStoragePathTile> {
  final _hiveHelper = HiveStorageHelper.instance;

  Future<void> _selectHiveStorageDirectory(BuildContext context) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择 Hive 数据存储文件夹',
      );

      if (result != null && context.mounted) {
        // 显示警告：更改存储路径需要重启应用
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: const Text('需要重启应用'),
            content: const Text(
              '更改 Hive 数据存储路径后，需要重启应用才能生效。\n\n'
              '新路径将在下次启动时生效。是否继续？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('确认'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await _hiveHelper.setCustomPath(result);
          setState(() {});

          if (context.mounted) {
            AppToast.success(context, 'Hive 存储路径已保存，重启后生效');
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '选择文件夹失败: ${e.toString()}');
      }
    }
  }

  Future<void> _resetToDefault(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: const Text('需要重启应用'),
        content: const Text(
          '重置 Hive 数据存储路径后，需要重启应用才能生效。\n\n'
          '默认路径将在下次启动时生效。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _hiveHelper.resetToDefault();
      setState(() {});

      if (context.mounted) {
        AppToast.success(context, '已重置为默认路径，重启后生效');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomPath = _hiveHelper.hasCustomPath;

    return ListTile(
      leading: const Icon(Icons.storage_outlined),
      title: const Text('数据存储路径'),
      subtitle: Text(
        _hiveHelper.getDisplayPath(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.folder_open, size: 20),
            tooltip: '打开文件夹',
            onPressed: () async {
              try {
                final path = await _hiveHelper.getPath();
                await launchUrl(
                  Uri.directory(path),
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                AppLogger.e('打开文件夹失败', e);
              }
            },
          ),
          if (hasCustomPath)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '重置为默认',
              onPressed: () => _resetToDefault(context),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _selectHiveStorageDirectory(context),
    );
  }
}
