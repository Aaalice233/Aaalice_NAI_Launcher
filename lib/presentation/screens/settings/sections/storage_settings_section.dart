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
import '../../../../data/services/local_onnx_model_service.dart';
import '../../../providers/image_save_settings_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../widgets/cache_statistics_tile.dart';
import '../widgets/data_source_cache_settings.dart';
import '../widgets/gallery_cache_actions.dart';
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

  Future<void> _selectLocalOnnxTaggerDirectory() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: context.l10n.settings_selectLocalOnnxTaggerFolder,
      );
      if (result == null) {
        return;
      }
      final service = ref.read(localOnnxModelServiceProvider);
      await service.setTaggerDirectory(result);
      if (mounted) {
        setState(() {});
        AppToast.success(
          context,
          context.l10n.settings_localOnnxTaggerFolderSaved,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          '${context.l10n.settings_selectFolderFailed}: $e',
        );
      }
    }
  }

  Future<void> _openLocalOnnxTaggerDirectory(String path) async {
    if (path.isEmpty) {
      return;
    }

    final openFolderFailed = context.l10n.settings_openFolderFailed;
    try {
      await launchUrl(
        Uri.directory(path),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      AppLogger.e(openFolderFailed, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveSettings = ref.watch(imageSaveSettingsNotifierProvider);
    final localOnnxService = ref.watch(localOnnxModelServiceProvider);
    final localOnnxDirectory = localOnnxService.taggerDirectory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: context.l10n.settings_dataStorage,
          icon: Icons.storage,
          child: Column(
            children: [
              // 图片保存路径设置
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(context.l10n.settings_imageSavePath),
                subtitle: Text(
                  saveSettings.getDisplayPath(
                    context.l10n.settings_defaultImagesPath,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.folder_open, size: 20),
                      tooltip: context.l10n.settings_openFolder,
                      onPressed: () async {
                        final openFolderFailed =
                            context.l10n.settings_openFolderFailed;
                        try {
                          String path;
                          if (saveSettings.hasCustomPath) {
                            path = saveSettings.customPath!;
                          } else {
                            final docDir =
                                await getApplicationDocumentsDirectory();
                            path =
                                '${docDir.path}${Platform.pathSeparator}NAI_Launcher${Platform.pathSeparator}images';
                          }
                          await launchUrl(
                            Uri.directory(path),
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (e) {
                          AppLogger.e(openFolderFailed, e);
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
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: Text(context.l10n.settings_localOnnxTaggerFolder),
                subtitle: Text(
                  localOnnxDirectory.isEmpty
                      ? context.l10n.settings_notConfigured
                      : localOnnxDirectory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (localOnnxDirectory.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.folder_open, size: 20),
                        tooltip: context.l10n.settings_openFolder,
                        onPressed: () =>
                            _openLocalOnnxTaggerDirectory(localOnnxDirectory),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: _selectLocalOnnxTaggerDirectory,
              ),
              // Vibe库保存路径设置
              const VibeLibraryPathTile(),
              // Hive 数据存储路径设置
              const HiveStoragePathTile(),
              const Divider(height: 32),
              // 缓存统计
              const CacheStatisticsTile(),
              const Divider(height: 32),
              // 画廊缓存操作（清除缓存 + 重建索引）
              const GalleryCacheActions(),
            ],
          ),
        ),
        const DataSourceCacheSettings(),
      ],
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
        dialogTitle: context.l10n.settings_selectVibeLibraryFolder,
      );

      if (result != null && context.mounted) {
        await _pathHelper.setPath(result);
        await _pathHelper.ensurePathExists(result);
        setState(() {});

        if (context.mounted) {
          AppToast.success(context, context.l10n.settings_vibePathSaved);
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
          context,
          '${context.l10n.settings_selectFolderFailed}: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _resetToDefault(BuildContext context) async {
    await _pathHelper.resetToDefault();
    setState(() {});

    if (context.mounted) {
      AppToast.success(context, context.l10n.settings_pathReset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customPath = _pathHelper.getCustomPath();
    final hasCustomPath = _pathHelper.hasCustomPath;

    return ListTile(
      leading: const Icon(Icons.style_outlined),
      title: Text(context.l10n.settings_vibeLibraryPath),
      subtitle: FutureBuilder<String>(
        future: _pathHelper.getPath(),
        builder: (context, snapshot) {
          final displayPath = hasCustomPath
              ? (customPath ?? '')
              : (snapshot.data != null
                  ? context.l10n.settings_defaultVibePath(snapshot.data!)
                  : context.l10n.settings_defaultVibePath(
                      'Documents/NAI_Launcher/vibes/',
                    ));
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
            tooltip: context.l10n.settings_openFolder,
            onPressed: () async {
              final openFolderFailed = context.l10n.settings_openFolderFailed;
              try {
                final path = await _pathHelper.getPath();
                await launchUrl(
                  Uri.directory(path),
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                AppLogger.e(openFolderFailed, e);
              }
            },
          ),
          if (hasCustomPath)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: context.l10n.common_reset,
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
        dialogTitle: context.l10n.settings_selectHiveFolder,
      );

      if (result != null && context.mounted) {
        // 显示警告：更改存储路径需要重启应用
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text(context.l10n.settings_restartRequiredTitle),
            content: Text(context.l10n.settings_changePathConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.l10n.common_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.l10n.common_confirm),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await _hiveHelper.setCustomPath(result);
          setState(() {});

          if (context.mounted) {
            AppToast.success(context, context.l10n.settings_hivePathSaved);
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(
          context,
          '${context.l10n.settings_selectFolderFailed}: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _resetToDefault(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: Text(context.l10n.settings_restartRequiredTitle),
        content: Text(context.l10n.settings_resetPathConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _hiveHelper.resetToDefault();
      setState(() {});

      if (context.mounted) {
        AppToast.success(
          context,
          context.l10n.settings_pathSavedRestartRequired,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomPath = _hiveHelper.hasCustomPath;

    return ListTile(
      leading: const Icon(Icons.storage_outlined),
      title: Text(context.l10n.settings_hiveStoragePath),
      subtitle: Text(
        hasCustomPath
            ? (_hiveHelper.getCustomPath() ?? '')
            : context.l10n.settings_defaultHivePath,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.folder_open, size: 20),
            tooltip: context.l10n.settings_openFolder,
            onPressed: () async {
              final openFolderFailed = context.l10n.settings_openFolderFailed;
              try {
                final path = await _hiveHelper.getPath();
                await launchUrl(
                  Uri.directory(path),
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                AppLogger.e(openFolderFailed, e);
              }
            },
          ),
          if (hasCustomPath)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: context.l10n.common_reset,
              onPressed: () => _resetToDefault(context),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _selectHiveStorageDirectory(context),
    );
  }
}
