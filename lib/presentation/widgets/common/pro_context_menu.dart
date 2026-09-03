import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../adaptive/interaction_policy.dart';
import 'themed_divider.dart';

/// 上下文菜单项
class ProMenuItem {
  final String id;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isDivider;
  final bool isDanger;

  const ProMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.onTap,
    this.isDivider = false,
    this.isDanger = false,
  });

  const ProMenuItem.divider()
    : id = '_divider',
      label = '',
      icon = null,
      onTap = null,
      isDivider = true,
      isDanger = false;
}

/// 专业上下文菜单组件
class ProContextMenu extends StatefulWidget {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem) onSelect;
  final double? maxHeight;

  const ProContextMenu({
    super.key,
    required this.position,
    required this.items,
    required this.onSelect,
    this.maxHeight,
  });

  static const double minimumWidth = 180;
  static const double maximumWidth = 320;

  static double widthFor(BuildContext context) {
    final availableWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      0.0,
      maximumWidth,
    );
    if (availableWidth <= minimumWidth) return availableWidth;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return (minimumWidth + (textScale - 1).clamp(0, 2) * 56).clamp(
      minimumWidth,
      availableWidth,
    );
  }

  @override
  State<ProContextMenu> createState() => _ProContextMenuState();
}

class _ProContextMenuState extends State<ProContextMenu> {
  final FocusNode _menuFocusNode = FocusNode(debugLabel: 'context menu');
  late List<FocusNode> _itemFocusNodes;
  late List<int> _selectableIndexes;

  @override
  void initState() {
    super.initState();
    _resetFocusNodes();
  }

  @override
  void didUpdateWidget(ProContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      for (final node in _itemFocusNodes) {
        node.dispose();
      }
      _resetFocusNodes();
    }
  }

  void _resetFocusNodes() {
    _itemFocusNodes = [
      for (var index = 0; index < widget.items.length; index++)
        FocusNode(debugLabel: 'context menu item $index'),
    ];
    _selectableIndexes = [
      for (var index = 0; index < widget.items.length; index++)
        if (!widget.items[index].isDivider) index,
    ];
  }

  @override
  void dispose() {
    _menuFocusNode.dispose();
    for (final node in _itemFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_selectableIndexes.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.home &&
        key != LogicalKeyboardKey.end) {
      return KeyEventResult.ignored;
    }

    final currentItemIndex = _itemFocusNodes.indexWhere(
      (node) => node.hasFocus,
    );
    final currentSelectableIndex = _selectableIndexes.indexOf(currentItemIndex);
    final int targetSelectableIndex;
    if (key == LogicalKeyboardKey.home) {
      targetSelectableIndex = 0;
    } else if (key == LogicalKeyboardKey.end) {
      targetSelectableIndex = _selectableIndexes.length - 1;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      targetSelectableIndex = currentSelectableIndex <= 0
          ? _selectableIndexes.length - 1
          : currentSelectableIndex - 1;
    } else {
      targetSelectableIndex =
          (currentSelectableIndex + 1) % _selectableIndexes.length;
    }
    _itemFocusNodes[_selectableIndexes[targetSelectableIndex]].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Focus(
          focusNode: _menuFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: ProContextMenu.widthFor(context),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.98)
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: widget.maxHeight == null
                      ? const BoxConstraints()
                      : BoxConstraints(maxHeight: widget.maxHeight!),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < widget.items.length;
                          index++
                        )
                          if (widget.items[index].isDivider)
                            const ThemedDivider(height: 1)
                          else
                            _ContextMenuItem(
                              item: widget.items[index],
                              focusNode: _itemFocusNodes[index],
                              order: index.toDouble(),
                              onSelect: widget.onSelect,
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  const _ContextMenuItem({
    required this.item,
    required this.focusNode,
    required this.order,
    required this.onSelect,
  });

  final ProMenuItem item;
  final FocusNode focusNode;
  final double order;
  final void Function(ProMenuItem) onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemColor = item.isDanger ? colorScheme.error : colorScheme.onSurface;
    final extent = context.interactionPolicy.minimumControlExtent;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120);

    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: Semantics(
        button: true,
        label: item.label,
        child: ExcludeSemantics(
          child: InkWell(
            focusNode: focusNode,
            onTap: () => onSelect(item),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (!states.contains(WidgetState.hovered) &&
                  !states.contains(WidgetState.focused) &&
                  !states.contains(WidgetState.pressed)) {
                return Colors.transparent;
              }
              return item.isDanger
                  ? colorScheme.error.withValues(alpha: isDark ? 0.15 : 0.1)
                  : colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08);
            }),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOut,
              constraints: BoxConstraints(minHeight: extent),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 18, color: itemColor),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: itemColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
