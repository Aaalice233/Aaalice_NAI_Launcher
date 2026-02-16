import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/themed_divider.dart';
import 'drag_target_wrapper.dart';
import 'recent_vibes_list.dart';

/// Vibe Transfer 参考面板 - V4 Vibe Transfer（最多16张、预编码、编码成本显示）
///
/// 支持功能：
/// - V4 Vibe Transfer（16张、预编码、编码成本显示）
/// - Normalize 强度标准化开关
/// - 保存到库 / 从库导入
/// - 最近使用的 Vibes
/// - 源类型图标显示
class UnifiedReferencePanel extends ConsumerWidget {
  const UnifiedReferencePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final panelState = ref.watch(referencePanelNotifierProvider);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);
    final vibes = params.vibeReferencesV4;
    final hasVibes = vibes.isNotEmpty;

    // 判断是否显示背景（折叠且有数据时显示）
    final showBackground = hasVibes && !panelState.isExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.vibe_title,
      icon: Icons.auto_fix_high,
      isExpanded: panelState.isExpanded,
      onToggle: panelNotifier.toggleExpanded,
      hasData: hasVibes,
      backgroundImage: _buildBackgroundImage(vibes),
      badge: _buildCountBadge(context, theme, vibes, showBackground),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),
            // 说明文字
            _buildDescription(context, theme, showBackground),
            const SizedBox(height: 12),

            // Normalize 复选框
            _buildNormalizeOption(context, ref, params, showBackground),
            const SizedBox(height: 12),

            // Vibe 列表或空状态（包裹 DragTarget 支持拖拽）
            DragTargetWrapper(
              params: params,
              vibes: vibes,
              showBackground: showBackground,
            ),

            // 添加按钮（有数据时显示）
            if (hasVibes && vibes.length < 16)
              _buildAddButton(context, ref, showBackground),

            // 最近使用的 Vibes
            if (panelState.recentEntries.isNotEmpty && vibes.length < 16) ...[
              const SizedBox(height: 16),
              RecentVibesList(
                isCollapsed: panelState.isRecentCollapsed,
                onToggleCollapsed: panelNotifier.toggleRecentCollapsed,
                entries: panelState.recentEntries,
              ),
            ],

            // 清除全部按钮
            if (hasVibes) ...[
              const SizedBox(height: 8),
              _buildClearButton(context, ref, theme, showBackground),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建计数徽章
  Widget _buildCountBadge(
    BuildContext context,
    ThemeData theme,
    List<VibeReference> vibes,
    bool showBackground,
  ) {
    return Container(
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
        '${vibes.length}/16',
        style: theme.textTheme.labelSmall?.copyWith(
          color: showBackground
              ? Colors.white
              : theme.colorScheme.onPrimaryContainer,
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

  /// 构建说明文字
  Widget _buildDescription(
    BuildContext context,
    ThemeData theme,
    bool showBackground,
  ) {
    return Text(
      context.l10n.vibe_description,
      style: theme.textTheme.bodySmall?.copyWith(
        color: showBackground
            ? Colors.white70
            : theme.colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }

  /// 构建 Normalize 选项
  Widget _buildNormalizeOption(
    BuildContext context,
    WidgetRef ref,
    dynamic params,
    bool showBackground,
  ) {
    final theme = Theme.of(context);

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

  /// 构建添加按钮
  Widget _buildAddButton(BuildContext context, WidgetRef ref, bool showBackground) {
    return OutlinedButton.icon(
      onPressed: () => DragTargetWrapper.addVibeFromFile(context, ref),
      icon: const Icon(Icons.add, size: 18),
      label: Text(context.l10n.vibe_addReference),
      style: showBackground
          ? OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            )
          : null,
    );
  }

  /// 构建清除按钮
  Widget _buildClearButton(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool showBackground,
  ) {
    return TextButton.icon(
      onPressed: () => _clearAllVibes(context, ref),
      icon: const Icon(Icons.clear_all, size: 18),
      label: Text(context.l10n.vibe_clearAll),
      style: TextButton.styleFrom(
        foregroundColor:
            showBackground ? Colors.red[300] : theme.colorScheme.error,
      ),
    );
  }

  void _clearAllVibes(BuildContext context, WidgetRef ref) {
    final params = ref.read(generationParamsNotifierProvider);
    final count = params.vibeReferencesV4.length;

    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    notifier.clearVibeReferences();
    notifier.saveGenerationState();

    // 清空 bundle 来源记录
    panelNotifier.clearBundleSources();

    if (context.mounted && count > 0) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('已删除 $count 个 Vibe')),
      );
    }
  }
}
