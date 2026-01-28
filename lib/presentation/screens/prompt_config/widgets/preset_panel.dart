import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_library_provider.dart';
import '../../../../core/services/tag_counting_service.dart';
import '../../../widgets/common/themed_divider.dart';

/// 预设面板组件
/// 左侧预设列表，支持NAI模式和自定义预设
class PresetPanel extends ConsumerWidget {
  final VoidCallback onNewPreset;
  final void Function(String presetId) onSelectPreset;
  final void Function(RandomPreset preset, Offset position)?
      onPresetContextMenu;

  const PresetPanel({
    super.key,
    required this.onNewPreset,
    required this.onSelectPreset,
    this.onPresetContextMenu,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final presetState = ref.watch(randomPresetNotifierProvider);
    final presets = presetState.presets;

    return Container(
      width: 220,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          _buildHeader(context, theme),
          const ThemedDivider(height: 1),

          // 预设列表
          Expanded(
            child: presetState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      // 预设列表
                      ...presets.map(
                        (preset) => PresetListItem(
                          preset: preset,
                          isSelected: preset.id == presetState.selectedPresetId,
                          onTap: () => onSelectPreset(preset.id),
                          onContextMenu: onPresetContextMenu != null
                              ? (offset) => onPresetContextMenu!(preset, offset)
                              : null,
                        ),
                      ),
                      // 新建预设按钮
                      _buildNewPresetButton(context, theme),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.shuffle,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.config_title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPresetButton(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: OutlinedButton.icon(
        onPressed: onNewPreset,
        icon: const Icon(Icons.add, size: 18),
        label: Text(context.l10n.config_newPreset),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// 预设列表项组件
class PresetListItem extends ConsumerWidget {
  final RandomPreset preset;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(Offset position)? onContextMenu;

  const PresetListItem({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
    this.onContextMenu,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final tagCountingService = ref.watch(tagCountingServiceProvider);

    // 计算标签数
    final tagGroupMappings = preset.tagGroupMappings;
    final categories = preset.categories;
    final builtinTagCount = _calculateBuiltinTagCount(
      libraryState.library,
      categories,
      libraryState.categoryFilterConfig,
    );
    final syncTagCount = tagCountingService.calculateTotalTagCount(
      tagGroupMappings,
      categories,
    );
    final totalTagCount = builtinTagCount + syncTagCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: GestureDetector(
        onSecondaryTapDown: onContextMenu != null
            ? (details) => onContextMenu!(details.globalPosition)
            : null,
        child: Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // 激活指示器
                  _buildActiveIndicator(theme),
                  // 图标
                  _buildIcon(theme),
                  const SizedBox(width: 8),
                  // 预设信息
                  Expanded(
                    child: _buildPresetInfo(context, theme, totalTagCount),
                  ),
                  // 默认预设标识
                  if (preset.isDefault) _buildDefaultBadge(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveIndicator(ThemeData theme) {
    if (isSelected) {
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
      );
    }
    return const SizedBox(width: 16);
  }

  Widget _buildIcon(ThemeData theme) {
    return Icon(
      preset.isDefault ? Icons.auto_awesome : Icons.tune,
      size: 18,
      color: preset.isDefault
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
    );
  }

  Widget _buildPresetInfo(BuildContext context, ThemeData theme, int tagCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preset.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : null,
            color: preset.isDefault
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          context.l10n.naiMode_totalTags(tagCount.toString()),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '默认',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontSize: 10,
        ),
      ),
    );
  }

  /// 计算内置标签数
  int _calculateBuiltinTagCount(
    dynamic library,
    List<dynamic> categories,
    dynamic filterConfig,
  ) {
    if (library == null) return 0;

    int count = 0;
    try {
      // 遍历启用的类别
      for (final category in categories) {
        if (!category.enabled) continue;

        // 检查是否为内置类别
        final subCategory = category.subCategory;
        if (subCategory == null) continue;

        // 获取该类别的标签组
        final categoryData = library.categories[subCategory];
        if (categoryData == null) continue;

        // 检查过滤器是否启用该类别
        if (filterConfig != null) {
          final isEnabled = filterConfig.isBuiltinEnabled(subCategory);
          if (!isEnabled) continue;
        }

        // 累加标签数
        for (final group in categoryData.groups) {
          count += (group.tags.length as int);
        }
      }
    } catch (e) {
      // 忽略计算错误
    }

    return count;
  }
}
