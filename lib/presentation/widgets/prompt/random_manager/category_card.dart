import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/random_preset_provider.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/tag_scope.dart';
import '../../common/elevated_card.dart';
import 'tag_group_card.dart';
import 'random_manager_widgets.dart';

/// 类别卡片组件
///
/// 显示类别信息，支持展开/收起内部的词组卡片
/// 采用 Dimensional Layering 风格设计
class CategoryCard extends ConsumerStatefulWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.presetId,
    this.onEdit,
  });

  final RandomCategory category;
  final String presetId;
  final VoidCallback? onEdit;

  @override
  ConsumerState<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends ConsumerState<CategoryCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final category = widget.category;

    return ElevatedCard(
      elevation: _isExpanded ? CardElevation.level2 : CardElevation.level1,
      hoverElevation: CardElevation.level2,
      enableHoverEffect: true,
      hoverTranslateY: -3,
      borderRadius: 8,
      gradientBorder: _isExpanded
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.6),
                colorScheme.secondary.withOpacity(0.4),
              ],
            )
          : null,
      gradientBorderWidth: 1.5,
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片头部
          _buildHeader(context, category),
          // 展开的内容
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(context, category),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RandomCategory category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：emoji + 名称 + 作用域标识
          Row(
            children: [
              // Emoji
              if (category.emoji.isNotEmpty)
                Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              if (category.emoji.isNotEmpty) const SizedBox(width: 8),
              // 名称
              Expanded(
                child: Text(
                  category.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 作用域标识
              _ScopeTag(scope: category.scope),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：概率 + 词组数量
          Row(
            children: [
              // 概率进度条
              Expanded(
                child: ProbabilityBar(
                  probability: category.probability,
                  enabled: category.enabled,
                ),
              ),
              const SizedBox(width: 12),
              // 词组数量
              Text(
                '${category.groupCount} 个词组',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              // 展开/收起图标
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context, RandomCategory category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 属性编辑区
              _buildPropertyEditor(context, category),
              const SizedBox(height: 12),
              // 词组列表标题
              Row(
                children: [
                  Text(
                    '词组列表',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // 添加词组按钮
                  TextButton.icon(
                    onPressed: () => _addTagGroup(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 词组卡片网格
              if (category.groups.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 32,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '暂无词组',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: category.groups.map((group) {
                    return TagGroupCard(
                      tagGroup: group,
                      categoryId: category.id,
                      presetId: widget.presetId,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyEditor(BuildContext context, RandomCategory category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // 作用域选择
          Row(
            children: [
              Text(
                '作用域:',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<TagScope>(
                  segments: const [
                    ButtonSegment(
                      value: TagScope.global,
                      label: Text('全局'),
                      icon: Icon(Icons.public, size: 16),
                    ),
                    ButtonSegment(
                      value: TagScope.character,
                      label: Text('角色'),
                      icon: Icon(Icons.person, size: 16),
                    ),
                    ButtonSegment(
                      value: TagScope.all,
                      label: Text('全部'),
                      icon: Icon(Icons.all_inclusive, size: 16),
                    ),
                  ],
                  selected: {category.scope},
                  onSelectionChanged: (set) {
                    _updateCategory(category.copyWith(scope: set.first));
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 概率滑块
          Row(
            children: [
              Text(
                '概率:',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: category.probability,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: '${(category.probability * 100).toInt()}%',
                  onChanged: (value) {
                    _updateCategory(category.copyWith(probability: value));
                  },
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${(category.probability * 100).toInt()}%',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 启用开关
          Row(
            children: [
              Text(
                '启用:',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Switch(
                value: category.enabled,
                onChanged: (value) {
                  _updateCategory(category.copyWith(enabled: value));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateCategory(RandomCategory updatedCategory) {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    notifier.updateCategory(updatedCategory);
  }

  void _addTagGroup(BuildContext context) {
    // TODO: 实现添加词组对话框
  }
}

/// 作用域标签组件
class _ScopeTag extends StatelessWidget {
  const _ScopeTag({required this.scope});

  final TagScope scope;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (scope) {
      TagScope.global => ('全局', Colors.blue, Icons.public),
      TagScope.character => ('角色', Colors.green, Icons.person),
      TagScope.all => ('全部', Colors.purple, Icons.all_inclusive),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 类别卡片垂直列表组件
///
/// 用于在仪表盘中显示所有类别卡片（垂直列表布局）
/// 采用 Dimensional Layering 风格设计
class CategoryCardList extends ConsumerWidget {
  const CategoryCardList({
    super.key,
    this.onAddCategory,
  });

  final VoidCallback? onAddCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;

    if (preset == null) {
      return const Center(child: Text('请选择一个预设'));
    }

    return ElevatedCard(
      elevation: CardElevation.level1,
      enableHoverEffect: false,
      borderRadius: 8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏 - 统一样式
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.15),
                      colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '类别配置',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 统计信息 - 类别数量、词组数量、标签数量
              _CategoryStats(
                categoryCount: preset.categoryCount,
                groupCount:
                    preset.categories.fold(0, (sum, c) => sum + c.groupCount),
                tagCount: preset.totalTagCount,
              ),
              const Spacer(),
              // 添加类别按钮
              _AddCategoryButton(onPressed: onAddCategory),
            ],
          ),
          const SizedBox(height: 16),
          // 类别卡片垂直列表
          if (preset.categories.isEmpty)
            _EmptyCategoryPlaceholder()
          else
            Expanded(
              child: ListView.separated(
                itemCount: preset.categories.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final category = preset.categories[index];
                  return CategoryCard(
                    category: category,
                    presetId: preset.id,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 类别卡片网格组件
///
/// 用于在仪表盘中显示所有类别卡片
/// 采用 Dimensional Layering 风格设计
class CategoryCardGrid extends ConsumerWidget {
  const CategoryCardGrid({
    super.key,
    this.onAddCategory,
  });

  final VoidCallback? onAddCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;

    if (preset == null) {
      return const Center(child: Text('请选择一个预设'));
    }

    return ElevatedCard(
      elevation: CardElevation.level1,
      enableHoverEffect: false,
      borderRadius: 8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏 - 统一样式
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.15),
                      colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '类别配置',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 统计信息 - 类别数量、词组数量、标签数量
              _CategoryStats(
                categoryCount: preset.categoryCount,
                groupCount:
                    preset.categories.fold(0, (sum, c) => sum + c.groupCount),
                tagCount: preset.totalTagCount,
              ),
              const Spacer(),
              // 添加类别按钮
              _AddCategoryButton(onPressed: onAddCategory),
            ],
          ),
          const SizedBox(height: 16),
          // 类别卡片网格 - 使用LayoutBuilder实现响应式布局
          if (preset.categories.isEmpty)
            _EmptyCategoryPlaceholder()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // 根据宽度计算每行卡片数量
                const minCardWidth = 260.0;
                const maxCardWidth = 320.0;
                const spacing = 12.0;

                final availableWidth = constraints.maxWidth;
                final cardsPerRow =
                    ((availableWidth + spacing) / (minCardWidth + spacing))
                        .floor()
                        .clamp(1, 4);
                final cardWidth =
                    (availableWidth - (cardsPerRow - 1) * spacing) /
                        cardsPerRow;
                final finalCardWidth =
                    cardWidth.clamp(minCardWidth, maxCardWidth);

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: preset.categories.map((category) {
                    return SizedBox(
                      width: finalCardWidth,
                      child: CategoryCard(
                        category: category,
                        presetId: preset.id,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// 添加类别按钮
class _AddCategoryButton extends StatefulWidget {
  const _AddCategoryButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_AddCategoryButton> createState() => _AddCategoryButtonState();
}

class _AddCategoryButtonState extends State<_AddCategoryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: _isHovered
                ? LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.15),
                      colorScheme.secondary.withOpacity(0.1),
                    ],
                  )
                : null,
            color: _isHovered ? null : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 16,
                color: _isHovered
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '新增类别',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _isHovered
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空类别占位符
class _EmptyCategoryPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 48,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无类别',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击"新增类别"开始配置',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 类别统计信息组件
class _CategoryStats extends StatelessWidget {
  const _CategoryStats({
    required this.categoryCount,
    required this.groupCount,
    required this.tagCount,
  });

  final int categoryCount;
  final int groupCount;
  final int tagCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatBadge(
          icon: Icons.category_outlined,
          label: '类别',
          value: '$categoryCount',
          color: colorScheme.primary,
        ),
        const SizedBox(width: 12),
        _StatBadge(
          icon: Icons.layers_outlined,
          label: '词组',
          value: '$groupCount',
          color: colorScheme.secondary,
        ),
        const SizedBox(width: 12),
        _StatBadge(
          icon: Icons.label_outlined,
          label: '标签',
          value: '$tagCount',
          color: colorScheme.tertiary,
        ),
      ],
    );
  }
}

/// 统计徽章组件
class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label:',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
