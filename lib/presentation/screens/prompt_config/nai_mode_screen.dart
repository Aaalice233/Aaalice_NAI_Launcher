import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/category_filter_config.dart';
import '../../../data/models/prompt/random_prompt_result.dart';
import '../../../data/models/prompt/sync_config.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../../data/models/prompt/weighted_tag.dart';
import '../../providers/prompt_config_provider.dart';
import '../../providers/random_mode_provider.dart';
import '../../providers/tag_library_provider.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/themed_scaffold.dart';
import '../../widgets/prompt/nai_algorithm_dialog.dart';

/// NAI官方模式页面（只读）
///
/// 展示NAI算法使用的词库内容，不可编辑
/// 用户可以同步词库、查看算法说明、基于此创建自定义预设
class NaiModeScreen extends ConsumerStatefulWidget {
  const NaiModeScreen({super.key});

  @override
  ConsumerState<NaiModeScreen> createState() => _NaiModeScreenState();
}

class _NaiModeScreenState extends ConsumerState<NaiModeScreen> {
  // 记录展开状态
  final _expandedCategories = <TagSubCategory>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(tagLibraryNotifierProvider);

    return ThemedScaffold(
      appBar: AppBar(
        title: Text(context.l10n.naiMode_title),
        actions: [
          // 算法说明按钮
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: context.l10n.naiMode_algorithmInfo,
            onPressed: () => _showAlgorithmDialog(context),
          ),
          // 同步按钮
          IconButton(
            icon: libraryState.isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onSurface,
                    ),
                  )
                : const Icon(Icons.sync),
            tooltip: context.l10n.naiMode_syncLibrary,
            onPressed: libraryState.isSyncing ? null : _syncLibrary,
          ),
        ],
      ),
      body: Column(
        children: [
          // 信息卡片
          _buildInfoCard(context, theme, libraryState),

          // 类别列表
          Expanded(
            child: libraryState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCategoryList(context, theme, libraryState),
          ),

          // 底部操作区
          _buildBottomActions(context, theme),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    ThemeData theme,
    TagLibraryState state,
  ) {
    final library = state.library;
    // 根据分类级过滤配置显示过滤后的标签数量
    final tagCount = library?.getFilteredTagCountWithConfig(
      state.categoryFilterConfig,
    ) ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.3),
            theme.colorScheme.primaryContainer.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.l10n.naiMode_subtitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 标签总数
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            context.l10n.naiMode_tagCountBadge(tagCount.toString()),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.naiMode_readOnlyHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 同步进度
          if (state.isSyncing && state.syncProgress != null) ...[
            const SizedBox(height: 12),
            _buildSyncProgress(theme, state.syncProgress!),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncProgress(ThemeData theme, SyncProgress progress) {
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

  Widget _buildCategoryList(
    BuildContext context,
    ThemeData theme,
    TagLibraryState state,
  ) {
    final library = state.library;
    if (library == null) {
      return Center(
        child: Text(context.l10n.naiMode_noLibrary),
      );
    }

    // NAI算法使用的类别及其选择概率
    final categoryConfig = _getNaiCategoryConfig();
    final filterConfig = state.categoryFilterConfig;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categoryConfig.length,
      itemBuilder: (context, index) {
        final entry = categoryConfig.entries.elementAt(index);
        final category = entry.key;
        final probability = entry.value;
        // 使用分类级过滤配置
        final includeSupplement = filterConfig.isEnabled(category);
        final tags = library.getFilteredCategory(category, includeDanbooruSupplement: includeSupplement);

        return _buildCategoryTile(context, theme, category, probability, tags, filterConfig);
      },
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    ThemeData theme,
    TagSubCategory category,
    int probability,
    List<WeightedTag> tags,
    CategoryFilterConfig filterConfig,
  ) {
    final isExpanded = _expandedCategories.contains(category);
    final categoryName = TagSubCategoryHelper.getDisplayName(category);
    final isSupplementEnabled = filterConfig.isEnabled(category);

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
          // 标题行
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(category);
                } else {
                  _expandedCategories.add(category);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 类别图标
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

                  // 类别名称和标签数
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

                  // Danbooru 补充开关（在概率标签左边）
                  Tooltip(
                    message: context.l10n.naiMode_danbooruToggleTooltip,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.naiMode_danbooruSupplementLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSupplementEnabled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: isSupplementEnabled,
                            onChanged: (value) {
                              ref.read(tagLibraryNotifierProvider.notifier).setCategoryEnabled(category, value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 概率标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.l10n.naiMode_categoryProbability(probability.toString()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 展开箭头
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

          // 展开的标签列表
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildTagList(theme, tags, context.l10n.naiMode_noTags),
            crossFadeState:
                isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildTagList(
    ThemeData theme,
    List<WeightedTag> tags,
    String emptyText,
  ) {
    if (tags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          emptyText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    // 按权重排序
    final sortedTags = List<WeightedTag>.from(tags)
      ..sort((a, b) => b.weight.compareTo(a.weight));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: sortedTags.take(50).map((tag) {
          return _buildTagChip(theme, tag);
        }).toList(),
      ),
    );
  }

  Widget _buildTagChip(ThemeData theme, WeightedTag tag) {
    // 根据权重计算颜色深浅
    final intensity = (tag.weight / 20).clamp(0.3, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(intensity * 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag.tag,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(intensity * 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${tag.weight}',
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.primary.withOpacity(0.8 + intensity * 0.2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 预览生成按钮
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
            // 基于此创建自定义预设按钮
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
      ),
    );
  }

  /// NAI算法使用的类别及其选择概率
  Map<TagSubCategory, int> _getNaiCategoryConfig() {
    return {
      TagSubCategory.hairColor: 80,
      TagSubCategory.eyeColor: 80,
      TagSubCategory.hairStyle: 50,
      TagSubCategory.expression: 60,
      TagSubCategory.pose: 50,
      TagSubCategory.background: 90,
      TagSubCategory.scene: 50,
      TagSubCategory.style: 30,
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
      TagSubCategory.background => Icons.landscape,
      TagSubCategory.scene => Icons.photo_camera,
      TagSubCategory.style => Icons.brush,
      TagSubCategory.characterCount => Icons.group,
      _ => Icons.label,
    };
  }

  void _showAlgorithmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NaiAlgorithmDialog(),
    );
  }

  Future<void> _syncLibrary() async {
    final success = await ref.read(tagLibraryNotifierProvider.notifier).syncLibrary();
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
      // 切换到NAI模式
      ref.read(randomModeNotifierProvider.notifier).setMode(RandomGenerationMode.naiOfficial);

      // 生成预览
      final result = await ref
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(isV4Model: true);

      if (mounted) {
        // 显示预览对话框
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.naiMode_previewResult),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.prompt_positive,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(result.mainPrompt),
                  if (result.hasCharacters) ...[
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.naiMode_characterPrompts,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
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
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
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
                onPressed: () => Navigator.pop(context),
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
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.naiMode_createCustomTitle),
        content: Text(context.l10n.naiMode_createCustomDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _doCreateCustomPreset();
            },
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );
  }

  void _doCreateCustomPreset() {
    // TODO: 导航到预设编辑器，并预填充NAI类别
    AppToast.info(context, context.l10n.naiMode_featureComingSoon);
  }
}
