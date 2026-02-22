import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/random_preset_provider.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../common/elevated_card.dart';
import '../../common/themed_confirm_dialog.dart';
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

  /// 当前正在拖拽的词组（用于显示垃圾桶区域）
  RandomTagGroup? _draggingGroup;

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
                      // 判断该词组是否可删除：默认预设中的内置词组不可删除
                      final canDelete =
                          !(widget.isPresetDefault && group.isBuiltin);

                      final card = TagGroupCard(
                        tagGroup: group,
                        categoryId: category.id,
                        categoryKey: category.key,
                        presetId: widget.presetId,
                        isPresetDefault: widget.isPresetDefault,
                      );

                      // 可删除的词组可以拖拽
                      if (canDelete) {
                        return Draggable<_DragData>(
                          data: _DragData(
                            group: group,
                            categoryKey: category.key,
                          ),
                          onDragStarted: () {
                            setState(() => _draggingGroup = group);
                          },
                          onDragEnd: (_) {
                            setState(() => _draggingGroup = null);
                          },
                          feedback: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(8),
                            child: Opacity(
                              opacity: 0.9,
                              child: card,
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: card,
                          ),
                          child: card,
                        );
                      }
                      return card;
                    }),
                    // 拖拽时显示垃圾桶区域
                    if (_draggingGroup != null)
                      _TrashDropZone(
                        onAccept: (data) =>
                            _showDeleteConfirmDialog(context, data),
                      )
                    else
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

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(BuildContext context, _DragData data) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '删除词组',
      content: '确定要删除词组「${data.group.name}」吗？此操作不可撤销。',
      confirmText: '删除',
      cancelText: '取消',
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );

    if (confirmed) {
      ref.read(randomPresetNotifierProvider.notifier).removeGroupFromCategory(
            data.categoryKey,
            data.group.id,
          );
    }
  }
}

/// 拖拽数据
class _DragData {
  final RandomTagGroup group;
  final String categoryKey;

  _DragData({
    required this.group,
    required this.categoryKey,
  });
}

/// 垃圾桶拖放区域
class _TrashDropZone extends StatefulWidget {
  const _TrashDropZone({
    required this.onAccept,
  });

  final void Function(_DragData data) onAccept;

  @override
  State<_TrashDropZone> createState() => _TrashDropZoneState();
}

class _TrashDropZoneState extends State<_TrashDropZone>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DragTarget<_DragData>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isHovering = true);
        _animationController.forward();
        return true;
      },
      onLeave: (_) {
        setState(() => _isHovering = false);
        _animationController.reverse();
      },
      onAcceptWithDetails: (details) {
        setState(() => _isHovering = false);
        _animationController.reverse();
        widget.onAccept(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 135,
            height: 80,
            decoration: BoxDecoration(
              color: _isHovering
                  ? colorScheme.errorContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHovering
                    ? colorScheme.error
                    : colorScheme.outline.withOpacity(0.3),
                width: _isHovering ? 2 : 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: colorScheme.error.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isHovering ? Icons.delete_forever : Icons.delete_outline,
                  size: _isHovering ? 32 : 28,
                  color: _isHovering
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  _isHovering ? '松开删除' : '拖到这里删除',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _isHovering
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    fontWeight: _isHovering ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
