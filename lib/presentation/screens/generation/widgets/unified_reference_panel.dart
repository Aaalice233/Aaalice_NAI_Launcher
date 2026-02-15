import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference_v4.dart';
import '../../../../data/services/vibe_file_storage_service.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/hover_image_preview.dart';
import '../../../widgets/common/app_toast.dart';
import '../../vibe_library/widgets/vibe_selector_dialog.dart';
import '../../../widgets/common/collapsible_image_panel.dart';

extension VibeLibraryEntryMatching on List<VibeLibraryEntry> {
  List<VibeLibraryEntry> deduplicateByEncodingAndThumbnail({int limit = 5}) {
    final seenEncodings = <String>{};
    final seenImageHashes = <String>{};
    final uniqueEntries = <VibeLibraryEntry>[];

    for (final entry in this) {
      if (entry.vibeEncoding.isNotEmpty) {
        if (seenEncodings.contains(entry.vibeEncoding)) {
          continue;
        }
        seenEncodings.add(entry.vibeEncoding);
        uniqueEntries.add(entry);
      } else if (entry.hasThumbnail && entry.thumbnail != null) {
        final hash = _calculateVibeThumbnailHash(entry.thumbnail!);
        if (seenImageHashes.contains(hash)) {
          continue;
        }
        seenImageHashes.add(hash);
        uniqueEntries.add(entry);
      } else {
        uniqueEntries.add(entry);
      }

      if (uniqueEntries.length >= limit) {
        break;
      }
    }

    return uniqueEntries;
  }

  VibeLibraryEntry? findMatchingEntry(VibeReferenceV4 vibe) {
    if (vibe.vibeEncoding.isNotEmpty) {
      for (final entry in this) {
        if (entry.vibeEncoding.isNotEmpty &&
            entry.vibeEncoding == vibe.vibeEncoding) {
          return entry;
        }
      }
      return null;
    }

    if (vibe.thumbnail != null) {
      final vibeHash = _calculateVibeThumbnailHash(vibe.thumbnail!);
      for (final entry in this) {
        if (entry.hasThumbnail && entry.thumbnail != null) {
          final entryHash = _calculateVibeThumbnailHash(entry.thumbnail!);
          if (entryHash == vibeHash) {
            return entry;
          }
        }
      }
      return null;
    }

    for (final entry in this) {
      if (entry.vibeDisplayName == vibe.displayName) {
        return entry;
      }
    }

    return null;
  }
}

String _calculateVibeThumbnailHash(Uint8List data) {
  return sha256.convert(data).toString().substring(0, 16);
}

/// Vibe Transfer 参考面板 - V4 Vibe Transfer（最多16张、预编码、编码成本显示）
///
/// 支持功能：
/// - V4 Vibe Transfer（16张、预编码、编码成本显示）
/// - Normalize 强度标准化开关
/// - 保存到库 / 从库导入
/// - 最近使用的 Vibes
/// - 源类型图标显示
class UnifiedReferencePanel extends ConsumerStatefulWidget {
  const UnifiedReferencePanel({super.key});

  @override
  ConsumerState<UnifiedReferencePanel> createState() =>
      _UnifiedReferencePanelState();
}

class _UnifiedReferencePanelState extends ConsumerState<UnifiedReferencePanel> {
  bool _isExpanded = false;
  bool _isRecentCollapsed = true; // 默认折叠
  List<VibeLibraryEntry> _recentEntries = [];

  /// 跟踪 vibe 的 bundle 来源
  /// Key: vibe displayName, Value: bundle 名称
  final Map<String, String> _vibeBundleSources = {};

  @override
  void initState() {
    super.initState();
    _loadRecentEntries();
    _loadRecentCollapsedState();
    _restoreGenerationState();
  }

  /// 加载最近使用区域的折叠状态
  Future<void> _loadRecentCollapsedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final collapsed = prefs.getBool(StorageKeys.vibeRecentCollapsed);
      if (mounted) {
        setState(() {
          _isRecentCollapsed = collapsed ?? true; // 默认折叠
        });
      }
    } catch (e) {
      AppLogger.e('Failed to load recent collapsed state', e);
    }
  }

  /// 保存最近使用区域的折叠状态
  Future<void> _saveRecentCollapsedState(bool collapsed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(StorageKeys.vibeRecentCollapsed, collapsed);
    } catch (e) {
      AppLogger.e('Failed to save recent collapsed state', e);
    }
  }

  /// 切换最近使用区域的折叠状态
  void _toggleRecentCollapsed() {
    final newState = !_isRecentCollapsed;
    setState(() {
      _isRecentCollapsed = newState;
    });
    _saveRecentCollapsedState(newState);
  }

  /// 恢复保存的生成状态
  Future<void> _restoreGenerationState() async {
    // 延迟执行，确保 notifier 已初始化
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      final notifier = ref.read(generationParamsNotifierProvider.notifier);
      await notifier.restoreGenerationState();
    }
  }

  bool _isDraggingOver = false;

  Future<void> _loadRecentEntries() async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    try {
      final entries = await storageService.getRecentEntries(limit: 20);
      final uniqueEntries = entries.deduplicateByEncodingAndThumbnail(limit: 5);

      if (mounted) {
        setState(() {
          _recentEntries = uniqueEntries;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to load recent vibes', e, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final vibes = params.vibeReferencesV4;
    final hasVibes = vibes.isNotEmpty;

    // 判断是否显示背景（折叠且有数据时显示）
    final showBackground = hasVibes && !_isExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.vibe_title,
      icon: Icons.auto_fix_high,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      hasData: hasVibes,
      backgroundImage: _buildBackgroundImage(vibes),
      badge: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: showBackground
              ? Colors.white.withOpacity(0.2)
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${params.vibeReferencesV4.length}/16',
          style: theme.textTheme.labelSmall?.copyWith(
            color: showBackground
                ? Colors.white
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),

            // Vibe Transfer 内容
            _buildVibeContent(
              context,
              theme,
              params,
              showBackground,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建背景图片
  Widget _buildBackgroundImage(List<VibeReferenceV4> vibes) {
    if (vibes.isEmpty) {
      return const SizedBox.shrink();
    }

    if (vibes.length == 1) {
      // 单张风格迁移：全屏背景
      final imageData = vibes.first.rawImageData ?? vibes.first.thumbnail;
      if (imageData != null) {
        return Image.memory(imageData, fit: BoxFit.cover);
      }
    } else {
      // 多张风格迁移：横向并列
      return Row(
        children: vibes.map((vibe) {
          final imageData = vibe.rawImageData ?? vibe.thumbnail;
          return Expanded(
            child: imageData != null
                ? Image.memory(imageData, fit: BoxFit.cover)
                : const SizedBox.shrink(),
          );
        }).toList(),
      );
    }
    return const SizedBox.shrink();
  }

  /// 构建 Vibe Transfer 内容
  Widget _buildVibeContent(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
    bool showBackground,
  ) {
    final vibes = params.vibeReferencesV4;
    final hasVibes = vibes.isNotEmpty;

    // 构建 Vibe 列表或空状态内容
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 说明文字
        Text(
          context.l10n.vibe_description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: showBackground
                ? Colors.white70
                : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),

        // Normalize 复选框
        _buildNormalizeOption(context, theme, params, showBackground),
        const SizedBox(height: 12),

        // Vibe 列表或空状态（包裹 DragTarget 支持拖拽）
        _buildDragTargetWrapper(
          context,
          theme,
          params,
          hasVibes,
          vibes,
          showBackground,
        ),

        // 添加按钮（有数据时显示）
        if (hasVibes && vibes.length < 16)
          OutlinedButton.icon(
            onPressed: _addVibe,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.vibe_addReference),
            style: showBackground
                ? OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  )
                : null,
          ),

        // 最近使用的 Vibes
        if (_recentEntries.isNotEmpty && vibes.length < 16) ...[
          const SizedBox(height: 16),
          _buildRecentVibes(context, theme),
        ],

        // 清除全部按钮
        if (hasVibes) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _clearAllVibes,
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(context.l10n.vibe_clearAll),
            style: TextButton.styleFrom(
              foregroundColor:
                  showBackground ? Colors.red[300] : theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  /// 构建库操作按钮（保存到库、从库导入）
  Widget _buildLibraryActions(
    BuildContext context,
    ThemeData theme,
    List<VibeReferenceV4> vibes,
  ) {
    return Row(
      children: [
        // 保存到库按钮
        Expanded(
          child: OutlinedButton.icon(
            onPressed: vibes.isNotEmpty ? _saveToLibrary : null,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('保存到库'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 从库导入按钮
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _importFromLibrary,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('从库导入'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建空状态 - 双卡片并排布局：从文件添加 + 从库导入
  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        // 从文件添加
        Expanded(
          child: _EmptyStateCard(
            icon: Icons.add_photo_alternate_outlined,
            title: context.l10n.vibe_addFromFileTitle,
            subtitle: context.l10n.vibe_addFromFileSubtitle,
            onTap: () async => await _addVibe(),
            theme: theme,
          ),
        ),
        const SizedBox(width: 12),
        // 从库导入
        Expanded(
          child: _EmptyStateCard(
            icon: Icons.folder_open_outlined,
            title: context.l10n.vibe_addFromLibraryTitle,
            subtitle: context.l10n.vibe_addFromLibrarySubtitle,
            onTap: () async => await _importFromLibrary(),
            theme: theme,
          ),
        ),
      ],
    );
  }

  /// 构建最近使用的 Vibes
  Widget _buildRecentVibes(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 可点击的标题栏
        InkWell(
          onTap: _toggleRecentCollapsed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '最近使用',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 4),
                // 折叠/展开图标
                AnimatedRotation(
                  turns: _isRecentCollapsed ? 0.75 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_left,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 可折叠的内容区域
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recentEntries.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = _recentEntries[index];
                  return _RecentVibeItem(
                    entry: entry,
                    onTap: () => _addRecentVibe(entry),
                  );
                },
              ),
            ),
          ),
          crossFadeState: _isRecentCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildNormalizeOption(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
    bool showBackground,
  ) {
    return Row(
      children: [
        Checkbox(
          value: params.normalizeVibeStrength,
          onChanged: (value) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .setNormalizeVibeStrength(value ?? true);
          },
          visualDensity: VisualDensity.compact,
          fillColor: showBackground
              ? WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.transparent;
                })
              : null,
          checkColor: showBackground ? Colors.black : null,
          side: showBackground ? const BorderSide(color: Colors.white) : null,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .setNormalizeVibeStrength(!params.normalizeVibeStrength);
            },
            child: Text(
              context.l10n.vibe_normalize,
              style: theme.textTheme.bodySmall?.copyWith(
                color: showBackground ? Colors.white : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addVibe() async {
    try {
      // 使用 withData: false 提高文件选择器打开速度
      // 通过路径异步读取文件内容，避免阻塞 UI
      // lockParentWindow: true 在 Windows 上可提高对话框打开性能
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'naiv4vibe',
          'naiv4vibebundle',
        ],
        allowMultiple: true,
        withData: false, // 优化：不直接读取文件数据，通过路径读取
        lockParentWindow: true, // 优化：锁定父窗口提高 Windows 性能
      );

      if (result != null && result.files.isNotEmpty) {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);

        for (final file in result.files) {
          Uint8List? bytes;
          final String fileName = file.name;

          // 优先使用已加载的字节（如果有），否则通过路径读取
          if (file.bytes != null) {
            bytes = file.bytes;
          } else if (file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }

          if (bytes != null) {
            try {
              var vibes = await VibeFileParser.parseFile(fileName, bytes);

              // 检查是否需要编码
              final needsEncoding = vibes.any(
                (v) => v.sourceType == VibeSourceType.rawImage,
              );

              // 如果需要编码，显示确认对话框
              var encodeNow = false;
              var autoSaveToLibrary = false;
              if (needsEncoding && mounted) {
                final result = await showDialog<
                    (bool confirmed, bool encode, bool autoSave)>(
                  context: context,
                  builder: (context) {
                    // 默认都勾选
                    var encodeChecked = true;
                    var autoSaveChecked = true;
                    return StatefulBuilder(
                      builder: (context, setState) {
                        // 根据勾选状态动态确定按钮文本
                        final confirmButtonText =
                            encodeChecked ? '确认编码' : '仅添加图片';

                        return AlertDialog(
                          title: Text(context.l10n.vibeNoEncodingWarning),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fileName),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.vibeWillCostAnlas(2),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.vibeEncodeConfirm,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              // 提前编码复选框
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    encodeChecked = !encodeChecked;
                                    if (!encodeChecked) {
                                      autoSaveChecked = false;
                                    }
                                  });
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: encodeChecked,
                                      onChanged: (value) {
                                        setState(() {
                                          encodeChecked = value ?? false;
                                          if (!encodeChecked) {
                                            autoSaveChecked = false;
                                          }
                                        });
                                      },
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '立即编码（消耗 2 Anlas）',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 自动保存到库复选框（仅在提前编码时可用）
                              InkWell(
                                onTap: encodeChecked
                                    ? () {
                                        setState(() {
                                          autoSaveChecked = !autoSaveChecked;
                                        });
                                      }
                                    : null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: autoSaveChecked,
                                      onChanged: encodeChecked
                                          ? (value) {
                                              setState(() {
                                                autoSaveChecked =
                                                    value ?? false;
                                              });
                                            }
                                          : null,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '编码后自动保存到 Vibe 库',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: encodeChecked
                                                  ? null
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.4),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context)
                                  .pop((false, false, false)),
                              child: Text(context.l10n.vibeCancel),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context)
                                  .pop((true, encodeChecked, autoSaveChecked)),
                              child: Text(confirmButtonText),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );

                if (result == null || result.$1 != true) {
                  continue; // 用户取消，跳过此文件
                }
                encodeNow = result.$2;
                autoSaveToLibrary = result.$3;

                // 如果需要提前编码
                if (encodeNow && mounted) {
                  final encodedVibes = await _encodeVibesNow(vibes);
                  if (!mounted) continue;
                  if (encodedVibes != null) {
                    vibes = encodedVibes;
                    // 编码成功后自动保存到库
                    if (autoSaveToLibrary && mounted) {
                      await _saveEncodedVibesToLibrary(encodedVibes, fileName);
                    }
                  } else {
                    // 编码失败，询问是否继续添加未编码的
                    final continueAnyway = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('编码失败'),
                        content:
                            const Text('图片编码失败，是否继续添加未编码的图片？\n\n生成时会再次尝试编码。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('继续'),
                          ),
                        ],
                      ),
                    );
                    if (continueAnyway != true) {
                      continue; // 跳过此文件
                    }
                  }
                }
              }

              notifier.addVibeReferencesV4(vibes);
            } catch (e) {
              if (mounted) {
                AppToast.error(context, 'Failed to parse $fileName: \$e');
              }
            }
          }
        }
        // 保存生成状态
        await notifier.saveGenerationState();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.img2img_selectFailed(e.toString()),
        );
      }
    }
  }

  void _removeVibe(int index) {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    // 清理 bundle 来源记录
    if (index < vibes.length) {
      final vibeName = vibes[index].displayName;
      _vibeBundleSources.remove(vibeName);
    }

    notifier.removeVibeReferenceV4(index);
    notifier.saveGenerationState();
  }

  void _updateVibeStrength(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReferenceV4(index, strength: value);
  }

  void _updateVibeInfoExtracted(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReferenceV4(index, infoExtracted: value);
  }

  void _clearAllVibes() {
    final params = ref.read(generationParamsNotifierProvider);
    final count = params.vibeReferencesV4.length;

    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    notifier.clearVibeReferencesV4();
    notifier.saveGenerationState();

    // 清空 bundle 来源记录
    _vibeBundleSources.clear();

    if (mounted && count > 0) {
      AppToast.success(context, '已删除 $count 个 Vibe');
    }
  }

  /// 在库中查找已存在的相同 vibe 条目
  /// 基于 vibeEncoding 或缩略图哈希进行匹配
  /// 返回匹配的条目，如果没有找到返回 null
  Future<VibeLibraryEntry?> _findExistingEntry(
    VibeLibraryStorageService storageService,
    VibeReferenceV4 vibe,
  ) async {
    final allEntries = await storageService.getAllEntries();
    return allEntries.findMatchingEntry(vibe);
  }

  /// 立即编码 Vibes（调用 API）
  Future<List<VibeReferenceV4>?> _encodeVibesNow(
    List<VibeReferenceV4> vibes,
  ) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final params = ref.read(generationParamsNotifierProvider);
    final model = params.model;

    // 显示编码进度对话框，使用 rootNavigator 确保正确关闭
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        dialogContext = ctx;
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在编码 Vibe...'),
            ],
          ),
        );
      },
    );

    try {
      final encodedVibes = <VibeReferenceV4>[];
      for (final vibe in vibes) {
        if (vibe.sourceType == VibeSourceType.rawImage &&
            vibe.rawImageData != null) {
          final encoding = await notifier.encodeVibeWithCache(
            vibe.rawImageData!,
            model: model,
            informationExtracted: vibe.infoExtracted,
            vibeName: vibe.displayName,
          );

          if (encoding != null) {
            encodedVibes.add(
              vibe.copyWith(
                vibeEncoding: encoding,
                sourceType: VibeSourceType.naiv4vibe,
                rawImageData: null, // 编码后不需要原始图片数据
              ),
            );
          } else {
            // 编码失败，保留原始 vibe
            encodedVibes.add(vibe);
          }
        } else {
          // 不需要编码或已有编码
          encodedVibes.add(vibe);
        }
      }

      // 使用保存的 dialogContext 关闭对话框
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      // 检查是否全部编码成功
      final allEncoded = encodedVibes.every(
        (v) =>
            v.sourceType != VibeSourceType.rawImage ||
            v.vibeEncoding.isNotEmpty,
      );

      if (allEncoded) {
        if (mounted) {
          AppToast.success(context, 'Vibe 编码完成');
        }
        return encodedVibes;
      } else {
        if (mounted) {
          AppToast.warning(context, '部分 Vibe 编码失败');
        }
        return encodedVibes;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to encode vibes', e, stackTrace);
      // 使用保存的 dialogContext 关闭对话框
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      return null;
    }
  }

  /// 保存已编码的 Vibes 到库
  /// 会检查库中是否已存在相同的 vibe，如果存在则只更新使用记录
  Future<void> _saveEncodedVibesToLibrary(
    List<VibeReferenceV4> vibes,
    String baseName,
  ) async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);

    try {
      var savedCount = 0;
      var reusedCount = 0;

      for (final vibe in vibes) {
        // 检查是否已存在相同的 vibe
        final existingEntry = await _findExistingEntry(storageService, vibe);

        if (existingEntry != null) {
          // 已存在：更新使用记录
          await storageService.incrementUsedCount(existingEntry.id);
          reusedCount++;
        } else {
          // 不存在：创建新条目
          final entry = VibeLibraryEntry.fromVibeReference(
            name: vibes.length == 1
                ? baseName
                : '$baseName - ${vibe.displayName}',
            vibeData: vibe,
          );
          await storageService.saveEntry(entry);
          savedCount++;
        }
      }

      if (mounted) {
        String message;
        if (savedCount > 0 && reusedCount > 0) {
          message = '新增 $savedCount 个，复用 $reusedCount 个';
        } else if (savedCount > 0) {
          message = '已保存 $savedCount 个编码后的 Vibe 到库中';
        } else {
          message = '库中已存在 $reusedCount 个，已更新使用记录';
        }
        AppToast.success(context, message);
        _loadRecentEntries(); // 刷新最近列表
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save encoded vibes to library', e, stackTrace);
      if (mounted) {
        AppToast.error(context, '保存到库失败: $e');
      }
    }
  }

  /// 保存当前 Vibes 到库（支持命名和参数设置）
  Future<void> _saveToLibrary() async {
    final params = ref.read(generationParamsNotifierProvider);
    final vibes = params.vibeReferencesV4;

    if (vibes.isEmpty) return;

    // 使用第一个 vibe 的默认值
    final firstVibe = vibes.first;
    final nameController = TextEditingController(
      text: vibes.length == 1 ? firstVibe.displayName : '',
    );

    final result = await showDialog<
        (bool confirmed, double strength, double infoExtracted)?>(
      context: context,
      builder: (context) {
        var strengthValue = firstVibe.strength;
        var infoExtractedValue = firstVibe.infoExtracted;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('保存到 Vibe 库'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('保存 ${vibes.length} 个 Vibe 到库中'),
                    const SizedBox(height: 16),
                    // 名称输入
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        hintText: '输入保存名称',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    // Reference Strength 滑条
                    _buildDialogSlider(
                      label: 'Reference Strength',
                      value: strengthValue,
                      onChanged: (value) =>
                          setState(() => strengthValue = value),
                    ),
                    const SizedBox(height: 16),
                    // Information Extracted 滑条
                    _buildDialogSlider(
                      label: 'Information Extracted',
                      value: infoExtractedValue,
                      onChanged: (value) =>
                          setState(() => infoExtractedValue = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(context.l10n.common_cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      Navigator.of(context).pop(
                        (
                          true,
                          strengthValue,
                          infoExtractedValue,
                        ),
                      );
                    }
                  },
                  child: Text(context.l10n.common_save),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result.$1 && mounted) {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final name = nameController.text.trim();
      final strength = result.$2;
      final infoExtracted = result.$3;

      try {
        var savedCount = 0;
        var reusedCount = 0;

        for (final vibe in vibes) {
          // 使用用户设置的参数创建新的 vibe
          final vibeWithParams = vibe.copyWith(
            strength: strength,
            infoExtracted: infoExtracted,
          );

          // 检查是否已存在相同的 vibe（基于原始内容，不包括参数）
          final existingEntry = await _findExistingEntry(storageService, vibe);

          if (existingEntry != null) {
            // 已存在：更新使用记录（保留用户设置的新参数）
            await storageService.incrementUsedCount(existingEntry.id);
            reusedCount++;
          } else {
            // 不存在：创建新条目
            final entry = VibeLibraryEntry.fromVibeReference(
              name: vibes.length == 1 ? name : '$name - ${vibe.displayName}',
              vibeData: vibeWithParams,
            );
            await storageService.saveEntry(entry);
            savedCount++;
          }
        }

        if (mounted) {
          String message;
          if (savedCount > 0 && reusedCount > 0) {
            message = '新增 $savedCount 个，复用 $reusedCount 个';
          } else if (savedCount > 0) {
            message = '已保存到 Vibe 库';
          } else {
            message = '库中已存在，已更新使用记录';
          }
          AppToast.success(context, message);
          _loadRecentEntries(); // 刷新最近列表
        }
      } catch (e, stackTrace) {
        AppLogger.e('Failed to save to library', e, stackTrace);
        if (mounted) {
          AppToast.error(context, '保存失败: \$e');
        }
      }
    }

    nameController.dispose();
  }

  /// 构建对话框中的滑条
  Widget _buildDialogSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          divisions: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 从库导入 Vibes
  Future<void> _importFromLibrary() async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);

    try {
      // 显示选择器对话框
      final result = await VibeSelectorDialog.show(
        context: context,
        initialSelectedIds: const {},
        showReplaceOption: true,
        title: '从库导入 Vibe',
      );

      if (result == null || result.selectedEntries.isEmpty) return;

      final notifier = ref.read(generationParamsNotifierProvider.notifier);

      if (result.shouldReplace) {
        // 替换模式：清除现有并添加新的
        notifier.clearVibeReferencesV4();
      }

      // 处理每个选中的条目（支持 bundle 展开）
      var totalAdded = 0;
      for (final entry in result.selectedEntries) {
        final currentCount =
            ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
        if (currentCount >= 16) break;

        if (entry.isBundle) {
          // 从 bundle 提取 vibes
          final added = await _extractAndAddBundleVibes(entry);
          totalAdded += added;
        } else {
          // 普通 vibe
          final existingNames = ref
              .read(generationParamsNotifierProvider)
              .vibeReferencesV4
              .map((v) => v.displayName)
              .toSet();
          if (!existingNames.contains(entry.displayName)) {
            final vibe = entry.toVibeReference();
            notifier.addVibeReferencesV4([vibe]);
            totalAdded++;
          }
        }

        // 更新使用统计
        await storageService.incrementUsedCount(entry.id);
      }

      // 刷新最近使用列表
      await _loadRecentEntries();

      if (mounted) {
        AppToast.success(
          context,
          '已导入 $totalAdded 个 Vibe',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import from library', e, stackTrace);
      if (mounted) {
        AppToast.error(context, '导入失败: $e');
      }
    }
  }

  /// 从 bundle 提取 vibes 并添加到生成参数
  /// 返回实际添加的数量
  Future<int> _extractAndAddBundleVibes(VibeLibraryEntry entry) async {
    return _addBundleVibesToGeneration(
      entry: entry,
      maxCount: 16,
      showToast: false,
    );
  }

  Future<int> _addBundleVibesToGeneration({
    required VibeLibraryEntry entry,
    required int maxCount,
    required bool showToast,
  }) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentCount =
        ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
    final availableSlots = maxCount - currentCount;

    if (availableSlots <= 0 || entry.filePath == null) return 0;

    try {
      final fileStorage = VibeFileStorageService();
      final extractedVibes = <VibeReferenceV4>[];

      for (int i = 0;
          i < entry.bundledVibeCount.clamp(0, availableSlots);
          i++) {
        final vibe =
            await fileStorage.extractVibeFromBundle(entry.filePath!, i);
        if (vibe != null) extractedVibes.add(vibe);
      }

      if (extractedVibes.isNotEmpty) {
        for (final vibe in extractedVibes) {
          _vibeBundleSources[vibe.displayName] = entry.displayName;
        }
        notifier.addVibeReferencesV4(extractedVibes);

        if (showToast && mounted) {
          AppToast.success(context, '已添加 ${extractedVibes.length} 个 Vibe');
        }
      }

      return extractedVibes.length;
    } catch (e, stackTrace) {
      AppLogger.e('从 Bundle 提取 Vibe 失败', e, stackTrace);
      return 0;
    }
  }

  /// 添加最近使用的 Vibe
  Future<void> _addRecentVibe(VibeLibraryEntry entry) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    if (vibes.length >= 16) {
      AppToast.warning(context, '已达到最大数量 (16张)');
      return;
    }

    // 如果是 bundle，提取所有内部 vibes
    if (entry.isBundle) {
      await _addVibesFromBundle(entry);
      return;
    }

    final vibe = entry.toVibeReference();
    notifier.addVibeReferencesV4([vibe]);

    // 更新使用统计
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    await storageService.incrementUsedCount(entry.id);

    if (mounted) {
      AppToast.success(context, '已添加: \${entry.displayName}');
    }
  }

  /// 从库中添加 Vibe（用于拖拽）
  Future<void> _addLibraryVibe(VibeLibraryEntry entry) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    // 检查是否超过 16 个限制
    if (vibes.length >= 16) {
      if (mounted) {
        AppToast.warning(context, '已达到最大数量 (16张)，请先移除一些 Vibe');
      }
      return;
    }

    // 如果是 bundle，提取所有内部 vibes
    if (entry.isBundle) {
      await _addVibesFromBundle(entry);
      return;
    }

    // 添加 Vibe 到生成参数
    final vibe = entry.toVibeReference();
    notifier.addVibeReferencesV4([vibe]);

    // 更新使用统计
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    await storageService.incrementUsedCount(entry.id);

    if (mounted) {
      AppToast.success(context, '已添加 Vibe: \${entry.displayName}');
    }
  }

  /// 从 bundle 中提取并添加所有 vibes
  Future<void> _addVibesFromBundle(VibeLibraryEntry entry) async {
    if (entry.filePath == null) {
      AppToast.error(context, 'Bundle 文件路径不存在');
      return;
    }

    // 检查是否有足够空间
    final currentCount =
        ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
    final availableSlots = 16 - currentCount;
    final bundleCount = entry.bundledVibeCount;

    if (availableSlots <= 0) {
      AppToast.warning(context, '已达到最大数量 (16张)，请先移除一些 Vibe');
      return;
    }

    if (bundleCount > availableSlots) {
      AppToast.warning(
        context,
        'Bundle 包含 \$bundleCount 个 Vibe，只能添加前 \$availableSlots 个',
      );
    }

    // 显示加载提示
    AppToast.info(context, '正在提取 Bundle 中的 Vibe...');

    try {
      final added = await _addBundleVibesToGeneration(
        entry: entry,
        maxCount: 16,
        showToast: false,
      );

      if (added <= 0) {
        if (mounted) {
          AppToast.error(context, '无法从 Bundle 中提取 Vibe');
        }
        return;
      }

      // 更新使用统计
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      await storageService.incrementUsedCount(entry.id);

      if (mounted) {
        AppToast.success(
          context,
          '已从 Bundle 添加 $added 个 Vibe',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('从 Bundle 提取 Vibe 失败', e, stackTrace);
      if (mounted) {
        AppToast.error(context, '提取 Bundle 失败: \$e');
      }
    }
  }

  /// 构建 DragTarget 包装器，支持从库拖拽 Vibe
  Widget _buildDragTargetWrapper(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
    bool hasVibes,
    List<VibeReferenceV4> vibes,
    bool showBackground,
  ) {
    return DragTarget<VibeLibraryEntry>(
      onWillAcceptWithDetails: (details) {
        // 检查是否超过 16 个限制
        final currentCount =
            ref.read(generationParamsNotifierProvider).vibeReferencesV4.length;
        if (currentCount >= 16) {
          if (mounted) {
            AppToast.warning(context, '已达到最大数量 (16张)');
          }
          return false;
        }
        setState(() => _isDraggingOver = true);
        return true;
      },
      onAcceptWithDetails: (details) async {
        HapticFeedback.heavyImpact();
        setState(() => _isDraggingOver = false);
        await _addLibraryVibe(details.data);
      },
      onLeave: (_) {
        setState(() => _isDraggingOver = false);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: _isDraggingOver
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : null,
            color: _isDraggingOver
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasVibes) ...[
                ...List.generate(vibes.length, (index) {
                  final vibe = vibes[index];
                  final bundleSource = _vibeBundleSources[vibe.displayName];
                  return _VibeCard(
                    index: index,
                    vibe: vibe,
                    bundleSource: bundleSource,
                    onRemove: () => _removeVibe(index),
                    onStrengthChanged: (value) =>
                        _updateVibeStrength(index, value),
                    onInfoExtractedChanged: (value) =>
                        _updateVibeInfoExtracted(index, value),
                    showBackground: showBackground,
                  );
                }),
                const SizedBox(height: 12),

                // 库操作按钮行
                _buildLibraryActions(context, theme, vibes),
                const SizedBox(height: 8),
              ] else ...[
                // 空状态优化
                _buildEmptyState(context, theme),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Vibe 卡片组件
class _VibeCard extends StatelessWidget {
  final int index;
  final VibeReferenceV4 vibe;
  final String? bundleSource;
  final VoidCallback onRemove;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;
  final bool showBackground;

  const _VibeCard({
    required this.index,
    required this.vibe,
    this.bundleSource,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：缩略图（占满剩余高度）
          _buildThumbnail(theme),
          const SizedBox(width: 12),

          // 右侧：滑条和源类型
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部行：编码状态标签 + Bundle 来源 + 删除按钮
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 编码状态标签
                    _buildEncodingStatusChip(context, theme),
                    // Bundle 来源标识
                    if (bundleSource != null) ...[
                      const SizedBox(width: 8),
                      _buildBundleSourceChip(context, theme),
                    ],
                    const Spacer(),
                    // 删除按钮（右上角）
                    SizedBox(
                      height: 28,
                      width: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: onRemove,
                        tooltip: context.l10n.vibe_remove,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reference Strength 滑条
                _buildSliderRow(
                  context,
                  theme,
                  label: context.l10n.vibe_referenceStrength,
                  value: vibe.strength,
                  onChanged: onStrengthChanged,
                ),

                // Information Extracted 滑条
                _buildSliderRow(
                  context,
                  theme,
                  label: context.l10n.vibe_infoExtraction,
                  value: vibe.infoExtracted,
                  onChanged: onInfoExtractedChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    final thumbnailBytes = vibe.thumbnail ?? vibe.rawImageData;

    // 悬浮预览使用原始图片数据或缩略图
    final previewBytes = vibe.rawImageData ?? vibe.thumbnail;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 100,
        height: 100,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: thumbnailBytes != null
              ? (previewBytes != null
                  ? HoverImagePreview(
                      imageBytes: previewBytes,
                      child: Image.memory(
                        thumbnailBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder(theme);
                        },
                      ),
                    )
                  : Image.memory(
                      thumbnailBytes,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder(theme);
                      },
                    ))
              : _buildPlaceholder(theme),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.auto_awesome,
        size: 24,
        color: theme.colorScheme.outline,
      ),
    );
  }

  /// 构建编码状态标签
  Widget _buildEncodingStatusChip(BuildContext context, ThemeData theme) {
    final isEncoded = vibe.vibeEncoding.isNotEmpty;
    final needsEncoding = vibe.sourceType == VibeSourceType.rawImage;

    if (isEncoded) {
      // 已编码状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.green.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 12,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              '已编码',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (needsEncoding) {
      // 需要编码状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pending,
              size: 12,
              color: Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              '待编码',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(2 Anlas)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    } else {
      // 预编码文件状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.blue.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.file_present,
              size: 12,
              color: Colors.blue,
            ),
            const SizedBox(width: 4),
            Text(
              vibe.sourceType.displayLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 构建 Bundle 来源标识
  Widget _buildBundleSourceChip(BuildContext context, ThemeData theme) {
    if (bundleSource == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_zip,
            size: 10,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 3),
          Text(
            bundleSource!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签 + 数值
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        // 滑条
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// 最近 Vibe 条目组件
class _RecentVibeItem extends StatelessWidget {
  final VibeLibraryEntry entry;
  final VoidCallback onTap;

  const _RecentVibeItem({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Column(
          children: [
            // 缩略图
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(7)),
                child: entry.hasThumbnail || entry.hasVibeThumbnail
                    ? Image.memory(
                        entry.thumbnail ?? entry.vibeThumbnail!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.image, size: 24),
                        ),
                      ),
              ),
            ),
            // 名称
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 源类型指示器
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: entry.isPreEncoded
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    entry.isPreEncoded ? Icons.check_circle : Icons.warning,
                    size: 8,
                    color: entry.isPreEncoded ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    entry.sourceType.displayLabel,
                    style: TextStyle(
                      fontSize: 8,
                      color: entry.isPreEncoded ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空状态卡片组件 - 双按钮布局用
class _EmptyStateCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;
  final ThemeData theme;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_EmptyStateCard> createState() => _EmptyStateCardState();
}

class _EmptyStateCardState extends State<_EmptyStateCard> {
  bool _isHovered = false;
  bool _isLoading = false;

  Future<void> _handleTap() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered
                ? theme.colorScheme.primary.withOpacity(0.5)
                : theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: _isHovered ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: _isLoading ? null : _handleTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: _isLoading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : AnimatedScale(
                          key: const ValueKey('icon'),
                          scale: _isHovered ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            widget.icon,
                            size: 40,
                            color: _isHovered
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withOpacity(0.6),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _isHovered
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
