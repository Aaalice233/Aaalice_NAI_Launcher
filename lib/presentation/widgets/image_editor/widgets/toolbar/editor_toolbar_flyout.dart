import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../themes/design_tokens.dart';

/// 二级菜单里的一项
@immutable
class EditorToolbarFlyoutItem {
  const EditorToolbarFlyoutItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.onActivate,
    this.shortcutLabel,
    this.selected = false,
  });

  final Key key;
  final IconData icon;
  final String label;
  final String? shortcutLabel;

  /// 当前工具或已开启的开关
  final bool selected;

  final VoidCallback onActivate;
}

/// 竖排工具栏向侧边展开，底部横排工具栏向上展开
enum EditorToolbarFlyoutPlacement { side, above }

/// 折叠按钮的同组二级菜单：悬停片刻、右键、长按或键盘均可展开，单击按钮仍直接激活它显示的项。
/// 名称与快捷键由二级菜单列出，按钮本身不要再挂 Tooltip，否则悬停时会先闪出说明再弹菜单
class EditorToolbarFlyout extends StatefulWidget {
  const EditorToolbarFlyout({
    super.key,
    required this.items,
    required this.placement,
    required this.child,
  });

  final List<EditorToolbarFlyoutItem> items;
  final EditorToolbarFlyoutPlacement placement;
  final Widget child;

  // 沿工具栏纵向划过时不应一路弹开
  static const hoverOpenDelay = Duration(milliseconds: 300);

  // 留给指针从按钮斜穿到菜单的时间
  static const hoverCloseDelay = Duration(milliseconds: 200);

  @override
  State<EditorToolbarFlyout> createState() => _EditorToolbarFlyoutState();
}

enum _OpenTrigger { hover, pointer, keyboard }

class _EditorToolbarFlyoutState extends State<EditorToolbarFlyout> {
  final _controller = MenuController();
  final _anchorFocus = FocusNode(
    debugLabel: 'EditorToolbarFlyout anchor',
    canRequestFocus: false,
    skipTraversal: true,
  );
  Timer? _openTimer;
  Timer? _closeTimer;
  _OpenTrigger? _trigger;

  /// 每次展开递增，让菜单面板重建并按本次触发方式决定是否取焦点
  int _openGeneration = 0;

  @override
  void dispose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _anchorFocus.dispose();
    super.dispose();
  }

  void _open(_OpenTrigger trigger) {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    if (!mounted) return;
    // 键盘展开要重建面板把焦点移进去；先清掉旧触发方式，免得收起回调把焦点还给按钮
    if (trigger == _OpenTrigger.keyboard || !_controller.isOpen) {
      _trigger = null;
      _controller.close();
      _openGeneration++;
      _trigger = trigger;
      _controller.open();
    } else {
      _trigger = trigger;
    }
  }

  void _close() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _controller.close();
  }

  void _scheduleHoverClose() {
    if (_trigger != _OpenTrigger.hover) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(EditorToolbarFlyout.hoverCloseDelay, _close);
  }

  void _handleAnchorEnter(PointerEnterEvent event) {
    _closeTimer?.cancel();
    if (_controller.isOpen || event.buttons != 0) return;
    _openTimer?.cancel();
    _openTimer = Timer(
      EditorToolbarFlyout.hoverOpenDelay,
      () => _open(_OpenTrigger.hover),
    );
  }

  void _handleAnchorExit(PointerExitEvent event) {
    _openTimer?.cancel();
    _scheduleHoverClose();
  }

  // 点按钮本身表示选它显示的项，菜单随之收起
  void _handleAnchorPointerDown(PointerDownEvent event) {
    _openTimer?.cancel();
    if (event.buttons == kPrimaryButton && _controller.isOpen) _close();
  }

  void _openFromPointer() => _open(_OpenTrigger.pointer);

  void _openFromKeyboard() => _open(_OpenTrigger.keyboard);

  void _activate(EditorToolbarFlyoutItem item) {
    _close();
    item.onActivate();
  }

  void _handleClosed() {
    final restoreFocus = _trigger == _OpenTrigger.keyboard;
    _trigger = null;
    if (!restoreFocus) return;
    // 激活后按钮会换成新显示的项，旧焦点节点随之销毁，等重建后再找
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final node in _anchorFocus.descendants) {
        if (node.canRequestFocus) {
          node.requestFocus();
          return;
        }
      }
    });
  }

  LogicalKeyboardKey _expandKey(TextDirection direction) {
    return switch (widget.placement) {
      EditorToolbarFlyoutPlacement.above => LogicalKeyboardKey.arrowUp,
      EditorToolbarFlyoutPlacement.side => switch (direction) {
        TextDirection.ltr => LogicalKeyboardKey.arrowRight,
        TextDirection.rtl => LogicalKeyboardKey.arrowLeft,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return RawMenuAnchor(
      controller: _controller,
      onClose: _handleClosed,
      overlayBuilder: (context, info) => _FlyoutOverlay(
        key: ValueKey(_openGeneration),
        info: info,
        placement: widget.placement,
        items: widget.items,
        focusOnOpen: _trigger == _OpenTrigger.keyboard,
        onPointerEnter: () => _closeTimer?.cancel(),
        onPointerExit: _scheduleHoverClose,
        onDismiss: _close,
        onSelected: _activate,
      ),
      child: CallbackShortcuts(
        bindings: {
          SingleActivator(_expandKey(direction)): _openFromKeyboard,
          const SingleActivator(LogicalKeyboardKey.contextMenu):
              _openFromKeyboard,
          const SingleActivator(LogicalKeyboardKey.f10, shift: true):
              _openFromKeyboard,
        },
        child: MergeSemantics(
          child: Semantics(
            hint: context.l10n.editor_toolbarFlyoutHint,
            customSemanticsActions: {
              CustomSemanticsAction(
                label: context.l10n.editor_toolbarFlyoutExpand,
              ): _openFromPointer,
            },
            child: Focus(
              focusNode: _anchorFocus,
              child: MouseRegion(
                onEnter: _handleAnchorEnter,
                onExit: _handleAnchorExit,
                child: Listener(
                  onPointerDown: _handleAnchorPointerDown,
                  child: GestureDetector(
                    onSecondaryTap: _openFromPointer,
                    onLongPress: _openFromPointer,
                    child: widget.child,
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

/// 折叠按钮角上的小三角，颜色跟随按钮前景
class EditorToolbarFoldIndicator extends StatelessWidget {
  const EditorToolbarFoldIndicator({super.key, required this.color});

  final Color color;

  static const double size = 5;

  // 与按钮边缘保持的距离
  static const double inset = 4;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      end: inset,
      bottom: inset,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: const Size.square(size),
          painter: _FoldTrianglePainter(
            color: color,
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

class _FoldTrianglePainter extends CustomPainter {
  const _FoldTrianglePainter({
    required this.color,
    required this.textDirection,
  });

  final Color color;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final cornerX = textDirection == TextDirection.ltr ? size.width : 0.0;
    final path = Path()
      ..moveTo(cornerX, 0)
      ..lineTo(cornerX, size.height)
      ..lineTo(size.width - cornerX, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FoldTrianglePainter oldDelegate) =>
      color != oldDelegate.color || textDirection != oldDelegate.textDirection;
}

class _FlyoutOverlay extends StatefulWidget {
  const _FlyoutOverlay({
    super.key,
    required this.info,
    required this.placement,
    required this.items,
    required this.focusOnOpen,
    required this.onPointerEnter,
    required this.onPointerExit,
    required this.onDismiss,
    required this.onSelected,
  });

  final RawMenuOverlayInfo info;
  final EditorToolbarFlyoutPlacement placement;
  final List<EditorToolbarFlyoutItem> items;
  final bool focusOnOpen;
  final VoidCallback onPointerEnter;
  final VoidCallback onPointerExit;
  final VoidCallback onDismiss;
  final ValueChanged<EditorToolbarFlyoutItem> onSelected;

  static const double gap = DesignTokens.spacingXxs;
  static const double verticalPadding = DesignTokens.spacingXs;

  @override
  State<_FlyoutOverlay> createState() => _FlyoutOverlayState();
}

class _FlyoutOverlayState extends State<_FlyoutOverlay> {
  final _scopeNode = FocusScopeNode(debugLabel: 'EditorToolbarFlyout menu');
  late List<FocusNode> _itemNodes = _createItemNodes();

  List<FocusNode> _createItemNodes() => [
    for (final item in widget.items)
      FocusNode(debugLabel: 'EditorToolbarFlyout ${item.label}'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.focusOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final selected = widget.items.indexWhere((item) => item.selected);
        _itemNodes[math.max(selected, 0)].requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(_FlyoutOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _disposeItemNodes();
      _itemNodes = _createItemNodes();
    }
  }

  void _disposeItemNodes() {
    for (final node in _itemNodes) {
      node.dispose();
    }
  }

  @override
  void dispose() {
    _disposeItemNodes();
    _scopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return ConstrainedBox(
      constraints: BoxConstraints.loose(info.overlaySize),
      child: CustomSingleChildLayout(
        delegate: _FlyoutLayout(
          anchor: info.anchorRect,
          placement: widget.placement,
          textDirection: Directionality.of(context),
          gap: _FlyoutOverlay.gap,
          panelInset: _FlyoutOverlay.verticalPadding,
        ),
        child: TapRegion(
          groupId: info.tapRegionGroupId,
          // RawMenuAnchor 的根菜单不会因点到外面而自行收起
          onTapOutside: (_) => widget.onDismiss(),
          child: MouseRegion(
            onEnter: (_) => widget.onPointerEnter(),
            onExit: (_) => widget.onPointerExit(),
            child: FocusScope(
              node: _scopeNode,
              skipTraversal: true,
              child: Actions(
                actions: {
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      widget.onDismiss();
                      return null;
                    },
                  ),
                },
                child: Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.arrowUp):
                        DirectionalFocusIntent(TraversalDirection.up),
                    SingleActivator(LogicalKeyboardKey.arrowDown):
                        DirectionalFocusIntent(TraversalDirection.down),
                  },
                  child: _FlyoutPanel(
                    items: widget.items,
                    itemNodes: _itemNodes,
                    onSelected: widget.onSelected,
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

/// 外观沿用应用的菜单主题，与其他下拉菜单一致
class _FlyoutPanel extends StatelessWidget {
  const _FlyoutPanel({
    required this.items,
    required this.itemNodes,
    required this.onSelected,
  });

  final List<EditorToolbarFlyoutItem> items;
  final List<FocusNode> itemNodes;
  final ValueChanged<EditorToolbarFlyoutItem> onSelected;

  static const double _iconSize = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = MenuTheme.of(context).style;
    const states = <WidgetState>{};
    final minimumExtent = context.interactionPolicy.minimumControlExtent;
    final itemStyle = MenuItemButton.styleFrom(
      minimumSize: Size(0, minimumExtent),
    );

    return Material(
      color:
          style?.backgroundColor?.resolve(states) ??
          colorScheme.surfaceContainer,
      elevation: style?.elevation?.resolve(states) ?? 3,
      shadowColor: style?.shadowColor?.resolve(states) ?? colorScheme.shadow,
      surfaceTintColor:
          style?.surfaceTintColor?.resolve(states) ?? colorScheme.surfaceTint,
      shape:
          style?.shape?.resolve(states) ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: _FlyoutOverlay.verticalPadding,
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, item) in items.indexed)
                MergeSemantics(
                  child: Semantics(
                    selected: item.selected,
                    child: MenuItemButton(
                      key: item.key,
                      focusNode: itemNodes[index],
                      // 画布持有焦点时工具快捷键才生效，悬停不能把焦点抢进菜单
                      requestFocusOnHover: false,
                      style: itemStyle,
                      leadingIcon: Icon(item.icon, size: _iconSize),
                      trailingIcon: _FlyoutItemTrailing(
                        shortcutLabel: item.shortcutLabel,
                        selected: item.selected,
                        iconSize: _iconSize,
                      ),
                      onPressed: () => onSelected(item),
                      child: Text(item.label),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 快捷键与选中勾分两列，各项的勾上下对齐
class _FlyoutItemTrailing extends StatelessWidget {
  const _FlyoutItemTrailing({
    required this.shortcutLabel,
    required this.selected,
    required this.iconSize,
  });

  final String? shortcutLabel;
  final bool selected;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortcutLabel = this.shortcutLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shortcutLabel != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: DesignTokens.spacingSm,
              end: DesignTokens.spacingXs,
            ),
            child: Text(
              shortcutLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        SizedBox.square(
          dimension: iconSize,
          child: selected ? Icon(Icons.check_rounded, size: iconSize) : null,
        ),
      ],
    );
  }
}

/// 侧边展开时与按钮顶对齐、放不下就整体上移；向上展开放不下时改到按钮下方
class _FlyoutLayout extends SingleChildLayoutDelegate {
  const _FlyoutLayout({
    required this.anchor,
    required this.placement,
    required this.textDirection,
    required this.gap,
    required this.panelInset,
  });

  final Rect anchor;
  final EditorToolbarFlyoutPlacement placement;
  final TextDirection textDirection;
  final double gap;

  /// 面板内边距，让首项与按钮对齐
  final double panelInset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double clampX(double x) =>
        x.clamp(0, math.max(0, size.width - childSize.width)).toDouble();
    double clampY(double y) =>
        y.clamp(0, math.max(0, size.height - childSize.height)).toDouble();
    final ltr = textDirection == TextDirection.ltr;

    switch (placement) {
      case EditorToolbarFlyoutPlacement.side:
        final x = ltr
            ? anchor.right + gap
            : anchor.left - gap - childSize.width;
        return Offset(clampX(x), clampY(anchor.top - panelInset));
      case EditorToolbarFlyoutPlacement.above:
        final x = ltr ? anchor.left : anchor.right - childSize.width;
        final above = anchor.top - gap - childSize.height;
        final y = above >= 0 ? above : clampY(anchor.bottom + gap);
        return Offset(clampX(x), y);
    }
  }

  @override
  bool shouldRelayout(_FlyoutLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      placement != oldDelegate.placement ||
      textDirection != oldDelegate.textDirection ||
      gap != oldDelegate.gap ||
      panelInset != oldDelegate.panelInset;
}
