import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../common/themed_confirm_dialog.dart';
import 'add_tag_group_dialog.dart';
import 'category_card_widgets.dart';
import 'random_config_l10n.dart';
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

class _CategoryCardState extends ConsumerState<CategoryCard> {
  bool _isExpanded = false;
  bool _isHovered = false;

  /// 当前正在拖拽的词组（用于显示垃圾桶区域）
  RandomTagGroup? _draggingGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final category = widget.category;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final restingColor = colorScheme.surfaceContainer;
    final raisedColor = colorScheme.surfaceContainerHigh;
    final backgroundColor = _isExpanded
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.055),
            raisedColor,
          )
        : _isHovered
        ? raisedColor
        : restingColor;

    return Semantics(
      container: true,
      button: true,
      expanded: _isExpanded,
      enabled: category.enabled,
      label: context.l10n.randomCategoryName(category),
      child: Opacity(
        opacity: category.enabled ? 1 : 0.58,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isExpanded || _isHovered
                  ? [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 10,
                        spreadRadius: -4,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, category),
                    AnimatedCrossFade(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      sizeCurve: Curves.easeOutCubic,
                      crossFadeState: _isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildExpandedContent(context, category),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RandomCategory category) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：emoji + 名称 + 作用域开关 + 启用开关
          Row(
            children: [
              if (category.emoji.isNotEmpty)
                Text(category.emoji, style: const TextStyle(fontSize: 18)),
              if (category.emoji.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.randomCategoryName(category),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: category.enabled
                        ? null
                        : TextDecoration.lineThrough,
                    color: category.enabled
                        ? null
                        : colorScheme.onSurfaceVariant,
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
                l10n.randomManager_tagGroupCount(
                  category.groupCount.toString(),
                ),
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
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          indent: 12,
          endIndent: 12,
          color: colorScheme.onSurface.withValues(alpha: 0.07),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.randomManager_tagGroupList,
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
                            child: Opacity(opacity: 0.9, child: card),
                          ),
                          childWhenDragging: Opacity(opacity: 0.3, child: card),
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
      title: context.l10n.randomManager_deleteTagGroupTitle,
      content: context.l10n.randomManager_deleteTagGroupConfirm(
        context.l10n.randomTagGroupName(data.group),
      ),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );

    if (confirmed) {
      ref
          .read(randomPresetNotifierProvider.notifier)
          .removeGroupFromCategory(data.categoryKey, data.group.id);
    }
  }
}

/// 拖拽数据
class _DragData {
  final RandomTagGroup group;
  final String categoryKey;

  _DragData({required this.group, required this.categoryKey});
}

/// 垃圾桶拖放区域
class _TrashDropZone extends StatefulWidget {
  const _TrashDropZone({required this.onAccept});

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
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final dropZone = AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
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
                  : colorScheme.outline.withValues(alpha: 0.3),
              width: _isHovering ? 2 : 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: colorScheme.error.withValues(alpha: 0.3),
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
                _isHovering
                    ? context.l10n.randomManager_releaseToDelete
                    : context.l10n.randomManager_dragHereToDelete,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _isHovering
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                  fontWeight: _isHovering ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        );
        return reduceMotion
            ? dropZone
            : ScaleTransition(scale: _scaleAnimation, child: dropZone);
      },
    );
  }
}
