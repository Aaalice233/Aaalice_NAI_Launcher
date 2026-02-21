import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_export_utils.dart';
import '../../../../core/utils/vibe_image_embedder.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/vibe_library_extensions.dart';
import '../../../providers/vibe_library_provider.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/services/vibe_file_storage_service.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/hover_image_preview.dart';
import '../../../widgets/common/app_toast.dart';
import '../../vibe_library/widgets/vibe_selector_dialog.dart';
import '../../../widgets/common/collapsible_image_panel.dart';

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
      // 标题右侧操作按钮：导出
      headerActions: hasVibes
          ? [
              _buildExportButton(context, theme, vibes),
            ]
          : null,
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
  Widget _buildBackgroundImage(List<VibeReference> vibes) {
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

  /// 构建导出按钮（下拉菜单）
  Widget _buildExportButton(
    BuildContext context,
    ThemeData theme,
    List<VibeReference> vibes,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.download,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      tooltip: '导出 Vibe',
      offset: const Offset(0, 32),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'vibe',
          child: Row(
            children: [
              Icon(
                Icons.file_download,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('导出为 .vibe 文件'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'image',
          child: Row(
            children: [
              Icon(
                Icons.image,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              const Text('嵌入到图片（可多选）'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'vibe') {
          _exportAsVibeFile(vibes);
        } else if (value == 'image') {
          _embedIntoImage(vibes);
        }
      },
    );
  }

  /// 导出为 .vibe 文件
  ///
  /// 单张：直接导出为 .naiv4vibe
  /// 多张：询问导出为 bundle 还是逐个导出
  Future<void> _exportAsVibeFile(List<VibeReference> vibes) async {
    if (vibes.isEmpty) return;

    try {
      // 单张直接导出
      if (vibes.length == 1) {
        final result = await VibeExportUtils.exportToNaiv4Vibe(vibes.first);
        if (result != null && mounted) {
          AppToast.success(context, 'Vibe 导出成功');
        }
        return;
      }

      // 多张：询问导出方式
      final exportType = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导出多个 Vibe'),
          content: const Text('请选择导出方式'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('bundle'),
              child: const Text('导出为 Bundle'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('individual'),
              child: const Text('逐个导出'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      );

      if (exportType == null) return;

      if (exportType == 'bundle') {
        final result = await VibeExportUtils.exportToNaiv4VibeBundle(
          vibes,
          'vibe-bundle',
        );
        if (result != null && mounted) {
          AppToast.success(context, 'Bundle 导出成功');
        }
      } else {
        // 逐个导出
        var successCount = 0;
        for (final vibe in vibes) {
          final result = await VibeExportUtils.exportToNaiv4Vibe(vibe);
          if (result != null) successCount++;
        }
        if (mounted) {
          AppToast.success(context, '已导出 $successCount/${vibes.length} 个 Vibe');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '导出失败: $e');
      }
    }
  }

  /// 检查是否为 PNG 图片
  bool _isPng(List<int> bytes) {
    if (bytes.length < 8) return false;
    // PNG 文件签名: 89 50 4E 47 0D 0A 1A 0A
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  /// 嵌入 Vibe 到图片
  ///
  /// 正确流程：
  /// 1. 选择目标图片（容器）
  /// 2. 选择要嵌入的 vibes（可多选）
  /// 3. 执行嵌入并保存
  Future<void> _embedIntoImage(List<VibeReference> vibes) async {
    if (vibes.isEmpty) return;

    // 过滤掉没有编码数据的 vibe
    final embeddableVibes = vibes.where((v) {
      return v.vibeEncoding.isNotEmpty || v.rawImageData != null;
    }).toList();

    if (embeddableVibes.isEmpty) {
      if (mounted) {
        AppToast.warning(context, '没有可嵌入的 Vibe（需要编码数据）');
      }
      return;
    }

    // 第一步：选择目标图片
    final pickResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
      dialogTitle: '选择要嵌入 Vibe 的目标图片',
    );

    if (pickResult == null || pickResult.files.isEmpty) return;

    final file = pickResult.files.first;
    final filePath = file.path;
    Uint8List? imageBytes = file.bytes;

    // Windows 平台下 bytes 可能为空，需要从 path 读取
    if (imageBytes == null && filePath != null) {
      try {
        imageBytes = await File(filePath).readAsBytes();
      } catch (e) {
        if (mounted) {
          AppToast.error(context, '读取文件失败: $e');
        }
        return;
      }
    }

    if (imageBytes == null) {
      if (mounted) {
        AppToast.error(context, '无法读取图片文件');
      }
      return;
    }

    // 第二步：选择要嵌入的 vibes（多选对话框）
    if (!mounted) return;

    final selectedVibes = await showDialog<List<VibeReference>>(
      context: context,
      builder: (context) {
        final selectedNames = <String>{};

        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final selectedCount = selectedNames.length;

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('选择要嵌入的 Vibe'),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 全选/取消全选按钮
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (selectedCount == embeddableVibes.length) {
                                selectedNames.clear();
                              } else {
                                selectedNames.addAll(
                                  embeddableVibes.map((v) => v.displayName),
                                );
                              }
                            });
                          },
                          icon: Icon(
                            selectedCount == embeddableVibes.length
                                ? Icons.check_box_outlined
                                : Icons.check_box_outline_blank,
                          ),
                          label: Text(
                            selectedCount == embeddableVibes.length
                                ? '取消全选'
                                : '全选',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '可嵌入: ${embeddableVibes.length} 个',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Vibe 列表
                    Expanded(
                      child: ListView.builder(
                        itemCount: embeddableVibes.length,
                        itemBuilder: (context, index) {
                          final vibe = embeddableVibes[index];
                          final isSelected = selectedNames.contains(vibe.displayName);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  selectedNames.add(vibe.displayName);
                                } else {
                                  selectedNames.remove(vibe.displayName);
                                }
                              });
                            },
                            secondary: vibe.thumbnail != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.memory(
                                      vibe.thumbnail!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.image),
                                  ),
                            title: Text(
                              vibe.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              vibe.vibeEncoding.isNotEmpty ? '已编码' : '原始图片',
                              style: TextStyle(
                                color: vibe.vibeEncoding.isNotEmpty
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 已选择数量
                    Text(
                      '已选择: $selectedCount 个',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: selectedCount > 0
                      ? () {
                          final result = embeddableVibes
                              .where((v) => selectedNames.contains(v.displayName))
                              .toList();
                          Navigator.of(context).pop(result);
                        }
                      : null,
                  child: const Text('嵌入并保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedVibes == null || selectedVibes.isEmpty) return;

    // 第三步：执行嵌入
    if (mounted) {
      AppToast.info(context, '正在处理...');
    }

    try {
      // 确保是 PNG 格式（如果不是则转换）
      Uint8List processedBytes = imageBytes;
      if (!_isPng(imageBytes)) {
        final decoded = img.decodeImage(imageBytes);
        if (decoded == null) {
          if (mounted) {
            AppToast.error(context, '无法解码图片');
          }
          return;
        }
        processedBytes = Uint8List.fromList(img.encodePng(decoded));
      }

      // 嵌入 vibes（使用 bundle 格式，一次嵌入所有）
      final embeddedBytes = await VibeImageEmbedder.embedVibesToImage(
        processedBytes,
        selectedVibes,
      );

      // 保存嵌入后的图片
      final defaultFileName = selectedVibes.length == 1
          ? '${selectedVibes.first.displayName}_with_vibe.png'
          : 'image_with_${selectedVibes.length}_vibes.png';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存嵌入 Vibe 的图片',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (savePath == null) return;

      await File(savePath).writeAsBytes(embeddedBytes);

      if (mounted) {
        AppToast.success(
          context,
          '已成功嵌入 ${selectedVibes.length} 个 Vibe 到图片',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '嵌入失败: $e');
      }
    }
  }

  /// 构建库操作按钮（保存到库、从库导入）
  Widget _buildLibraryActions(
    BuildContext context,
    ThemeData theme,
    List<VibeReference> vibes,
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
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

              notifier.addVibeReferences(vibes);
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
    notifier.removeVibeReference(index);
    notifier.saveGenerationState();
  }

  void _updateVibeStrength(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, strength: value);
  }

  void _updateVibeInfoExtracted(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, infoExtracted: value);
  }

  void _clearAllVibes() {
    final params = ref.read(generationParamsNotifierProvider);
    final count = params.vibeReferencesV4.length;

    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    notifier.clearVibeReferences();
    notifier.saveGenerationState();

    if (mounted && count > 0) {
      AppToast.success(context, '已删除 $count 个 Vibe');
    }
  }

  /// 在库中查找已存在的相同 vibe 条目
  /// 基于 vibeEncoding 或缩略图哈希进行匹配
  /// 返回匹配的条目，如果没有找到返回 null
  Future<VibeLibraryEntry?> _findExistingEntry(
    VibeLibraryStorageService storageService,
    VibeReference vibe,
  ) async {
    final allEntries = await storageService.getAllEntries();
    return allEntries.findMatchingEntry(vibe);
  }

  /// 立即编码 Vibes（调用 API）
  Future<List<VibeReference>?> _encodeVibesNow(
    List<VibeReference> vibes,
  ) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final params = ref.read(generationParamsNotifierProvider);
    final model = params.model;

    // 显示编码进度对话框，使用 rootNavigator 确保正确关闭
    final dialogCompleter = Completer<void>();
    BuildContext? dialogContext;

    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) {
          dialogContext = ctx;
          dialogCompleter.complete();
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
      ),
    );

    // 等待对话框显示完成
    await dialogCompleter.future;

    void closeDialog() {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
    }

    try {
      final encodedVibes = <VibeReference>[];
      for (final vibe in vibes) {
        if (vibe.sourceType == VibeSourceType.rawImage &&
            vibe.rawImageData != null) {
          // 添加 30 秒超时保护，防止 API 无限卡住
          final encoding = await notifier
              .encodeVibeWithCache(
            vibe.rawImageData!,
            model: model,
            informationExtracted: vibe.infoExtracted,
            vibeName: vibe.displayName,
          )
              .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              AppLogger.w(
                'Vibe 编码超时: ${vibe.displayName}',
                'UnifiedReferencePanel',
              );
              return null;
            },
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

      closeDialog();

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
    } on TimeoutException catch (e) {
      AppLogger.e('Vibe 编码超时', e);
      closeDialog();
      if (mounted) {
        AppToast.error(context, 'Vibe 编码超时，请检查网络连接后重试');
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to encode vibes', e, stackTrace);
      closeDialog();
      return null;
    }
  }

  /// 保存已编码的 Vibes 到库
  /// 会检查库中是否已存在相同的 vibe，如果存在则只更新使用记录
  Future<void> _saveEncodedVibesToLibrary(
    List<VibeReference> vibes,
    String baseName,
  ) async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);

    try {
      var savedCount = 0;
      var reusedCount = 0;

      for (final vibe in vibes) {
        // 检查是否已存在相同的 vibe
        final existingEntry = await _findExistingEntry(storageService, vibe);

        AppLogger.d(
          '保存 Vibe: name=${vibe.displayName}, encoding=${vibe.vibeEncoding.substring(0, vibe.vibeEncoding.length > 20 ? 20 : vibe.vibeEncoding.length)}..., existing=${existingEntry?.id ?? "null"}',
          'UnifiedReferencePanel',
        );

        if (existingEntry != null) {
          // 已存在：更新使用记录
          await storageService.incrementUsedCount(existingEntry.id);
          reusedCount++;
          AppLogger.d(
            'Vibe 已存在，更新使用记录: ${existingEntry.id}',
            'UnifiedReferencePanel',
          );
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
          AppLogger.i(
            '新 Vibe 已保存: ${entry.id}, name=${entry.name}',
            'UnifiedReferencePanel',
          );
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
        // 通知 Vibe 库刷新
        ref.read(vibeLibraryNotifierProvider.notifier).reload();
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

    // 检查是否有未编码的原始图片
    final unencodedVibes = vibes
        .where(
          (v) => v.sourceType == VibeSourceType.rawImage && v.vibeEncoding.isEmpty,
        )
        .toList();

    if (unencodedVibes.isNotEmpty) {
      AppToast.warning(
        context, 
        '${unencodedVibes.length} 个 Vibe 需要先编码才能保存到库中',
      );
      return;
    }

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
                      label: context.l10n.vibe_strength,
                      value: strengthValue,
                      onChanged: (value) =>
                          setState(() => strengthValue = value),
                    ),
                    const SizedBox(height: 16),
                    // Information Extracted 滑条
                    _buildDialogSlider(
                      label: context.l10n.vibe_infoExtracted,
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

          // 检查是否已存在相同名称的 vibe（基于名称去重，而非内容）
          // 这样用户可以用不同名称保存相同内容
          final allEntries = await storageService.getAllEntries();
          final existingEntry = allEntries.firstWhereOrNull((entry) {
            return entry.name.toLowerCase() == name.toLowerCase();
          });

          if (existingEntry != null) {
            // 已存在相同名称：删除旧条目和文件，创建新的（覆盖更新）
            await storageService.deleteEntry(existingEntry.id);
            reusedCount++;
          }

          // 创建新条目（无论是否已存在，都创建新的）
          final entry = VibeLibraryEntry.fromVibeReference(
            name: vibes.length == 1 ? name : '$name - ${vibe.displayName}',
            vibeData: vibeWithParams,
          );
          await storageService.saveEntry(entry);
          savedCount++;
        }

        if (mounted) {
          String message;
          if (savedCount > 0 && reusedCount > 0) {
            message = '已覆盖 $reusedCount 个，新增 $savedCount 个';
          } else if (savedCount > 0) {
            message = '已保存到 Vibe 库';
          } else {
            message = '没有保存任何 Vibe';
          }
          AppToast.success(context, message);
          _loadRecentEntries(); // 刷新最近列表
          // 通知 Vibe 库刷新
          ref.read(vibeLibraryNotifierProvider.notifier).reload();
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
        notifier.clearVibeReferences();
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
            notifier.addVibeReferences([vibe]);
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
      final extractedVibes = <VibeReference>[];

      for (int i = 0;
          i < entry.bundledVibeCount.clamp(0, availableSlots);
          i++) {
        final vibe =
            await fileStorage.extractVibeFromBundle(entry.filePath!, i);
        if (vibe != null) extractedVibes.add(vibe);
      }

      if (extractedVibes.isNotEmpty) {
        // 设置 bundle 来源
        final vibesWithSource = extractedVibes.map((vibe) => vibe.copyWith(
          bundleSource: entry.displayName,
        ),).toList();
        notifier.addVibeReferences(vibesWithSource);

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

    // 更新使用统计（包括 bundle）
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    await storageService.incrementUsedCount(entry.id);

    // 如果是 bundle，提取所有内部 vibes
    if (entry.isBundle) {
      await _addVibesFromBundle(entry);
      return;
    }

    final vibe = entry.toVibeReference();
    notifier.addVibeReferences([vibe]);

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
    notifier.addVibeReferences([vibe]);

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
    List<VibeReference> vibes,
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
                  return _VibeCard(
                    index: index,
                    vibe: vibe,
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
class _VibeCard extends ConsumerStatefulWidget {
  final int index;
  final VibeReference vibe;
  final VoidCallback onRemove;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;
  final bool showBackground;

  const _VibeCard({
    required this.index,
    required this.vibe,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
    this.showBackground = false,
  });

  @override
  ConsumerState<_VibeCard> createState() => _VibeCardState();
}

class _VibeCardState extends ConsumerState<_VibeCard> {
  bool _isEncoding = false;
  
  // 跟踪已经显示过编码对话框的 vibe （使用缩略图哈希作为 ID）
  static final Set<String> _shownDialogs = {};

  @override
  void initState() {
    super.initState();
    // 如果是新添加的未编码原始图片，自动显示编码对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowEncodingDialog();
    });
  }
  
  void _checkAndShowEncodingDialog() {
    final vibe = widget.vibe;
    final needsEncoding = vibe.sourceType == VibeSourceType.rawImage && 
                          vibe.vibeEncoding.isEmpty &&
                          vibe.rawImageData != null;
    
    if (needsEncoding) {
      // 生成唯一 ID（基于图片数据哈希）
      final vibeId = _calculateVibeId(vibe);
      
      // 确保只显示一次
      if (!_shownDialogs.contains(vibeId)) {
        _shownDialogs.add(vibeId);
        _showEncodingDialog();
      }
    }
  }
  
  String _calculateVibeId(VibeReference vibe) {
    if (vibe.rawImageData != null) {
      return sha256.convert(vibe.rawImageData!).toString();
    }
    return vibe.displayName + DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = widget.vibe;

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
          // 左侧：缩略图 + Bundle 标签
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThumbnail(theme),
              const SizedBox(height: 6),
              // Bundle 来源标识移到缩略图下方，宽度与缩略图一致
              if (vibe.bundleSource != null)
                _buildBundleSourceChip(context, theme),
            ],
          ),
          const SizedBox(width: 12),

          // 右侧：滑条和源类型
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部行：编码状态标签 + 删除按钮
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 编码状态标签
                    _buildEncodingStatusChip(context, theme),
                    const Spacer(),
                    // 删除按钮（右上角）
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: widget.onRemove,
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
                  onChanged: widget.onStrengthChanged,
                ),

                // Information Extracted 滑条
                _buildSliderRow(
                  context,
                  theme,
                  label: context.l10n.vibe_infoExtraction,
                  value: vibe.infoExtracted,
                  onChanged: widget.onInfoExtractedChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    final thumbnailBytes = widget.vibe.thumbnail ?? widget.vibe.rawImageData;

    // 悬浮预览使用原始图片数据或缩略图
    final previewBytes = widget.vibe.rawImageData ?? widget.vibe.thumbnail;

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
    final isEncoded = widget.vibe.vibeEncoding.isNotEmpty;
    final needsEncoding = widget.vibe.sourceType == VibeSourceType.rawImage;

    if (isEncoded) {
      // 已编码状态
      return Container(
        constraints: const BoxConstraints(maxWidth: 80),
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
            Flexible(
              child: Text(
                '已编码',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    } else if (needsEncoding) {
      // 需要编码状态 - 可点击按钮
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isEncoding ? null : _showEncodingDialog,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 100),
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
                if (_isEncoding)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  )
                else
                  const Icon(
                    Icons.pending,
                    size: 12,
                    color: Colors.orange,
                  ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _isEncoding ? '编码中...' : '待编码 (2 Anlas)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // 预编码文件状态
      return Container(
        constraints: const BoxConstraints(maxWidth: 80),
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
            Flexible(
              child: Text(
                widget.vibe.sourceType.displayLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// 显示编码确认对话框
  Future<void> _showEncodingDialog() async {
    final context = this.context;
    final l10n = context.l10n;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认编码 Vibe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('是否编码此图片以供生成使用？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '此操作将消耗 2 Anlas（点数）',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
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
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('编码'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _encodeVibe();
    }
  }

  /// 执行编码
  Future<void> _encodeVibe() async {
    if (_isEncoding || widget.vibe.rawImageData == null) return;

    setState(() => _isEncoding = true);

    try {
      final notifier = ref.read(generationParamsNotifierProvider.notifier);
      final model = ref.read(generationParamsNotifierProvider).model;

      // 调用编码 API
      final encoding = await notifier.encodeVibeWithCache(
        widget.vibe.rawImageData!,
        model: model,
        informationExtracted: widget.vibe.infoExtracted,
        vibeName: widget.vibe.displayName,
      );

      if (encoding != null && mounted) {
        // 更新 vibe 编码状态
        notifier.updateVibeReference(
          widget.index,
          vibeEncoding: encoding,
        );
        AppToast.success(context, 'Vibe 编码成功！');
      } else if (mounted) {
        AppToast.error(context, 'Vibe 编码失败，请重试');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '编码失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isEncoding = false);
      }
    }
  }

  /// 构建 Bundle 来源标识
  Widget _buildBundleSourceChip(BuildContext context, ThemeData theme) {
    final source = widget.vibe.bundleSource;
    if (source == null) return const SizedBox.shrink();

    // 宽度与缩略图一致 100px
    return SizedBox(
      width: 100,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.tertiary.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_zip,
              size: 12,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                source,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 主缩略图
                    entry.hasThumbnail || entry.hasVibeThumbnail
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
                    // Bundle 标识
                    if (entry.isBundle)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers,
                                size: 10,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${entry.bundledVibeCount}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 8,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    entry.sourceType.displayLabel,
                    style: TextStyle(
                      fontSize: 8,
                      color: theme.colorScheme.primary,
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
