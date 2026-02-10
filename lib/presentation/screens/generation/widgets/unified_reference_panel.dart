import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference_v4.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/hover_image_preview.dart';
import '../../../widgets/common/app_toast.dart';

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
  List<VibeLibraryEntry> _recentEntries = [];

  @override
  void initState() {
    super.initState();
    _loadRecentEntries();
  }

  Future<void> _loadRecentEntries() async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    try {
      final entries = await storageService.getRecentEntries(limit: 5);
      if (mounted) {
        setState(() {
          _recentEntries = entries;
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 背景图片层
          if (showBackground)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景图
                  _buildBackgroundImage(vibes),
                  // 暗化遮罩
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 内容层
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_fix_high,
                        size: 20,
                        color: showBackground
                            ? Colors.white
                            : hasVibes
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.vibe_title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: showBackground
                                ? Colors.white
                                : hasVibes
                                    ? theme.colorScheme.primary
                                    : null,
                          ),
                        ),
                      ),
                      // 数量标志（有数据时显示）
                      if (hasVibes) ...[
                        Container(
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
                      ],
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: showBackground ? Colors.white : null,
                      ),
                    ],
                  ),
                ),
              ),

              // 展开内容
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
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
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ],
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

        // Vibe 列表
        if (hasVibes) ...[
          ...List.generate(vibes.length, (index) {
            return _VibeCard(
              index: index,
              vibe: vibes[index],
              onRemove: () => _removeVibe(index),
              onStrengthChanged: (value) => _updateVibeStrength(index, value),
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

        // 添加按钮
        if (vibes.length < 16)
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

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_fix_high_outlined,
            size: 40,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '添加参考图来迁移视觉风格',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '支持 PNG、JPG、V4 Vibe 文件',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
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
        Row(
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
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
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
      );

      if (result != null && result.files.isNotEmpty) {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);

        for (final file in result.files) {
          Uint8List? bytes;
          final String fileName = file.name;

          if (file.bytes != null) {
            bytes = file.bytes;
          } else if (file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }

          if (bytes != null) {
            try {
              final vibes = await VibeFileParser.parseFile(fileName, bytes);

              // 检查是否需要编码
              final needsEncoding = vibes.any(
                (v) => v.sourceType == VibeSourceType.rawImage,
              );

              // 如果需要编码，显示确认对话框
              if (needsEncoding && mounted) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
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
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(context.l10n.vibeCancel),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(context.l10n.vibeConfirmEncode),
                      ),
                    ],
                  ),
                );

                if (confirm != true) {
                  continue; // 用户取消，跳过此文件
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
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
            context, context.l10n.img2img_selectFailed(e.toString()),);
      }
    }
  }

  void _removeVibe(int index) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .removeVibeReferenceV4(index);
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
    ref.read(generationParamsNotifierProvider.notifier).clearVibeReferencesV4();
  }

  /// 保存当前 Vibes 到库
  Future<void> _saveToLibrary() async {
    final params = ref.read(generationParamsNotifierProvider);
    final vibes = params.vibeReferencesV4;

    if (vibes.isEmpty) return;

    // 显示保存对话框
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存到 Vibe 库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('保存 ${vibes.length} 个 Vibe 到库中'),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '输入保存名称',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text(context.l10n.common_save),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final storageService = ref.read(vibeLibraryStorageServiceProvider);
      final name = nameController.text.trim();

      try {
        for (final vibe in vibes) {
          final entry = VibeLibraryEntry.fromVibeReference(
            name: vibes.length == 1 ? name : '$name - ${vibe.displayName}',
            vibeData: vibe,
          );
          await storageService.saveEntry(entry);
        }

        if (mounted) {
          AppToast.success(context, '已保存到 Vibe 库');
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

  /// 从库导入 Vibes
  Future<void> _importFromLibrary() async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);

    try {
      final entries = await storageService.getAllEntries();

      if (!mounted) return;

      if (entries.isEmpty) {
        AppToast.info(context, 'Vibe 库为空');
        return;
      }

      final selected = await showDialog<VibeLibraryEntry>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('从库导入 Vibe'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  leading: entry.hasThumbnail
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            entry.thumbnail!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.image, size: 20),
                        ),
                  title: Text(entry.displayName),
                  subtitle: Text(
                    entry.isPreEncoded ? '预编码' : '需编码 (2 Anlas)',
                    style: TextStyle(
                      fontSize: 12,
                      color: entry.isPreEncoded
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(entry),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.common_cancel),
            ),
          ],
        ),
      );

      if (selected != null && mounted) {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);
        final vibe = selected.toVibeReference();
        notifier.addVibeReferencesV4([vibe]);

        // 更新使用统计
        await storageService.incrementUsedCount(selected.id);

        if (mounted) {
          AppToast.success(context, '已导入: \${selected.displayName}');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import from library', e, stackTrace);
      if (mounted) {
        AppToast.error(context, '导入失败: \$e');
      }
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

    final vibe = entry.toVibeReference();
    notifier.addVibeReferencesV4([vibe]);

    // 更新使用统计
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    await storageService.incrementUsedCount(entry.id);

    if (mounted) {
      AppToast.success(context, '已添加: \${entry.displayName}');
    }
  }
}

/// Vibe 卡片组件
class _VibeCard extends StatelessWidget {
  final int index;
  final VibeReferenceV4 vibe;
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRawImage = vibe.sourceType == VibeSourceType.rawImage;

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
          // 左侧：缩略图 + 删除按钮
          Column(
            children: [
              // 缩略图
              _buildThumbnail(theme),
              const SizedBox(height: 8),
              // 删除按钮
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
          const SizedBox(width: 12),

          // 右侧：滑条和源类型
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 源类型标签
                _buildSourceTypeChip(context, theme),
                const SizedBox(height: 8),

                // Reference Strength 滑条
                _buildSliderRow(
                  context,
                  theme,
                  label: context.l10n.vibe_referenceStrength,
                  value: vibe.strength,
                  onChanged: onStrengthChanged,
                ),

                // Information Extracted 滑条 (仅原始图片)
                if (isRawImage)
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
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 64,
        height: 64,
        color: theme.colorScheme.surfaceContainerHighest,
        child: vibe.thumbnail != null
            ? Image.memory(
                vibe.thumbnail!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(theme);
                },
              )
            : _buildPlaceholder(theme),
      ),
    );

    // 悬浮预览使用原始图片数据或缩略图
    final previewBytes = vibe.rawImageData ?? vibe.thumbnail;
    if (previewBytes != null) {
      return HoverImagePreview(
        imageBytes: previewBytes,
        child: thumbnail,
      );
    }
    return thumbnail;
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

  /// 构建源类型标签
  Widget _buildSourceTypeChip(BuildContext context, ThemeData theme) {
    final isPreEncoded = vibe.sourceType.isPreEncoded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPreEncoded
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPreEncoded
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPreEncoded ? Icons.check_circle_outline : Icons.warning_amber,
            size: 12,
            color: isPreEncoded ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            vibe.sourceType.displayLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isPreEncoded ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isPreEncoded) ...[
            const SizedBox(width: 4),
            Text(
              '(2 Anlas)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
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
                    entry.isPreEncoded
                        ? Icons.check_circle
                        : Icons.warning,
                    size: 8,
                    color: entry.isPreEncoded
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    entry.sourceType.displayLabel,
                    style: TextStyle(
                      fontSize: 8,
                      color: entry.isPreEncoded
                          ? Colors.green
                          : Colors.orange,
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
