import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/hive_storage_helper.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_library_path_helper.dart';
import '../../../../data/services/local_onnx_model_service.dart';
import '../../../providers/image_save_settings_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../widgets/cache_statistics_tile.dart';
import '../widgets/data_source_cache_settings.dart';
import '../widgets/gallery_cache_actions.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_page_layout.dart';

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

  Future<void> _configureLocalOnnxTagger() async {
    if (PlatformCapabilities.current.supportsManagedFileImports) {
      await _importLocalOnnxTaggerFiles();
      return;
    }

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: context.l10n.settings_selectLocalOnnxTaggerFolder,
      );
      if (result == null) return;
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

  Future<void> _importLocalOnnxTaggerFiles() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: context.l10n.settings_importLocalOnnxTaggerFiles,
        // Android maps custom extensions to MIME types before opening its
        // document picker. ONNX and external-data extensions have no standard
        // mapping and would be hidden, so let the service validate selections.
        type: FileType.any,
        allowMultiple: true,
      );
      if (selection == null) return;
      final sources = selection.files
          .where((file) => file.path != null)
          .map(
            (file) => LocalOnnxImportSource(name: file.name, path: file.path!),
          )
          .toList(growable: false);
      final importedCount = await ref
          .read(localOnnxModelServiceProvider)
          .importTaggerSelections(sources);
      if (mounted) {
        setState(() {});
        AppToast.success(
          context,
          context.l10n.settings_localOnnxFilesImported(importedCount),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.tagLibrary_importFailedWithError('$e'),
        );
      }
    }
  }

  Future<void> _clearLocalOnnxTaggerFiles() async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.settings_clearLocalOnnxModelsTitle,
      content: context.l10n.settings_clearLocalOnnxModelsContent,
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
    if (!confirmed) return;
    await ref.read(localOnnxModelServiceProvider).clearManagedTaggerFiles();
    if (mounted) setState(() {});
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

    return SettingsPageLayout(
      title: context.l10n.settings_dataStorage,
      children: [
        SettingsCard(
          title: context.l10n.settings_storageImagesSection,
          icon: Icons.image_outlined,
          child: Column(
            children: [
              // 图片保存路径设置
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(context.l10n.settings_imageSavePath),
                subtitle: Text(
                  PlatformCapabilities.current.usesAppManagedStorage
                      ? context.l10n.settings_androidManagedStorage
                      : saveSettings.getDisplayPath(
                          context.l10n.settings_defaultImagesPath,
                        ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing:
                    PlatformCapabilities
                        .current
                        .supportsCustomStorageDirectories
                    ? Row(
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
                                    .read(
                                      imageSaveSettingsNotifierProvider
                                          .notifier,
                                    )
                                    .resetToDefault();
                                if (context.mounted) {
                                  AppToast.success(
                                    context,
                                    context.l10n.settings_pathReset,
                                  );
                                }
                              },
                            ),
                        ],
                      )
                    : null,
                onTap:
                    PlatformCapabilities
                        .current
                        .supportsCustomStorageDirectories
                    ? () => _selectSaveDirectory(context)
                    : null,
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
            ],
          ),
        ),
        SettingsCard(
          title: context.l10n.settings_storageLibrariesSection,
          icon: Icons.folder_copy_outlined,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: Text(context.l10n.settings_localOnnxTaggerFolder),
                subtitle:
                    PlatformCapabilities.current.supportsManagedFileImports
                    ? FutureBuilder<int>(
                        future: localOnnxService.managedFileCount(),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Text(
                            count == 0
                                ? context
                                      .l10n
                                      .settings_importLocalOnnxTaggerFiles
                                : context.l10n.settings_localOnnxManagedFiles(
                                    count,
                                  ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      )
                    : Text(
                        localOnnxDirectory.isEmpty
                            ? context.l10n.settings_notConfigured
                            : localOnnxDirectory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (PlatformCapabilities
                        .current
                        .supportsManagedFileImports) ...[
                      if (localOnnxDirectory.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: context.l10n.common_delete,
                          onPressed: _clearLocalOnnxTaggerFiles,
                        ),
                      IconButton(
                        icon: const Icon(Icons.file_upload_outlined, size: 20),
                        tooltip:
                            context.l10n.settings_importLocalOnnxTaggerFiles,
                        onPressed: _importLocalOnnxTaggerFiles,
                      ),
                    ] else ...[
                      if (localOnnxDirectory.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.folder_open, size: 20),
                          tooltip: context.l10n.settings_openFolder,
                          onPressed: () =>
                              _openLocalOnnxTaggerDirectory(localOnnxDirectory),
                        ),
                    ],
                  ],
                ),
                onTap: _configureLocalOnnxTagger,
              ),
              // Vibe库保存路径设置
              const VibeLibraryPathTile(),
              // Hive 数据存储路径设置
              const HiveStoragePathTile(),
            ],
          ),
        ),
        SettingsCard(
          title: context.l10n.settings_storageCacheSection,
          child: Column(
            children: [
              // 缓存统计
              LayoutBuilder(
                builder: (context, constraints) {
                  final needsScrollableMetrics =
                      constraints.maxWidth < 480 &&
                      MediaQuery.textScalerOf(context).scale(1) > 1.6;
                  if (!needsScrollableMetrics) {
                    return const CacheStatisticsTile();
                  }
                  return const SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: 480, child: CacheStatisticsTile()),
                  );
                },
              ),
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

    final supportsCustomDirectory =
        PlatformCapabilities.current.supportsCustomStorageDirectories;
    return ListTile(
      leading: const Icon(Icons.style_outlined),
      title: Text(context.l10n.settings_vibeLibraryPath),
      subtitle: supportsCustomDirectory
          ? FutureBuilder<String>(
              future: _pathHelper.getPath(),
              builder: (context, snapshot) {
                final displayPath = hasCustomPath
                    ? (customPath ?? '')
                    : (snapshot.data != null
                          ? context.l10n.settings_defaultVibePath(
                              snapshot.data!,
                            )
                          : context.l10n.settings_defaultVibePath(
                              'Documents/NAI_Launcher/vibes/',
                            ));
                return Text(
                  displayPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            )
          : Text(
              context.l10n.settings_androidManagedStorage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: supportsCustomDirectory
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 20),
                  tooltip: context.l10n.settings_openFolder,
                  onPressed: () async {
                    final openFolderFailed =
                        context.l10n.settings_openFolderFailed;
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
              ],
            )
          : null,
      onTap: supportsCustomDirectory
          ? () => _selectVibeLibraryDirectory(context)
          : null,
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
        final confirmed = await ThemedConfirmDialog.show(
          context: context,
          title: context.l10n.settings_restartRequiredTitle,
          content: context.l10n.settings_changePathConfirm,
          confirmText: context.l10n.common_confirm,
          cancelText: context.l10n.common_cancel,
          type: ThemedConfirmDialogType.warning,
          icon: Icons.warning_amber_rounded,
        );

        if (confirmed) {
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
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.settings_restartRequiredTitle,
      content: context.l10n.settings_resetPathConfirm,
      confirmText: context.l10n.common_confirm,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.warning,
      icon: Icons.warning_amber_rounded,
    );

    if (confirmed) {
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

    final supportsCustomDirectory =
        PlatformCapabilities.current.supportsCustomStorageDirectories;
    return ListTile(
      leading: const Icon(Icons.storage_outlined),
      title: Text(context.l10n.settings_hiveStoragePath),
      subtitle: Text(
        supportsCustomDirectory
            ? (hasCustomPath
                  ? (_hiveHelper.getCustomPath() ?? '')
                  : context.l10n.settings_defaultHivePath)
            : context.l10n.settings_androidManagedStorage,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: supportsCustomDirectory
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 20),
                  tooltip: context.l10n.settings_openFolder,
                  onPressed: () async {
                    final openFolderFailed =
                        context.l10n.settings_openFolderFailed;
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
              ],
            )
          : null,
      onTap: supportsCustomDirectory
          ? () => _selectHiveStorageDirectory(context)
          : null,
    );
  }
}
