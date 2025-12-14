import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/prompt_config.dart';
import '../../../data/models/prompt/random_prompt_result.dart';
import '../../../data/models/prompt/sync_config.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../../data/models/prompt/weighted_tag.dart';
import '../../providers/prompt_config_provider.dart';
import '../../providers/random_mode_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/prompt/nai_algorithm_dialog.dart';

/// 随机提示词配置页面 - 分栏布局
class PromptConfigScreen extends ConsumerStatefulWidget {
  const PromptConfigScreen({super.key});

  @override
  ConsumerState<PromptConfigScreen> createState() => _PromptConfigScreenState();
}

class _PromptConfigScreenState extends ConsumerState<PromptConfigScreen> {
  String? _selectedPresetId;
  String? _selectedConfigId;
  bool _hasUnsavedChanges = false;

  // 编辑状态
  late TextEditingController _presetNameController;
  List<PromptConfig> _editingConfigs = [];

  @override
  void initState() {
    super.initState();
    _presetNameController = TextEditingController();
  }

  @override
  void dispose() {
    _presetNameController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(promptConfigNotifierProvider);
    final theme = Theme.of(context);
    final currentMode = ref.watch(randomModeNotifierProvider);

    // 初始化选中状态（仅在自定义模式下）
    if (currentMode == RandomGenerationMode.custom &&
        _selectedPresetId == null &&
        state.presets.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectPreset(state.selectedPresetId ?? state.presets.first.id);
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // 左侧预设列表
          _buildPresetPanel(state, theme),
          // 垂直分割线
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          // NAI 模式：显示算法说明；自定义模式：显示配置组列表和详情
          if (currentMode == RandomGenerationMode.naiOfficial)
            Expanded(child: _buildNaiDetailPanel(theme))
          else ...[
            // 中间配置组列表
            _buildConfigPanel(state, theme),
            // 垂直分割线
            VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
            // 右侧详情编辑
            _buildDetailPanel(state, theme),
          ],
        ],
      ),
    );
  }

  /// NAI 模式详情面板 - 直接展示完整内容
  Widget _buildNaiDetailPanel(ThemeData theme) {
    final libraryState = ref.watch(tagLibraryNotifierProvider);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 信息卡片（包含操作按钮）
          _buildNaiInfoCard(theme, libraryState),

          // 类别列表
          Expanded(
            child: libraryState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildNaiCategoryList(theme, libraryState),
          ),

          // 底部操作区
          _buildNaiBottomActions(theme),
        ],
      ),
    );
  }

  /// NAI 模式头部区域
  Widget _buildNaiInfoCard(ThemeData theme, TagLibraryState state) {
    final library = state.library;
    final config = state.syncConfig;
    // 根据分类级过滤配置显示过滤后的标签数量
    final tagCount = library?.getFilteredTagCountWithConfig(
      state.categoryFilterConfig,
    ) ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题与操作按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：标题信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.naiMode_subtitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.naiMode_readOnlyHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧：操作按钮
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _showAlgorithmDialog,
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: Text(context.l10n.naiMode_algorithmInfo),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: state.isSyncing ? null : _showSyncSettingsDialog,
                    icon: state.isSyncing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(
                      state.isSyncing
                          ? context.l10n.tagLibrary_syncing
                          : context.l10n.naiMode_syncLibrary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 统计数据卡片
          Row(
            children: [
              _buildStatCard(
                theme,
                value: tagCount.toString(),
                label: context.l10n.naiMode_statTags,
                icon: Icons.label_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                theme,
                value: _getDataRangeText(config.dataRange),
                label: context.l10n.naiMode_statRange,
                icon: Icons.data_usage,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                theme,
                value: _formatLastSync(config.lastSyncTime),
                label: context.l10n.naiMode_statSync,
                icon: Icons.schedule,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),

          // 同步进度
          if (state.isSyncing && state.syncProgress != null) ...[
            const SizedBox(height: 16),
            _buildNaiSyncProgress(theme, state.syncProgress!),
          ],
        ],
      ),
    );
  }

  /// 显示同步设置对话框
  void _showSyncSettingsDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(tagLibraryNotifierProvider);

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.sync, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(context.l10n.naiMode_syncLibrary),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 数据范围
                    Text(
                      context.l10n.tagLibrary_dataRange,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: DataRange.values.map((range) {
                        final selected = state.syncConfig.dataRange == range;
                        final label = switch (range) {
                          DataRange.popular =>
                            context.l10n.tagLibrary_dataRangePopular,
                          DataRange.medium =>
                            context.l10n.tagLibrary_dataRangeMedium,
                          DataRange.full =>
                            context.l10n.tagLibrary_dataRangeFull,
                        };
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (value) {
                            if (value) {
                              ref
                                  .read(tagLibraryNotifierProvider.notifier)
                                  .setDataRange(range);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.tagLibrary_dataRangeHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 词库组成说明
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.tagLibrary_libraryComposition,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.l10n.tagLibrary_libraryCompositionDesc,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.l10n.common_cancel),
                ),
                FilledButton.icon(
                  onPressed: state.isSyncing
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _syncLibrary();
                        },
                  icon: const Icon(Icons.sync, size: 18),
                  label: Text(context.l10n.tagLibrary_syncNow),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 统计数据卡片
  Widget _buildStatCard(
    ThemeData theme, {
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNaiSyncProgress(ThemeData theme, SyncProgress progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                progress.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        if (progress.totalEstimate > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ],
    );
  }

  /// NAI 类别列表
  Widget _buildNaiCategoryList(ThemeData theme, TagLibraryState state) {
    final library = state.library;
    if (library == null) {
      return Center(child: Text(context.l10n.naiMode_noLibrary));
    }

    final categoryConfig = _getNaiCategoryConfig();
    final allCategories = categoryConfig.keys.toSet();
    final allExpanded = _expandedNaiCategories.containsAll(allCategories);
    final filterConfig = state.categoryFilterConfig;

    return Column(
      children: [
        // 展开/收起全部按钮和总开关
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Spacer(),
              // 全局 Danbooru 补充开关
              Tooltip(
                message: context.l10n.naiMode_danbooruMasterToggleTooltip,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.naiMode_danbooruSupplementLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: filterConfig.anyEnabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: filterConfig.anyEnabled,
                        onChanged: (value) {
                          ref.read(tagLibraryNotifierProvider.notifier).setAllCategoriesEnabled(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (allExpanded) {
                      _expandedNaiCategories.clear();
                    } else {
                      _expandedNaiCategories.addAll(allCategories);
                    }
                  });
                },
                icon: Icon(
                  allExpanded ? Icons.unfold_less : Icons.unfold_more,
                  size: 18,
                ),
                label: Text(
                  allExpanded
                      ? context.l10n.common_collapseAll
                      : context.l10n.common_expandAll,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        // 类别列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categoryConfig.length,
            itemBuilder: (context, index) {
              final entry = categoryConfig.entries.elementAt(index);
              final category = entry.key;
              final probability = entry.value;
              // 使用分类级过滤配置
              final includeSupplement = filterConfig.isEnabled(category);
              final tags = library.getFilteredCategory(
                category,
                includeDanbooruSupplement: includeSupplement,
              );

              return _buildNaiCategoryTile(theme, category, probability, tags);
            },
          ),
        ),
      ],
    );
  }

  /// 有 Danbooru 补充的分类（只有这些分类显示开关）
  static const _categoriesWithDanbooruSupplement = {
    TagSubCategory.hairColor,
    TagSubCategory.eyeColor,
    TagSubCategory.hairStyle,
    TagSubCategory.background,
  };

  Widget _buildNaiCategoryTile(
    ThemeData theme,
    TagSubCategory category,
    int probability,
    List<WeightedTag> tags,
  ) {
    final isExpanded = _expandedNaiCategories.contains(category);
    final hasDanbooruSupplement = _categoriesWithDanbooruSupplement.contains(category);
    final categoryName = TagSubCategoryHelper.getDisplayName(category);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedNaiCategories.remove(category);
                } else {
                  _expandedNaiCategories.add(category);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(category),
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.naiMode_tagCount(tags.length.toString()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Danbooru 补充开关（仅对有补充的分类显示）
                  if (hasDanbooruSupplement)
                    Tooltip(
                      message: context.l10n.naiMode_danbooruToggleTooltip,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.naiMode_danbooruSupplementLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: ref.watch(tagLibraryNotifierProvider).categoryFilterConfig.isEnabled(category)
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: ref.watch(tagLibraryNotifierProvider).categoryFilterConfig.isEnabled(category),
                              onChanged: (value) {
                                ref.read(tagLibraryNotifierProvider.notifier).setCategoryEnabled(category, value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.l10n.naiMode_categoryProbability(
                        probability.toString(),
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isExpanded
                ? _buildNaiTagList(theme, tags)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildNaiTagList(ThemeData theme, List<WeightedTag> tags) {
    if (tags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.naiMode_noTags,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    final sortedTags = List<WeightedTag>.from(tags)
      ..sort((a, b) => b.weight.compareTo(a.weight));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: sortedTags.map((tag) {
          return _buildNaiTagChip(theme, tag);
        }).toList(),
      ),
    );
  }

  Widget _buildNaiTagChip(ThemeData theme, WeightedTag tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Text(
        tag.tag,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  /// NAI 底部操作区
  Widget _buildNaiBottomActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _previewGenerate,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(context.l10n.naiMode_preview),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _createCustomPreset,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.naiMode_createCustom),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NAI 模式辅助方法
  final _expandedNaiCategories = <TagSubCategory>{};

  /// NAI 官方类别及其选中概率配置
  /// 参考: docs/NAI随机提示词功能分析.md
  Map<TagSubCategory, int> _getNaiCategoryConfig() {
    return {
      // 角色特征类（概率约50%）
      TagSubCategory.hairColor: 50,
      TagSubCategory.eyeColor: 50,
      TagSubCategory.hairStyle: 50,
      TagSubCategory.expression: 50,
      TagSubCategory.pose: 50,
      TagSubCategory.clothing: 50,
      TagSubCategory.accessory: 50,
      TagSubCategory.bodyFeature: 30,
      // 场景/画风类
      TagSubCategory.background: 90,
      TagSubCategory.scene: 50,
      TagSubCategory.style: 30,
      // 人数（由算法决定，显示供参考）
      TagSubCategory.characterCount: 100,
    };
  }

  IconData _getCategoryIcon(TagSubCategory category) {
    return switch (category) {
      TagSubCategory.hairColor => Icons.palette,
      TagSubCategory.eyeColor => Icons.remove_red_eye,
      TagSubCategory.hairStyle => Icons.face,
      TagSubCategory.expression => Icons.emoji_emotions,
      TagSubCategory.pose => Icons.accessibility_new,
      TagSubCategory.clothing => Icons.checkroom,
      TagSubCategory.accessory => Icons.watch,
      TagSubCategory.bodyFeature => Icons.accessibility,
      TagSubCategory.background => Icons.landscape,
      TagSubCategory.scene => Icons.photo_camera,
      TagSubCategory.style => Icons.brush,
      TagSubCategory.characterCount => Icons.group,
      _ => Icons.label,
    };
  }

  String _getDataRangeText(DataRange range) {
    return switch (range) {
      DataRange.popular => context.l10n.tagLibrary_rangePopular,
      DataRange.medium => context.l10n.tagLibrary_rangeMedium,
      DataRange.full => context.l10n.tagLibrary_rangeFull,
    };
  }

  String _formatLastSync(DateTime? time) {
    if (time == null) return context.l10n.tagLibrary_neverSynced;
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) {
      return context.l10n.tagLibrary_daysAgo(diff.inDays.toString());
    }
    if (diff.inHours > 0) {
      return context.l10n.tagLibrary_hoursAgo(diff.inHours.toString());
    }
    return context.l10n.tagLibrary_justNow;
  }

  void _showAlgorithmDialog() {
    showDialog(
      context: context,
      builder: (context) => const NaiAlgorithmDialog(),
    );
  }

  Future<void> _syncLibrary() async {
    final success =
        await ref.read(tagLibraryNotifierProvider.notifier).syncLibrary();
    if (mounted) {
      if (success) {
        AppToast.success(context, context.l10n.tagLibrary_syncSuccess);
      } else {
        AppToast.error(context, context.l10n.tagLibrary_syncFailed);
      }
    }
  }

  Future<void> _previewGenerate() async {
    try {
      final result = await ref
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(isV4Model: true);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.naiMode_previewResult),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.prompt_positive,
                    style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(result.mainPrompt),
                  if (result.hasCharacters) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.naiMode_characterPrompts,
                      style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    ...result.characters.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${context.l10n.naiMode_character} ${entry.key + 1}:',
                              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(ctx).colorScheme.outline,
                                  ),
                            ),
                            SelectableText(entry.value.prompt),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.common_close),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString());
      }
    }
  }

  void _createCustomPreset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.naiMode_createCustomTitle),
        content: Text(context.l10n.naiMode_createCustomDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppToast.info(context, context.l10n.naiMode_featureComingSoon);
            },
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );
  }

  // ==================== 左侧预设面板 ====================
  Widget _buildPresetPanel(PromptConfigState state, ThemeData theme) {
    final currentMode = ref.watch(randomModeNotifierProvider);
    final isNaiMode = currentMode == RandomGenerationMode.naiOfficial;

    return Container(
      width: 220,
      color: theme.colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Container(
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
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _buildPresetMenu(theme),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // 预设列表（包含固定的 NAI 官方模式）
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      // NAI 官方模式（固定项）
                      _buildNaiPresetItem(isNaiMode, theme),
                      // 分隔线
                      if (state.presets.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: theme.dividerColor,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  context.l10n.config_presets,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: theme.dividerColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // 自定义预设列表
                      ...state.presets.map(
                        (preset) => _buildPresetItem(preset, state, theme),
                      ),
                    ],
                  ),
          ),

          // 底部操作
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _createNewPreset,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.config_newPreset),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// NAI 官方模式预设项（固定）
  Widget _buildNaiPresetItem(bool isSelected, ThemeData theme) {
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    // 根据分类级过滤配置显示过滤后的标签数量
    final tagCount = libraryState.library?.getFilteredTagCountWithConfig(
      libraryState.categoryFilterConfig,
    ) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _selectNaiMode(),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 激活指示器
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                // 图标
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                // 预设信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.naiMode_title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : null,
                          color: theme.colorScheme.primary,
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 选择 NAI 官方模式
  void _selectNaiMode() {
    if (_hasUnsavedChanges) {
      _showUnsavedDialog(() => _doSelectNaiMode());
      return;
    }
    _doSelectNaiMode();
  }

  void _doSelectNaiMode() {
    ref.read(randomModeNotifierProvider.notifier).setMode(
          RandomGenerationMode.naiOfficial,
        );
    setState(() {
      _selectedPresetId = null;
      _selectedConfigId = null;
      _editingConfigs = [];
      _hasUnsavedChanges = false;
    });
  }

  Widget _buildPresetMenu(ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      tooltip: context.l10n.preset_moreActions,
      onSelected: _handlePresetMenuAction,
      itemBuilder: (menuContext) => [
        PopupMenuItem(
          value: 'import',
          child: Text(context.l10n.config_importConfig),
        ),
      ],
    );
  }

  Widget _buildPresetItem(
    RandomPromptPreset preset,
    PromptConfigState state,
    ThemeData theme,
  ) {
    final isSelected = preset.id == _selectedPresetId;
    final isActive = preset.id == state.selectedPresetId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _selectPreset(preset.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 激活指示器
                if (isActive)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                // 预设名称
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.l10n.preset_configGroupCount(
                          preset.configs.length.toString(),
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                // 右键菜单
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (action) =>
                      _handlePresetItemAction(preset, action),
                  itemBuilder: (menuContext) => [
                    PopupMenuItem(
                      value: 'activate',
                      enabled: !isActive,
                      child: Text(context.l10n.preset_setAsCurrent),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text(context.l10n.preset_duplicate),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Text(context.l10n.preset_export),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        context.l10n.preset_delete,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 中间配置组面板 ====================
  Widget _buildConfigPanel(PromptConfigState state, ThemeData theme) {
    final preset = _getSelectedPreset(state);

    return Container(
      width: 280,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.config_configGroups,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (preset != null)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: context.l10n.preset_addConfigGroup,
                    onPressed: _addConfig,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          // 预设名称编辑
          if (preset != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _presetNameController,
                decoration: InputDecoration(
                  labelText: context.l10n.preset_presetName,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: theme.textTheme.bodyMedium,
                onChanged: (_) => _markChanged(),
              ),
            ),
          // 配置组列表
          Expanded(
            child: preset == null
                ? Center(
                    child: Text(
                      context.l10n.preset_selectPreset,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                : _editingConfigs.isEmpty
                    ? _buildEmptyConfigs(theme)
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        buildDefaultDragHandles: false,
                        itemCount: _editingConfigs.length,
                        onReorder: _reorderConfig,
                        itemBuilder: (context, index) {
                          final config = _editingConfigs[index];
                          return _buildConfigItem(config, index, theme);
                        },
                      ),
          ),
          // 保存按钮
          if (_hasUnsavedChanges && preset != null) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _savePreset,
                icon: const Icon(Icons.save, size: 18),
                label: Text(context.l10n.config_saveChanges),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyConfigs(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            context.l10n.preset_noConfigGroups,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addConfig,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.preset_addConfigGroup),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(PromptConfig config, int index, ThemeData theme) {
    final isSelected = config.id == _selectedConfigId;

    return Padding(
      key: ValueKey(config.id),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _selectConfig(config.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 拖拽手柄
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(width: 8),
                // 启用开关
                SizedBox(
                  width: 36,
                  height: 20,
                  child: Switch(
                    value: config.enabled,
                    onChanged: (_) => _toggleConfigEnabled(index),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                // 配置信息
                Expanded(
                  child: Opacity(
                    opacity: config.enabled ? 1.0 : 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getConfigSummary(config),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // 删除按钮
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.error.withOpacity(0.7),
                  ),
                  onPressed: () => _deleteConfig(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: context.l10n.common_delete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 右侧详情面板 ====================
  Widget _buildDetailPanel(PromptConfigState state, ThemeData theme) {
    final config = _getSelectedConfig();

    return Expanded(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: config == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 64,
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.preset_selectConfigToEdit,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              )
            : _ConfigDetailEditor(
                key: ValueKey(config.id),
                config: config,
                onChanged: (updated) => _updateConfig(updated),
              ),
      ),
    );
  }

  // ==================== 辅助方法 ====================
  RandomPromptPreset? _getSelectedPreset(PromptConfigState state) {
    if (_selectedPresetId == null) return null;
    try {
      return state.presets.firstWhere((p) => p.id == _selectedPresetId);
    } catch (_) {
      return null;
    }
  }

  PromptConfig? _getSelectedConfig() {
    if (_selectedConfigId == null) return null;
    try {
      return _editingConfigs.firstWhere((c) => c.id == _selectedConfigId);
    } catch (_) {
      return null;
    }
  }

  void _selectPreset(String presetId) {
    if (_hasUnsavedChanges) {
      _showUnsavedDialog(() => _doSelectPreset(presetId));
      return;
    }
    _doSelectPreset(presetId);
  }

  void _doSelectPreset(String presetId) {
    final state = ref.read(promptConfigNotifierProvider);
    final preset = state.presets.firstWhere((p) => p.id == presetId);

    // 切换到自定义模式
    ref.read(randomModeNotifierProvider.notifier).setMode(
          RandomGenerationMode.custom,
        );

    setState(() {
      _selectedPresetId = presetId;
      _presetNameController.text = preset.name;
      _editingConfigs = List.from(preset.configs);
      // 默认选中第一个配置组
      _selectedConfigId =
          _editingConfigs.isNotEmpty ? _editingConfigs.first.id : null;
      _hasUnsavedChanges = false;
    });
  }

  void _selectConfig(String configId) {
    setState(() {
      _selectedConfigId = configId;
    });
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _createNewPreset() {
    if (_hasUnsavedChanges) {
      _showUnsavedDialog(_doCreateNewPreset);
      return;
    }
    _doCreateNewPreset();
  }

  void _doCreateNewPreset() async {
    final presetName = context.l10n.config_newPreset;
    final successMessage = context.l10n.preset_newPresetCreated;
    final newPreset = RandomPromptPreset.create(name: presetName);
    await ref.read(promptConfigNotifierProvider.notifier).addPreset(newPreset);
    _doSelectPreset(newPreset.id);
    if (mounted) {
      AppToast.success(context, successMessage);
    }
  }

  void _addConfig() {
    final newConfig =
        PromptConfig.create(name: context.l10n.presetEdit_newConfigGroup);
    setState(() {
      _editingConfigs.add(newConfig);
      _selectedConfigId = newConfig.id;
      _hasUnsavedChanges = true;
    });
  }

  void _deleteConfig(int index) {
    setState(() {
      final removed = _editingConfigs.removeAt(index);
      if (_selectedConfigId == removed.id) {
        _selectedConfigId = null;
      }
      _hasUnsavedChanges = true;
    });
  }

  void _toggleConfigEnabled(int index) {
    setState(() {
      _editingConfigs[index] = _editingConfigs[index].copyWith(
        enabled: !_editingConfigs[index].enabled,
      );
      _hasUnsavedChanges = true;
    });
  }

  void _reorderConfig(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _editingConfigs.removeAt(oldIndex);
      _editingConfigs.insert(newIndex, item);
      _hasUnsavedChanges = true;
    });
  }

  void _updateConfig(PromptConfig updated) {
    final index = _editingConfigs.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      setState(() {
        _editingConfigs[index] = updated;
        _hasUnsavedChanges = true;
      });
    }
  }

  void _savePreset() async {
    if (_selectedPresetId == null) return;

    final successMessage = context.l10n.preset_saveSuccess;
    final state = ref.read(promptConfigNotifierProvider);
    final preset = state.presets.firstWhere((p) => p.id == _selectedPresetId);
    final updated = preset.copyWith(
      name: _presetNameController.text.trim(),
      configs: _editingConfigs,
      updatedAt: DateTime.now(),
    );

    await ref.read(promptConfigNotifierProvider.notifier).updatePreset(updated);
    setState(() => _hasUnsavedChanges = false);
    if (mounted) {
      AppToast.success(context, successMessage);
    }
  }

  void _handlePresetMenuAction(String action) {
    switch (action) {
      case 'import':
        _showImportDialog();
        break;
    }
  }

  void _handlePresetItemAction(RandomPromptPreset preset, String action) {
    switch (action) {
      case 'activate':
        ref.read(promptConfigNotifierProvider.notifier).selectPreset(preset.id);
        AppToast.success(context, context.l10n.preset_setAsCurrentSuccess);
        break;
      case 'duplicate':
        ref
            .read(promptConfigNotifierProvider.notifier)
            .duplicatePreset(preset.id);
        AppToast.success(context, context.l10n.preset_duplicated);
        break;
      case 'export':
        final json = ref
            .read(promptConfigNotifierProvider.notifier)
            .exportPreset(preset.id);
        Clipboard.setData(ClipboardData(text: json));
        AppToast.success(context, context.l10n.preset_copiedToClipboard);
        break;
      case 'delete':
        _showDeletePresetDialog(preset);
        break;
    }
  }

  String _getConfigSummary(PromptConfig config) {
    final parts = <String>[];
    if (config.contentType == ContentType.string) {
      parts.add(
        context.l10n.preset_itemCount(config.stringContents.length.toString()),
      );
    } else {
      parts.add(
        context.l10n
            .preset_subConfigCount(config.nestedConfigs.length.toString()),
      );
    }
    parts.add(_getSelectionModeShort(config.selectionMode));
    return parts.join(' · ');
  }

  String _getSelectionModeShort(SelectionMode mode) {
    switch (mode) {
      case SelectionMode.singleRandom:
        return context.l10n.preset_random;
      case SelectionMode.singleSequential:
        return context.l10n.preset_sequential;
      case SelectionMode.singleProbability:
        return context.l10n.preset_probability;
      case SelectionMode.multipleCount:
        return context.l10n.preset_multiple;
      case SelectionMode.multipleProbability:
        return context.l10n.preset_probability;
      case SelectionMode.all:
        return context.l10n.preset_all;
    }
  }

  void _showUnsavedDialog(VoidCallback onDiscard) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.preset_unsavedChanges),
        content: Text(context.l10n.preset_unsavedChangesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _hasUnsavedChanges = false);
              onDiscard();
            },
            child: Text(context.l10n.preset_discard),
          ),
        ],
      ),
    );
  }

  void _showDeletePresetDialog(RandomPromptPreset preset) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.preset_deletePreset),
        content: Text(context.l10n.preset_deletePresetConfirm(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(promptConfigNotifierProvider.notifier)
                  .deletePreset(preset.id);
              if (_selectedPresetId == preset.id) {
                setState(() {
                  _selectedPresetId = null;
                  _selectedConfigId = null;
                  _editingConfigs = [];
                });
              }
              AppToast.success(context, context.l10n.preset_deleted);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    // 预先捕获本地化字符串，避免异步间隙问题
    final titleText = context.l10n.preset_importConfig;
    final hintText = context.l10n.preset_pasteJson;
    final cancelText = context.l10n.common_cancel;
    final importText = context.l10n.common_import;
    final successText = context.l10n.preset_importSuccess;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titleText),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(promptConfigNotifierProvider.notifier)
                    .importPreset(controller.text);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (mounted) {
                  AppToast.success(context, successText);
                }
              } catch (e) {
                if (mounted) {
                  AppToast.error(
                    context,
                    context.l10n.preset_importFailed(e.toString()),
                  );
                }
              }
            },
            child: Text(importText),
          ),
        ],
      ),
    );
  }
}

// ==================== 配置详情编辑器 ====================
class _ConfigDetailEditor extends StatefulWidget {
  final PromptConfig config;
  final ValueChanged<PromptConfig> onChanged;

  const _ConfigDetailEditor({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<_ConfigDetailEditor> createState() => _ConfigDetailEditorState();
}

class _ConfigDetailEditorState extends State<_ConfigDetailEditor> {
  late TextEditingController _nameController;
  late TextEditingController _contentsController;
  late SelectionMode _selectionMode;
  late int _selectCount;
  late double _selectProbability;
  late int _bracketMin;
  late int _bracketMax;
  late bool _shuffle;

  @override
  void initState() {
    super.initState();
    _initFromConfig();
  }

  @override
  void didUpdateWidget(_ConfigDetailEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.id != widget.config.id) {
      _initFromConfig();
    }
  }

  void _initFromConfig() {
    _nameController = TextEditingController(text: widget.config.name);
    _contentsController = TextEditingController(
      text: widget.config.stringContents.join('\n'),
    );
    _selectionMode = widget.config.selectionMode;
    _selectCount = widget.config.selectCount ?? 1;
    _selectProbability =
        (widget.config.selectProbability ?? 0.5).clamp(0.05, 1.0);
    _bracketMin = widget.config.bracketMin;
    _bracketMax = widget.config.bracketMax;
    _shuffle = widget.config.shuffle;
  }

  void _notifyChanged() {
    final stringContents = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    widget.onChanged(
      widget.config.copyWith(
        name: _nameController.text.trim(),
        selectionMode: _selectionMode,
        selectCount: _selectCount,
        selectProbability: _selectProbability,
        bracketMin: _bracketMin,
        bracketMax: _bracketMax,
        shuffle: _shuffle,
        stringContents: stringContents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(Icons.edit_note, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.configEditor_editConfigGroup,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 配置名称
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: context.l10n.configEditor_configName,
              prefixIcon: const Icon(Icons.label_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => _notifyChanged(),
          ),
          const SizedBox(height: 24),

          // 选取方式 - 使用卡片式单选
          _buildSectionTitle(theme, context.l10n.configEditor_selectionMode),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SelectionMode.values.map((mode) {
              final isSelected = _selectionMode == mode;
              return ChoiceChip(
                label: Text(_getSelectionModeName(mode)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectionMode = mode);
                    _notifyChanged();
                  }
                },
              );
            }).toList(),
          ),

          // 附加参数
          if (_selectionMode == SelectionMode.multipleCount) ...[
            const SizedBox(height: 16),
            _buildSliderRow(
              label: context.l10n.config_selectCount,
              value: _selectCount.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              displayValue: '$_selectCount',
              onChanged: (v) {
                setState(() => _selectCount = v.toInt());
                _notifyChanged();
              },
            ),
          ],
          if (_selectionMode == SelectionMode.singleProbability ||
              _selectionMode == SelectionMode.multipleProbability) ...[
            const SizedBox(height: 16),
            _buildSliderRow(
              label: context.l10n.config_selectProbability,
              value: _selectProbability,
              min: 0.05,
              max: 1.0,
              divisions: 19,
              displayValue: '${(_selectProbability * 100).toInt()}%',
              onChanged: (v) {
                setState(() => _selectProbability = v);
                _notifyChanged();
              },
            ),
          ],
          if (_selectionMode == SelectionMode.multipleProbability ||
              _selectionMode == SelectionMode.all) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text(context.l10n.configEditor_shuffleOrder),
              subtitle: Text(context.l10n.configEditor_shuffleOrderHint),
              value: _shuffle,
              onChanged: (v) {
                setState(() => _shuffle = v);
                _notifyChanged();
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 权重括号
          _buildSectionTitle(theme, context.l10n.configEditor_weightBrackets),
          const SizedBox(height: 8),
          Text(
            context.l10n.configEditor_weightBracketsHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSliderRow(
                  label: context.l10n.config_min,
                  value: _bracketMin.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  displayValue: '$_bracketMin',
                  onChanged: (v) {
                    setState(() {
                      _bracketMin = v.toInt();
                      if (_bracketMax < _bracketMin) _bracketMax = _bracketMin;
                    });
                    _notifyChanged();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSliderRow(
                  label: context.l10n.config_max,
                  value: _bracketMax.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  displayValue: '$_bracketMax',
                  onChanged: (v) {
                    setState(() {
                      _bracketMax = v.toInt();
                      if (_bracketMin > _bracketMax) _bracketMin = _bracketMax;
                    });
                    _notifyChanged();
                  },
                ),
              ),
            ],
          ),
          if (_bracketMin > 0 || _bracketMax > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.preview,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.config_preview(_getBracketPreview()),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 标签内容
          _buildSectionTitle(theme, context.l10n.config_tagContent),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                context.l10n.config_tagContentHint(
                  _contentsController.text
                      .split('\n')
                      .where((s) => s.trim().isNotEmpty)
                      .length,
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _formatContents,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: Text(context.l10n.config_format),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              TextButton.icon(
                onPressed: _sortContents,
                icon: const Icon(Icons.sort_by_alpha, size: 16),
                label: Text(context.l10n.config_sort),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentsController,
            maxLines: 15,
            minLines: 8,
            decoration: InputDecoration(
              hintText: context.l10n.config_inputTags,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            onChanged: (_) {
              setState(() {});
              _notifyChanged();
            },
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(displayValue, textAlign: TextAlign.end),
        ),
      ],
    );
  }

  String _getSelectionModeName(SelectionMode mode) {
    switch (mode) {
      case SelectionMode.singleRandom:
        return context.l10n.config_singleRandom;
      case SelectionMode.singleSequential:
        return context.l10n.config_singleSequential;
      case SelectionMode.singleProbability:
        return context.l10n.configEditor_singleProbability;
      case SelectionMode.multipleCount:
        return context.l10n.config_multipleCount;
      case SelectionMode.multipleProbability:
        return context.l10n.config_probability;
      case SelectionMode.all:
        return context.l10n.config_all;
    }
  }

  String _getBracketPreview() {
    final examples = <String>[];
    for (int i = _bracketMin; i <= _bracketMax; i++) {
      examples.add('${'{' * i}tag${'}' * i}');
    }
    return examples.join(context.l10n.configEditor_or);
  }

  void _formatContents() {
    final lines = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _contentsController.text = lines.join('\n');
    _notifyChanged();
  }

  void _sortContents() {
    final lines = _contentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();
    _contentsController.text = lines.join('\n');
    _notifyChanged();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentsController.dispose();
    super.dispose();
  }
}
