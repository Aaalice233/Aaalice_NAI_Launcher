import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/extensions/vibe_extensions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/services/vibe_file_storage_service.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../vibe_library/widgets/vibe_selector_dialog.dart';
import 'drag_target_wrapper.dart';
import 'recent_vibes_list.dart';
import 'vibe_card.dart';

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
        DragTargetWrapper(
          params: params,
          vibes: vibes,
          showBackground: showBackground,
          onRemoveVibe: _removeVibe,
          onUpdateStrength: _updateVibeStrength,
          onUpdateInfoExtracted: _updateVibeInfoExtracted,
          onClearAll: _clearAllVibes,
          onSaveToLibrary: _saveToLibrary,
          onImportFromLibrary: _importFromLibrary,
          vibeBundleSources: _vibeBundleSources,
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
          RecentVibesList(
            isCollapsed: _isRecentCollapsed,
            onToggleCollapsed: _toggleRecentCollapsed,
            entries: _recentEntries,
            onAddEntry: _addRecentVibe,
          ),
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
                    (bool confirmed, bool encode, bool autoSave)?>(
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
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    // 清理 bundle 来源记录
    if (index < vibes.length) {
      final vibeName = vibes[index].displayName;
      _vibeBundleSources.remove(vibeName);
    }

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
      final encodedVibes = <VibeReference>[];
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
        for (final vibe in extractedVibes) {
          _vibeBundleSources[vibe.displayName] = entry.displayName;
        }
        notifier.addVibeReferences(extractedVibes);

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
    notifier.addVibeReferences([vibe]);

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
}
