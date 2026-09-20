import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/services/file_export_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/hive_storage_helper.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_library_path_helper.dart';
import '../../../../data/cloud_sync/app_cloud_sync_adapters.dart';
import '../../../../data/services/local_onnx_model_service.dart';
import '../../../providers/image_save_settings_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../widgets/cache_statistics_tile.dart';
import '../widgets/data_source_cache_settings.dart';
import '../widgets/gallery_cache_actions.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_page_layout.dart';

/// 「目录由系统/沙盒接管」的副标题文案。
///
/// 【偏离上游】上游三处路径行都直接写 `settings_androidManagedStorage`
/// （「由系统安全管理；导出时可选择保存位置」）。那是 Android SAF 的说法，
/// iOS 上不准确——iOS 是沙盒把目录固定在应用容器内、根本改不了，
/// 所以 iOS 换成 `settings_pathFixedIosHint`。能力门控本身沿用上游的
/// `supportsCustomStorageDirectories`，只替换文案。
String _managedStorageSubtitle(BuildContext context) {
  return PlatformCapabilities.current.isIOS
      ? context.l10n.settings_pathFixedIosHint
      : context.l10n.settings_androidManagedStorage;
}

/// 「导入配置」允许写回的设置键白名单。
///
/// 【上游没有配置导出/导入】v4.2.1 的配置迁移只有云同步一条路，而云同步在 iOS 上
/// 只剩 GitHub / WebDAV 且必须先配好凭据，「把 PC 上的一份配置直接搬到手机」没有
/// 替代品，所以这两个入口是我们的纯增量（服务层见 `LocalStorageService`）。
///
/// 白名单直接复用云同步已经审定过的三组可迁移键，再补上词库/固定词的内容键：
/// 这样「哪些设置可以跨设备搬」只有云同步 adapter 一处事实来源，上游新增设置时
/// 两条通道自动保持一致，不会出现只更新了一边的情况。不在这四组里的键（窗口几何、
/// 存储路径、凭据、缓存索引等设备本地值）一律跳过。
///
/// 不能写成 const：`portablePromptSettingKeys` 与 `contentSettingKeys` 的固定词
/// 三个键是重复的，const Set 字面量里出现相等元素是编译期错误。
final Set<String> _importableSettingKeys = <String>{
  ...portableSettingKeys,
  ...portablePromptSettingKeys,
  ...portableOnlineGallerySettingKeys,
  ...contentSettingKeys,
};

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

  /// iOS：在「文件」App 里打开 Documents/tagger_models。
  ///
  /// 【上游没有这个入口】上游的 `supportsOpenFolder => isDesktop`，iOS 上
  /// 一个打开目录的路径都没有，而 `Uri.directory(...)` 交给 `launchUrl`
  /// 在 iOS 上只会静默失败。iOS 的正确做法是把 `file://` 换成私有的
  /// `shareddocuments://` scheme，系统会直接跳进「文件」App 的对应文件夹。
  /// 这是用户手动投放 GB 级模型的唯一可达入口，必须保留。
  Future<void> _openIosTaggerFolder() async {
    final openFolderFailed = context.l10n.settings_openFolderFailed;
    try {
      final directory = await ref
          .read(localOnnxModelServiceProvider)
          .resolveTaggerDirectory();
      await launchUrl(
        Uri.file(directory).replace(scheme: 'shareddocuments'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      AppLogger.e(openFolderFailed, e);
    }
  }

  /// 导出全部本地设置为一份带版本信封的 JSON 文件。
  ///
  /// 【上游没有这个入口】理由见 [_importableSettingKeys]。落盘统一走
  /// [FileExportService.saveText]：桌面是另存为对话框、Android 是 SAF、
  /// iOS 是临时文件 + 系统分享面板，这里不再自己写 `Platform.isIOS` 分支。
  Future<void> _exportConfig() async {
    final l10n = context.l10n;
    try {
      final document = ref
          .read(localStorageServiceProvider)
          .buildSettingsExportDocument();
      final json = const JsonEncoder.withIndent('  ').convert(document);
      // 文件名带时间戳，便于用户同时保留多份快照且不会互相覆盖。
      final stamp = DateTime.now()
          .toIso8601String()
          .split('.')
          .first
          .replaceAll(':', '-');
      final savedPath = await FileExportService.saveText(
        text: json,
        fileName: 'nai_launcher_config_$stamp.json',
        dialogTitle: l10n.settings_exportConfig,
        mimeType: 'application/json',
        allowedExtensions: const ['json'],
      );
      // null = 用户取消了另存为/分享面板，不提示。
      if (savedPath == null || !mounted) return;
      AppToast.success(context, l10n.settings_configExported);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, '${l10n.settings_configExportFailed}: $e');
    }
  }

  /// 从导出文件恢复设置：解析 → 确认 → 按白名单写回。
  ///
  /// 【上游没有这个入口】理由见 [_importableSettingKeys]。导入会覆盖本机现有值，
  /// 所以写回前必须有一次明确确认；文件格式版本比本版本新时额外加一行提醒，
  /// 因为那种文件里很可能有本版本读不懂、会被静默跳过的条目。
  Future<void> _importConfig() async {
    final l10n = context.l10n;
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.settings_importConfig,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = picked?.files.isNotEmpty == true
          ? picked!.files.first.path
          : null;
      if (path == null) return;

      final parsed = LocalStorageService.parseSettingsExport(
        await File(path).readAsString(),
      );
      if (!mounted) return;

      final confirmed = await ThemedConfirmDialog.show(
        context: context,
        title: l10n.settings_importConfigConfirmTitle,
        content: parsed.isNewerThanSupported
            ? '${l10n.settings_importConfigConfirmMessage}\n\n'
                  '${l10n.settings_importConfigNewerFormat}'
            : l10n.settings_importConfigConfirmMessage,
        confirmText: l10n.common_confirm,
        cancelText: l10n.common_cancel,
        type: ThemedConfirmDialogType.warning,
        icon: Icons.warning_amber_rounded,
      );
      if (!confirmed) return;

      final result = await ref
          .read(localStorageServiceProvider)
          .importSettings(parsed.settings, allowedKeys: _importableSettingKeys);
      if (!mounted) return;
      // 带上「采纳/总数」，让用户直接看到白名单过滤掉了多少条，而不是以为全导入了。
      final total = result.importedCount + result.skippedCount;
      AppToast.success(
        context,
        '${l10n.settings_configImported}: ${result.importedCount}/$total',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, '${l10n.settings_configImportFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveSettings = ref.watch(imageSaveSettingsNotifierProvider);
    final localOnnxService = ref.watch(localOnnxModelServiceProvider);
    final localOnnxDirectory = localOnnxService.taggerDirectory;
    final isIos = PlatformCapabilities.current.isIOS;

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
                      ? _managedStorageSubtitle(context)
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
                            count > 0
                                ? context.l10n.settings_localOnnxManagedFiles(
                                    count,
                                  )
                                // 【偏离上游】上游空态只提「应用内导入」。iOS 上
                                // 自管目录就是 Documents/tagger_models，用户也可以
                                // 用「文件」App 直接往里放模型——这是他既有的使用
                                // 方式，空态必须把这条路径写清楚。
                                : isIos
                                ? context
                                      .l10n
                                      .settings_localOnnxTaggerFolderIosHint
                                : context
                                      .l10n
                                      .settings_importLocalOnnxTaggerFiles,
                            maxLines: isIos ? 3 : 2,
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
                      // 【偏离上游】上游只在「非自管目录」分支才给打开目录按钮，
                      // 于是 iOS 走自管分支后完全没有打开目录的入口。
                      // iOS 的自管目录恰好是「文件」App 可见的，必须留这个跳转。
                      if (isIos)
                        IconButton(
                          icon: const Icon(Icons.folder_open, size: 20),
                          tooltip: context.l10n.settings_openFolder,
                          onPressed: _openIosTaggerFolder,
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
        // 配置备份：导出 / 导入。
        // 【上游没有这张卡】理由见 _importableSettingKeys；不给标题是因为可用的
        // 板块标题键只有「图片 / 模型与库 / 缓存维护」三个，这两条都不属于它们，
        // 而两个 ListTile 自带标题与说明，无标题卡是本仓库既有形态。
        SettingsCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(context.l10n.settings_exportConfig),
                subtitle: Text(
                  context.l10n.settings_exportConfigSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: _exportConfig,
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(context.l10n.settings_importConfig),
                subtitle: Text(
                  context.l10n.settings_importConfigSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: _importConfig,
              ),
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
              _managedStorageSubtitle(context),
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
            : _managedStorageSubtitle(context),
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
