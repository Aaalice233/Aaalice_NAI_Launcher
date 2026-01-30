import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/random_preset_provider.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/tag_scope.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../common/elevated_card.dart';
import '../../common/emoji_picker_dialog.dart';
import '../../common/hover_preview_card.dart';
import 'danbooru_preview_content.dart';
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
              Text(
                '词组列表',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 词组卡片网格
              if (category.groups.isEmpty)
                _AddTagGroupCard(
                  onTap: () => _addTagGroup(context),
                  isEmpty: true,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...category.groups.map((group) {
                      return TagGroupCard(
                        tagGroup: group,
                        categoryId: category.id,
                        presetId: widget.presetId,
                      );
                    }),
                    // 添加词组卡片
                    _AddTagGroupCard(onTap: () => _addTagGroup(context)),
                  ],
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
    showDialog(
      context: context,
      builder: (context) => _AddTagGroupDialog(
        category: widget.category,
        presetId: widget.presetId,
      ),
    );
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

/// 添加词组对话框
class _AddTagGroupDialog extends ConsumerStatefulWidget {
  const _AddTagGroupDialog({
    required this.category,
    required this.presetId,
  });

  final RandomCategory category;
  final String presetId;

  @override
  ConsumerState<_AddTagGroupDialog> createState() => _AddTagGroupDialogState();
}

class _AddTagGroupDialogState extends ConsumerState<_AddTagGroupDialog>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _tagsController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  String _selectedEmoji = '';
  int _sourceTabIndex = 0; // 0 = 自定义, 1 = Tag Group, 2 = Pool

  // Danbooru 导入相关
  String? _selectedDanbooruGroup;
  int? _selectedPoolId;
  String _searchQuery = '';

  // 预定义 Tag Groups
  static const _tagGroups = [
    ('Hair Color', 'tag_group:hair_color'),
    ('Eye Color', 'tag_group:eye_color'),
    ('Hairstyles', 'tag_group:hairstyles'),
    ('Hair Length', 'tag_group:hair_lengths'),
    ('Attire', 'tag_group:attire'),
    ('Expressions', 'tag_group:facial_expressions'),
    ('Posture', 'tag_group:posture'),
    ('Gestures', 'tag_group:gestures'),
    ('Accessories', 'tag_group:accessories'),
    ('Backgrounds', 'tag_group:backgrounds'),
    ('Skin Color', 'tag_group:skin_color'),
    ('Body Types', 'tag_group:body_types'),
  ];

  // 预定义 Pools
  static const _popularPools = [
    ('Genshin Characters', 21512),
    ('Blue Archive', 22345),
    ('Arknights', 17654),
    ('Fate Grand Order', 15432),
    ('Honkai Star Rail', 24567),
    ('Azur Lane', 18765),
  ];

  List<(String, String)> get _filteredTagGroups {
    if (_searchQuery.isEmpty) return _tagGroups;
    final query = _searchQuery.toLowerCase();
    return _tagGroups.where((g) {
      return g.$1.toLowerCase().contains(query) ||
          g.$2.toLowerCase().contains(query);
    }).toList();
  }

  List<(String, int)> get _filteredPools {
    if (_searchQuery.isEmpty) return _popularPools;
    final query = _searchQuery.toLowerCase();
    return _popularPools.where((p) {
      return p.$1.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _sourceTabIndex = _tabController.index;
          _searchQuery = '';
          _searchController.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagsController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              _buildNameSection(context),
              _buildSourceTabs(context),
              // 搜索栏（仅在 Tag Group 和 Pool Tab 显示）
              if (_sourceTabIndex > 0) _buildSearchBar(context),
              Flexible(child: _buildTabContent(context)),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.3),
            colorScheme.secondaryContainer.withOpacity(0.2),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.add_circle_outline,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '添加词组',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '添加到「${widget.category.name}」类别',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            iconSize: 20,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _EmojiPickerButton(
            emoji: _selectedEmoji,
            onTap: _pickEmoji,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '词组名称',
                hintText: '输入词组名称',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入词组名称';
                }
                return null;
              },
              autofocus: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTabs(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: colorScheme.onPrimaryContainer,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note, size: 16),
                SizedBox(width: 4),
                Text('自定义'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.label_outline, size: 16),
                SizedBox(width: 4),
                Text('Tag Group'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined, size: 16),
                SizedBox(width: 4),
                Text('Pool'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: _sourceTabIndex == 1 ? '搜索 Tag Group...' : '搜索 Pool...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildCustomTagsTab(context),
        _buildTagGroupTab(context),
        _buildPoolTab(context),
      ],
    );
  }

  Widget _buildCustomTagsTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '标签列表',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '每行一个标签，支持格式: tag 或 tag:weight',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextFormField(
              controller: _tagsController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'red hair\nblue eyes:2\nlong hair',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagGroupTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredTagGroups;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Danbooru Tag Group',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${filtered.length} 个',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '未找到匹配的 Tag Group',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final (label, groupTitle) = filtered[index];
                      final isSelected = _selectedDanbooruGroup == groupTitle;
                      return _DanbooruListTile(
                        label: label,
                        subtitle: groupTitle,
                        isSelected: isSelected,
                        onTap: () => _selectDanbooruGroup(groupTitle, label),
                        onOpenExternal: () => _openDanbooruUrl(
                          'https://danbooru.donmai.us/wiki_pages/$groupTitle',
                        ),
                        itemType: DanbooruItemType.tagGroup,
                        groupTitle: groupTitle,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredPools;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Danbooru Pool',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${filtered.length} 个',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '未找到匹配的 Pool',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final (label, poolId) = filtered[index];
                      final isSelected = _selectedPoolId == poolId;
                      return _DanbooruListTile(
                        label: label,
                        subtitle: 'Pool #$poolId',
                        isSelected: isSelected,
                        onTap: () => _selectPool(poolId, label),
                        onOpenExternal: () => _openDanbooruUrl(
                          'https://danbooru.donmai.us/pools/$poolId',
                        ),
                        itemType: DanbooruItemType.pool,
                        poolId: poolId,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _canSubmit() ? _addGroup : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickEmoji() async {
    final emoji = await EmojiPickerDialog.show(context);
    if (emoji != null) setState(() => _selectedEmoji = emoji);
  }

  void _selectDanbooruGroup(String groupTitle, String label) {
    setState(() {
      _selectedDanbooruGroup = groupTitle;
      _selectedPoolId = null;
      if (_nameController.text.isEmpty) {
        _nameController.text = label;
      }
    });
  }

  void _selectPool(int poolId, String label) {
    setState(() {
      _selectedPoolId = poolId;
      _selectedDanbooruGroup = null;
      if (_nameController.text.isEmpty) {
        _nameController.text = label;
      }
    });
  }

  Future<void> _openDanbooruUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _canSubmit() {
    final hasName = _nameController.text.trim().isNotEmpty;
    switch (_sourceTabIndex) {
      case 0:
        return hasName;
      case 1:
        return hasName && _selectedDanbooruGroup != null;
      case 2:
        return hasName && _selectedPoolId != null;
      default:
        return false;
    }
  }

  void _addGroup() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final emoji = _selectedEmoji;
    RandomTagGroup newGroup;

    switch (_sourceTabIndex) {
      case 0:
        final tags = _parseTagsInput(_tagsController.text);
        newGroup = RandomTagGroup.custom(name: name, emoji: emoji, tags: tags);
        break;
      case 1:
        newGroup = RandomTagGroup.fromTagGroup(
          name: name,
          tagGroupName: _selectedDanbooruGroup!,
          tags: [],
          emoji: emoji,
        );
        break;
      case 2:
        newGroup = RandomTagGroup.fromPool(
          name: name,
          poolId: _selectedPoolId!.toString(),
          postCount: 0,
          emoji: emoji,
        );
        break;
      default:
        return;
    }

    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final state = ref.read(randomPresetNotifierProvider);
    final preset = state.presets.firstWhere((p) => p.id == widget.presetId);
    final category =
        preset.categories.firstWhere((c) => c.id == widget.category.id);
    final updatedCategory = category.addGroup(newGroup);
    notifier.updateCategory(updatedCategory);

    Navigator.pop(context);
  }

  List<WeightedTag> _parseTagsInput(String input) {
    final lines = input.split('\n');
    final tags = <WeightedTag>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final tag = parts.sublist(0, parts.length - 1).join(':');
        final weight = int.tryParse(parts.last) ?? 1;
        tags.add(WeightedTag(tag: tag, weight: weight));
      } else {
        tags.add(WeightedTag(tag: trimmed, weight: 1));
      }
    }
    return tags;
  }
}

/// Emoji 选择按钮
class _EmojiPickerButton extends StatefulWidget {
  const _EmojiPickerButton({required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;
  @override
  State<_EmojiPickerButton> createState() => _EmojiPickerButtonState();
}

class _EmojiPickerButtonState extends State<_EmojiPickerButton> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.3),
              width: _isHovered ? 2 : 1,
            ),
          ),
          child: Center(
            child: widget.emoji.isEmpty
                ? Icon(
                    Icons.add_reaction_outlined,
                    color: _isHovered
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  )
                : Text(widget.emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ),
    );
  }
}

/// Danbooru 列表项类型
enum DanbooruItemType { tagGroup, pool }

/// Danbooru 列表项
class _DanbooruListTile extends StatefulWidget {
  const _DanbooruListTile({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.onOpenExternal,
    required this.itemType,
    this.groupTitle,
    this.poolId,
  });
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOpenExternal;
  final DanbooruItemType itemType;
  final String? groupTitle;
  final int? poolId;
  @override
  State<_DanbooruListTile> createState() => _DanbooruListTileState();
}

class _DanbooruListTileState extends State<_DanbooruListTile> {
  bool _isHovered = false;

  Widget _buildPreviewContent(BuildContext context) {
    if (widget.itemType == DanbooruItemType.tagGroup &&
        widget.groupTitle != null) {
      return TagGroupPreviewContent(groupTitle: widget.groupTitle!);
    } else if (widget.itemType == DanbooruItemType.pool &&
        widget.poolId != null) {
      return PoolPreviewContent(poolId: widget.poolId!);
    }
    return const PreviewCardError(message: '无法加载预览');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primaryContainer
                : _isHovered
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  widget.isSelected ? colorScheme.primary : Colors.transparent,
              width: widget.isSelected ? 2 : 0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 20,
                color: widget.isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (_isHovered || widget.isSelected)
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: widget.onOpenExternal,
                  tooltip: '在 Danbooru 中查看',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // 用悬浮预览卡片包装
    return HoverPreviewCard(
      previewBuilder: _buildPreviewContent,
      child: tile,
    );
  }
}

/// 添加词组卡片
///
/// 放置在词组列表末尾，点击后打开添加词组对话框
class _AddTagGroupCard extends StatefulWidget {
  const _AddTagGroupCard({
    required this.onTap,
    this.isEmpty = false,
  });

  final VoidCallback onTap;
  final bool isEmpty;

  @override
  State<_AddTagGroupCard> createState() => _AddTagGroupCardState();
}

class _AddTagGroupCardState extends State<_AddTagGroupCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 135,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 图标
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? colorScheme.primary.withOpacity(0.15)
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: _isHovered
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                // 文字
                Text(
                  '添加词组',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _isHovered
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight:
                        _isHovered ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
