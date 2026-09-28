import 'package:flutter/material.dart';

/// 把窗口全局坐标换算成 [showMenu] 可用的锚点矩形。
///
/// [showMenu] 的 position 相对最近的 Overlay，而不是窗口：应用壳层把
/// 分支 Navigator 放在自绘标题栏和主导航栏右侧，直接传手势
/// globalPosition 会让菜单整体偏移一个壳层边距。这里先换算到 overlay
/// 局部坐标再构造 1x1 锚点，放不下时的边界收拢交由 showMenu 处理。
RelativeRect contextMenuAnchorAt(BuildContext context, Offset globalPosition) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final local = overlay.globalToLocal(globalPosition);
  return RelativeRect.fromRect(
    Rect.fromLTWH(local.dx, local.dy, 1, 1),
    Offset.zero & overlay.size,
  );
}

/// 把窗口全局坐标换算到最近 Overlay 的局部坐标。
///
/// 自定义 PopupRoute 的页面铺在最近 Overlay 上，其定位坐标必须用
/// overlay 局部坐标系；边界收拢配合 [contextMenuOverlaySize]。
Offset contextMenuLocalPosition(BuildContext context, Offset globalPosition) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return overlay.globalToLocal(globalPosition);
}

/// 最近 Overlay 的尺寸；自定义菜单路由的边界收拢应基于它而非窗口。
Size contextMenuOverlaySize(BuildContext context) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return overlay.size;
}

