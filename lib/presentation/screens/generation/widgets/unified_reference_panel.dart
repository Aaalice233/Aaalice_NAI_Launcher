import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/vibe_library_extensions.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import 'vibe_transfer_content.dart';
import '../handlers/vibe_import_handler.dart';
import '../handlers/vibe_export_handler.dart';

/// Vibe Transfer 参考面板 - V4 Vibe Transfer（最多16张、预编码、编码成本显示）
///
/// 支持功能：
/// - V4 Vibe Transfer（16张、预编码、编码成本显示）
/// - Normalize 强度标准化开关
/// - 保存到库 / 从库导入
/// - 最近使用的 Vibes
/// - 源类型图标显示
///
/// 此面板现在是一个轻量级容器，使用提取的组件：
/// - [VibeTransferContent] - 主内容区域
/// - [VibeCard] - 单个 Vibe 卡片
/// - [RecentVibesSection] - 最近使用的 Vibes
/// - [VibeImportHandler] - 导入/保存逻辑
/// - [VibeExportHandler] - 导出逻辑
class UnifiedReferencePanel extends ConsumerStatefulWidget {
  const UnifiedReferencePanel({super.key});

  @override
  ConsumerState<UnifiedReferencePanel> createState() =>
      _UnifiedReferencePanelState();
}

class _UnifiedReferencePanelState extends ConsumerState<UnifiedReferencePanel> {
  bool _isExpanded = false;
  bool _isRecentCollapsed = true;
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
          _isRecentCollapsed = collapsed ?? true;
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
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      final notifier = ref.read(generationParamsNotifierProvider.notifier);
      await notifier.restoreGenerationState();
    }
  }

  /// 加载最近使用的条目
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

  /// 添加 Vibe（从文件）
  Future<void> _addVibe() async {
    final handler = VibeImportHandler(ref: ref, context: context);
    await handler.importFromFiles();
    await _loadRecentEntries();
  }

  /// 从库导入 Vibes
  Future<void> _importFromLibrary() async {
    final handler = VibeImportHandler(ref: ref, context: context);
    await handler.importFromLibrary();
    await _loadRecentEntries();
  }

  /// 从库条目添加 Vibe（用于拖拽和最近使用）
  Future<void> _addLibraryVibe(VibeLibraryEntry entry) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final vibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;

    // 检查是否超过 16 个限制
    if (vibes.length >= 16) {
      if (mounted) {
        AppToast.warning(context, 'Maximum 16 vibes reached');
      }
      return;
    }

    // 如果是 bundle，使用 handler 的特殊处理
    if (entry.isBundle) {
      final handler = VibeImportHandler(ref: ref, context: context);
      await handler.importFromLibrary();
      return;
    }

    // 添加 Vibe 到生成参数
    final vibe = entry.toVibeReference();
    notifier.addVibeReferences([vibe]);

    // 更新使用统计
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    await storageService.incrementUsedCount(entry.id);

    if (mounted) {
      AppToast.success(context, 'Added ${entry.displayName}');
    }
  }

  /// 移除 Vibe
  void _removeVibe(int index) {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    notifier.removeVibeReference(index);
    notifier.saveGenerationState();
  }

  /// 更新 Vibe 强度
  void _updateVibeStrength(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, strength: value);
  }

  /// 更新 Vibe 信息提取
  void _updateVibeInfoExtracted(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, infoExtracted: value);
  }

  /// 更新 Vibe 编码
  void _updateVibeEncoding(int index, {required String vibeEncoding}) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, vibeEncoding: vibeEncoding);
  }

  /// 编码 Vibe（供 VibeCard 使用）
  Future<String?> _encodeVibe(
    Uint8List imageData, {
    required double informationExtracted,
    required String vibeName,
  }) async {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final model = ref.read(generationParamsNotifierProvider).model;

    return await notifier.encodeVibeWithCache(
      imageData,
      model: model,
      informationExtracted: informationExtracted,
      vibeName: vibeName,
    );
  }

  /// 清除全部 Vibes
  void _clearAllVibes() {
    final params = ref.read(generationParamsNotifierProvider);
    final count = params.vibeReferencesV4.length;

    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    notifier.clearVibeReferences();
    notifier.saveGenerationState();

    if (mounted && count > 0) {
      AppToast.success(context, 'Cleared $count vibes');
    }
  }

  /// 保存到库
  Future<void> _saveToLibrary() async {
    final params = ref.read(generationParamsNotifierProvider);
    final vibes = params.vibeReferencesV4;

    final handler = VibeImportHandler(ref: ref, context: context);
    await handler.saveToLibrary(vibes);
    await _loadRecentEntries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final vibes = params.vibeReferencesV4;
    final hasVibes = vibes.isNotEmpty;
    final showBackground = hasVibes && !_isExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.vibe_title,
      icon: Icons.auto_fix_high,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      hasData: hasVibes,
      backgroundImage: _buildBackgroundImage(vibes),
      headerActions: hasVibes
          ? [
              VibeExportHandler(ref: ref, context: context)
                  .buildExportButton(vibes),
            ]
          : null,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            VibeTransferContent(
              vibes: vibes,
              params: params,
              showBackground: showBackground,
              onAddVibe: _addVibe,
              onAddLibraryVibe: _addLibraryVibe,
              onRemoveVibe: _removeVibe,
              onUpdateStrength: _updateVibeStrength,
              onUpdateInfoExtracted: _updateVibeInfoExtracted,
              onUpdateEncoding: _updateVibeEncoding,
              onClearAll: _clearAllVibes,
              onSaveToLibrary: _saveToLibrary,
              onImportFromLibrary: _importFromLibrary,
              onEncode: _encodeVibe,
              recentEntries: _recentEntries,
              isRecentCollapsed: _isRecentCollapsed,
              onToggleRecentCollapsed: _toggleRecentCollapsed,
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
      final imageData = vibes.first.rawImageData ?? vibes.first.thumbnail;
      if (imageData != null) {
        return Image.memory(imageData, fit: BoxFit.cover);
      }
    } else {
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
}
