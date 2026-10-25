import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'raster_cache_layer.dart';

/// 大块且多数时间静止的区域：邻近有动画时把它缓存成像素对齐的纹理，视觉逐像素不变。
///
/// 内容会裁剪到自身尺寸，实时绘制与缓存回贴范围一致。
class RasterCacheBoundary extends SingleChildRenderObjectWidget {
  const RasterCacheBoundary({super.key, super.child});

  @override
  RenderRasterCacheBoundary createRenderObject(BuildContext context) =>
      RenderRasterCacheBoundary(enabled: RasterCacheScope.enabledOf(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderRasterCacheBoundary renderObject,
  ) {
    renderObject.enabled = RasterCacheScope.enabledOf(context);
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
  RenderRasterCacheBoundary({bool enabled = true, RenderBox? child})
    : _enabled = enabled,
      super(child);

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsCompositedLayerUpdate();
  }

  Rect get _contentBounds => Offset.zero & size;

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({
    required covariant RasterCacheLayer? oldLayer,
  }) => (oldLayer ?? RasterCacheLayer())..enabled = _enabled;

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _contentBounds;

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
    properties.add(
      FlagProperty('enabled', value: _enabled, ifFalse: 'disabled'),
    );
  }
}
