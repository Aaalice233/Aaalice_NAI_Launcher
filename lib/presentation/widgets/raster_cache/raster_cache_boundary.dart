import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'raster_cache_layer.dart';

/// 大块且多数时间静止的区域：邻近有动画时把它缓存成像素对齐的纹理，视觉逐像素不变。
///
/// 内容会裁剪到自身尺寸加 [paintOverflow]，实时绘制与缓存回贴范围一致；
/// 阴影或悬停放大会画出边界时用它声明余量。
class RasterCacheBoundary extends SingleChildRenderObjectWidget {
  const RasterCacheBoundary({
    super.key,
    this.paintOverflow = EdgeInsets.zero,
    super.child,
  });

  final EdgeInsets paintOverflow;

  @override
  RenderRasterCacheBoundary createRenderObject(BuildContext context) =>
      RenderRasterCacheBoundary(
        enabled: RasterCacheScope.enabledOf(context),
        paintOverflow: paintOverflow,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderRasterCacheBoundary renderObject,
  ) {
    renderObject
      ..enabled = RasterCacheScope.enabledOf(context)
      ..paintOverflow = paintOverflow;
  }
}

/// 统一开关子树内的 [RasterCacheBoundary]，用于诊断对比；默认开启。
class RasterCacheScope extends InheritedWidget {
  const RasterCacheScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RasterCacheScope>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(RasterCacheScope oldWidget) =>
      oldWidget.enabled != enabled;
}

class RenderRasterCacheBoundary extends RenderProxyBox {
  RenderRasterCacheBoundary({
    bool enabled = true,
    EdgeInsets paintOverflow = EdgeInsets.zero,
    RenderBox? child,
  }) : _enabled = enabled,
       _paintOverflow = paintOverflow,
       super(child);

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsCompositedLayerUpdate();
  }

  EdgeInsets get paintOverflow => _paintOverflow;
  EdgeInsets _paintOverflow;
  set paintOverflow(EdgeInsets value) {
    if (_paintOverflow == value) return;
    _paintOverflow = value;
    markNeedsPaint();
  }

  Rect get _contentBounds => _paintOverflow.inflateRect(Offset.zero & size);

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({
    required covariant RasterCacheLayer? oldLayer,
  }) => (oldLayer ?? RasterCacheLayer())..enabled = _enabled;

  @override
  Rect get paintBounds => _contentBounds;

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _contentBounds;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_contentBounds.contains(position)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      _clipLayer.layer = null;
      return;
    }
    final layer = this.layer! as RasterCacheLayer;
    final bounds = _contentBounds;
    layer.contentBounds = bounds.shift(offset);
    context.pushLayer(layer.content, (context, offset) {
      _clipLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        bounds,
        super.paint,
        oldLayer: _clipLayer.layer,
      );
    }, offset);
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('enabled', value: _enabled, ifFalse: 'disabled'))
      ..add(DiagnosticsProperty<EdgeInsets>('paintOverflow', _paintOverflow));
  }
}
