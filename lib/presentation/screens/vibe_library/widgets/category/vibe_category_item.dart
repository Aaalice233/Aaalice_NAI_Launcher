import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../widgets/common/context_menu_anchor.dart';
import '../../../../adaptive/interaction_policy.dart';

enum _VibeCategoryAction { rename, addSubCategory, delete }

/// Vibe分类项组件
///
/// 用于在Vibe库侧边栏显示分类项，支持展开/折叠、重命名、右键菜单等功能
class VibeCategoryItem extends StatefulWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final int count;
  final bool isSelected;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onExpand;
  final void Function(String)? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onAddSubCategory;
  final bool reserveExpansionSpace;

  const VibeCategoryItem({
    super.key,
    required this.icon,
    this.iconColor,
    required this.label,
    required this.count,
    required this.isSelected,
    this.depth = 0,
    this.hasChildren = false,
    this.isExpanded = false,
    required this.onTap,
    this.onExpand,
    this.onRename,
    this.onDelete,
    this.onAddSubCategory,
    this.reserveExpansionSpace = true,
  });

  @override
  State<VibeCategoryItem> createState() => _VibeCategoryItemState();
}

class _VibeCategoryItemState extends State<VibeCategoryItem> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editController;
  late FocusNode _editFocusNode;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.label);
    _editFocusNode = FocusNode();
    _editFocusNode.onKeyEvent = _handleEditKeyEvent;
  }

  KeyEventResult _handleEditKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _editController.text = widget.label;
      setState(() => _isEditing = false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant VibeCategoryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label && !_isEditing) {
      _editController.text = widget.label;
    }
  }

  @override
  void dispose() {
    _editFocusNode.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTouch = context.interactionPolicy.shouldExposeTouchAlternatives;
    // Preserve a usable label/action area for deeply nested imported trees.
    final indent = (12.0 + widget.depth * 16.0).clamp(12.0, 44.0).toDouble();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onSecondaryTapUp:
            widget.onRename != null ||
                widget.onAddSubCategory != null ||
                widget.onDelete != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primaryContainer
                : (_isHovering
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: isTouch || !widget.reserveExpansionSpace ? 48 : 0,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: indent,
                  right: isTouch ? 0 : 8,
                  top: isTouch || !widget.reserveExpansionSpace ? 0 : 8,
                  bottom: isTouch || !widget.reserveExpansionSpace ? 0 : 8,
                ),
                child: Row(
                  children: [
                    // 展开/折叠按钮
                    if (widget.hasChildren)
                      IconButton(
                        onPressed: widget.onExpand,
                        tooltip: widget.isExpanded
                            ? context.l10n.common_collapse
                            : context.l10n.common_expand,
                        icon: Icon(
                          widget.isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 18,
                          color: theme.colorScheme.outline,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                      )
                    else if (widget.reserveExpansionSpace)
                      const SizedBox(width: 48, height: 48),

                    // 图标
                    Icon(
                      widget.icon,
                      size: 18,
                      color:
                          widget.iconColor ??
                          (widget.isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),

                    // 名称（编辑模式或显示模式）
                    Expanded(
                      child: _isEditing
                          ? TextField(
                              controller: _editController,
                              focusNode: _editFocusNode,
                              autofocus: true,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  widget.onRename?.call(value.trim());
                                }
                                if (mounted) {
                                  setState(() => _isEditing = false);
                                }
                              },
                              onTapOutside: (_) {
                                _editController.text = widget.label;
                                if (mounted) {
                                  setState(() => _isEditing = false);
                                }
                              },
                            )
                          : Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: widget.isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: widget.isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),

                    // 拖拽提示图标（悬停时显示）
                    if (_isHovering && widget.onRename != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: theme.colorScheme.outline.withAlpha(128),
                        ),
                      ),

                    // 数量
                    Text(
                      widget.count.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    if (isTouch &&
                        (widget.onRename != null ||
                            widget.onAddSubCategory != null ||
                            widget.onDelete != null))
                      PopupMenuButton<_VibeCategoryAction>(
                        tooltip: context.l10n.common_moreActions,
                        onSelected: (action) {
                          switch (action) {
                            case _VibeCategoryAction.rename:
                              setState(() => _isEditing = true);
                            case _VibeCategoryAction.addSubCategory:
                              widget.onAddSubCategory?.call();
                            case _VibeCategoryAction.delete:
                              widget.onDelete?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          if (widget.onRename != null)
                            PopupMenuItem(
                              value: _VibeCategoryAction.rename,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.edit),
                                title: Text(context.l10n.common_rename),
                              ),
                            ),
                          if (widget.onAddSubCategory != null)
                            PopupMenuItem(
                              value: _VibeCategoryAction.addSubCategory,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.create_new_folder),
                                title: Text(
                                  context.l10n.vibeLibrary_newSubCategory,
                                ),
                              ),
                            ),
                          if (widget.onDelete != null)
                            PopupMenuItem(
                              value: _VibeCategoryAction.delete,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.delete,
                                  color: theme.colorScheme.error,
                                ),
                                title: Text(context.l10n.common_delete),
                              ),
                            ),
                        ],
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

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: contextMenuAnchorAt(context, position),
      items: [
        if (widget.onRename != null)
          PopupMenuItem(
            onTap: () {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() => _isEditing = true);
                }
              });
            },
            child: Row(
              children: [
                const Icon(Icons.edit, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.common_rename),
              ],
            ),
          ),
        if (widget.onAddSubCategory != null)
          PopupMenuItem(
            onTap: widget.onAddSubCategory,
            child: Row(
              children: [
                const Icon(Icons.create_new_folder, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.vibeLibrary_newSubCategory),
              ],
            ),
          ),
        if (widget.onDelete != null)
          PopupMenuItem(
            onTap: widget.onDelete,
            child: Row(
              children: [
                Icon(
                  Icons.delete,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.common_delete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
