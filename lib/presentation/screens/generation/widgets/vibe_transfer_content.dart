import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import 'recent_vibes_section.dart';
import 'vibe_card.dart';

/// Vibe Transfer 内容组件
///
/// 显示 Vibe Transfer 的主要交互内容，包括：
/// - 说明文字
/// - Normalize 强度标准化开关
/// - Vibe 卡片列表（支持拖拽添加）
/// - 空状态（从文件/库添加）
/// - 添加按钮
/// - 最近使用的 Vibes
/// - 清除全部按钮
class VibeTransferContent extends ConsumerStatefulWidget {
  /// Vibe 引用列表
  final List<VibeReference> vibes;

  /// 生成参数
  final ImageParams params;

  /// 是否显示背景模式（折叠状态）
  final bool showBackground;

  /// 添加 Vibe 的回调
  final VoidCallback onAddVibe;

  /// 添加库 Vibe 的回调
  final Function(VibeLibraryEntry entry) onAddLibraryVibe;

  /// 移除 Vibe 的回调
  final Function(int index) onRemoveVibe;

  /// 更新 Vibe 强度的回调
  final Function(int index, double value) onUpdateStrength;

  /// 更新 Vibe 信息提取的回调
  final Function(int index, double value) onUpdateInfoExtracted;

  /// 更新 Vibe 编码的回调
  final Function(int index, {required String vibeEncoding})? onUpdateEncoding;

  /// 清除全部 Vibes 的回调
  final VoidCallback onClearAll;

  /// 保存到库的回调
  final VoidCallback? onSaveToLibrary;

  /// 从库导入的回调
  final VoidCallback? onImportFromLibrary;

  /// 编码 Vibe 的回调
  final Future<String?> Function(
    Uint8List imageData, {
    required double informationExtracted,
    required String vibeName,
  })? onEncode;

  /// 最近使用的条目
  final List<VibeLibraryEntry> recentEntries;

  /// 最近条目区域是否折叠
  final bool isRecentCollapsed;

  /// 切换最近条目折叠状态的回调
  final VoidCallback onToggleRecentCollapsed;

  const VibeTransferContent({
    super.key,
    required this.vibes,
    required this.params,
    required this.showBackground,
    required this.onAddVibe,
    required this.onAddLibraryVibe,
    required this.onRemoveVibe,
    required this.onUpdateStrength,
    required this.onUpdateInfoExtracted,
    this.onUpdateEncoding,
    required this.onClearAll,
    this.onSaveToLibrary,
    this.onImportFromLibrary,
    this.onEncode,
    required this.recentEntries,
    required this.isRecentCollapsed,
    required this.onToggleRecentCollapsed,
  });

  @override
  ConsumerState<VibeTransferContent> createState() =>
      _VibeTransferContentState();
}

class _VibeTransferContentState extends ConsumerState<VibeTransferContent> {
  bool _isDraggingOver = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibes = widget.vibes;
    final hasVibes = vibes.isNotEmpty;
    final showBackground = widget.showBackground;

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
        _buildNormalizeOption(context, theme, showBackground),
        const SizedBox(height: 12),

        // Vibe 列表或空状态（包裹 DragTarget 支持拖拽）
        _buildDragTargetWrapper(
          context,
          theme,
          hasVibes,
          vibes,
          showBackground,
        ),

        // 添加按钮（有数据时显示）
        if (hasVibes && vibes.length < 16)
          OutlinedButton.icon(
            onPressed: widget.onAddVibe,
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
        if (widget.recentEntries.isNotEmpty && vibes.length < 16) ...[
          const SizedBox(height: 16),
          RecentVibesSection(
            entries: widget.recentEntries,
            isCollapsed: widget.isRecentCollapsed,
            onToggleCollapse: widget.onToggleRecentCollapsed,
            onEntryTap: (entry) => widget.onAddLibraryVibe(entry),
          ),
        ],

        // 清除全部按钮
        if (hasVibes) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: widget.onClearAll,
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

  /// 构建 Normalize 选项
  Widget _buildNormalizeOption(
    BuildContext context,
    ThemeData theme,
    bool showBackground,
  ) {
    return Row(
      children: [
        Checkbox(
          value: widget.params.normalizeVibeStrength,
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
                  .setNormalizeVibeStrength(
                      !widget.params.normalizeVibeStrength,);
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

  /// 构建拖拽目标包装器
  Widget _buildDragTargetWrapper(
    BuildContext context,
    ThemeData theme,
    bool hasVibes,
    List<VibeReference> vibes,
    bool showBackground,
  ) {
    return DragTarget<VibeLibraryEntry>(
      onWillAcceptWithDetails: (details) {
        // 检查是否超过 16 个限制
        if (vibes.length >= 16) {
          AppToast.warning(context, '已达到最大数量 (16张)');
          return false;
        }
        setState(() => _isDraggingOver = true);
        return true;
      },
      onAcceptWithDetails: (details) async {
        HapticFeedback.heavyImpact();
        setState(() => _isDraggingOver = false);
        widget.onAddLibraryVibe(details.data);
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
                  return VibeCard(
                    key: ValueKey('${vibe.displayName}_$index'),
                    index: index,
                    vibe: vibe,
                    onRemove: () => widget.onRemoveVibe(index),
                    onStrengthChanged: (value) =>
                        widget.onUpdateStrength(index, value),
                    onInfoExtractedChanged: (value) =>
                        widget.onUpdateInfoExtracted(index, value),
                    onEncode: widget.onEncode,
                    onUpdateEncoding: widget.onUpdateEncoding,
                  );
                }),
                const SizedBox(height: 12),

                // 库操作按钮行
                _buildLibraryActions(context, theme, vibes),
                const SizedBox(height: 8),
              ] else ...[
                // 空状态
                _buildEmptyState(context, theme),
              ],
            ],
          ),
        );
      },
    );
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
            onPressed: vibes.isNotEmpty ? widget.onSaveToLibrary : null,
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
            onPressed: widget.onImportFromLibrary,
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
              onTap: widget.onAddVibe,
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
              onTap: () => widget.onImportFromLibrary?.call(),
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }
}

/// 空状态卡片组件 - 双按钮布局用
class _EmptyStateCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
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
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            child: Column(
              children: [
                AnimatedScale(
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
