import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/hive_storage_helper.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_library_path_helper.dart';
import '../../../providers/image_save_settings_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../widgets/settings_card.dart';

/// 存储设置板块
class StorageSettingsSection extends ConsumerStatefulWidget {
  const StorageSettingsSection({super.key});

  @override
  ConsumerState<StorageSettingsSection> createState() =>
      _StorageSettingsSectionState();
}

class _StorageSettingsSectionState
    extends ConsumerState<StorageSettingsSection> {
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

  @override
  Widget build(BuildContext context) {
    final saveSettings = ref.watch(imageSaveSettingsNotifierProvider);

    return SettingsCard(
      title: context.l10n.settings_storage,
      icon: Icons.storage,
      child: Column(
        children: [
          // 图片保存路径设置
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
          // 自动保存开关
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
          const VibeLibraryPathTile(),
          // Hive 数据存储路径设置
          const HiveStoragePathTile(),
        ],
      ),
    );
  }
}

/// Vibe库保存路径设置项
class VibeLibraryPathTile extends StatefulWidget {
  const VibeLibraryPathTile({super.key});

  @override
  State<VibeLibraryPathTile> createState() => _VibeLibraryPathTileState();
}

class _VibeLibraryPathTileState extends State<VibeLibraryPathTile> {
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
class HiveStoragePathTile extends StatefulWidget {
  const HiveStoragePathTile({super.key});

  @override
  State<HiveStoragePathTile> createState() => _HiveStoragePathTileState();
}

class _HiveStoragePathTileState extends State<HiveStoragePathTile> {
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
