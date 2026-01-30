import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/random_preset_provider.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../common/elevated_card.dart';
import 'add_tag_group_dialog.dart';
import 'category_card_widgets.dart';
import 'tag_group_card.dart';

// 导出拆分的组件，方便外部使用
export 'add_tag_group_dialog.dart' show AddTagGroupDialog;
export 'category_card_list.dart' show CategoryCardList, CategoryCardGrid;
export 'category_card_widgets.dart'
    show
        ScopeTripleSwitch,
        ColorfulProbabilitySlider,
        AddTagGroupCard,
        AddCategoryButton,
        EmptyCategoryPlaceholder,
        CategoryStats;

/// 类别卡片组件
///
/// 显示类别信息，支持展开/收起内部的词组卡片
/// 采用 Dimensional Layering 风格设计
class CategoryCard extends ConsumerStatefulWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.presetId,
    this.isPresetDefault = false,
    this.onEdit,
  });

  final RandomCategory category;
  final String presetId;
  final bool isPresetDefault;
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

    return Opacity(
      opacity: category.enabled ? 1.0 : 0.5,
      child: ElevatedCard(
        elevation: _isExpanded ? CardElevation.level2 : CardElevation.level1,
        hoverElevation: CardElevation.level2,
        enableHoverEffect: category.enabled,
        hoverTranslateY: -3,
        borderRadius: 8,
        gradientBorder: category.enabled && _isExpanded
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
            _buildHeader(context, category),
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
          // 第一行：emoji + 名称 + 作用域开关 + 启用开关
          Row(
            children: [
              if (category.emoji.isNotEmpty)
                Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              if (category.emoji.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration:
                        category.enabled ? null : TextDecoration.lineThrough,
                    color:
                        category.enabled ? null : colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 作用域三选项开关
              SizedBox(
                width: 220,
                child: ScopeTripleSwitch(
                  scope: category.scope,
                  enabled: !widget.isPresetDefault,
                  onChanged: (scope) {
                    _updateCategory(category.copyWith(scope: scope));
                  },
                ),
              ),
              const SizedBox(width: 8),
              // 启用开关
              SizedBox(
                height: 28,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: category.enabled,
                    onChanged: widget.isPresetDefault
                        ? null
                        : (value) {
                            _updateCategory(category.copyWith(enabled: value));
                          },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：概率滑条 + 词组数量
          Row(
            children: [
              Expanded(
                child: ColorfulProbabilitySlider(
                  probability: category.probability,
                  enabled: category.enabled,
                  interactive: !widget.isPresetDefault,
                  onChanged: (value) {
                    _updateCategory(category.copyWith(probability: value));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${category.groupCount} 个词组',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
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
              Text(
                '词组列表',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (category.groups.isEmpty)
                AddTagGroupCard(
                  onTap: () => _addTagGroup(context),
                  enabled: !widget.isPresetDefault,
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
                        categoryKey: category.key,
                        presetId: widget.presetId,
                        isPresetDefault: widget.isPresetDefault,
                      );
                    }),
                    AddTagGroupCard(
                      onTap: () => _addTagGroup(context),
                      enabled: !widget.isPresetDefault,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateCategory(RandomCategory updatedCategory) {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    notifier.updateCategory(updatedCategory);
  }

  void _addTagGroup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddTagGroupDialog(
        category: widget.category,
        presetId: widget.presetId,
      ),
    );
  }
}
