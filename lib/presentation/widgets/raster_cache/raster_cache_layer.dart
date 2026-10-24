import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'raster_cache_geometry.dart';
import 'raster_cache_promotion.dart';

/// 子树稳定时用像素对齐的快照代替逐帧重放，子树或位置一变立即退回实时绘制。
///
/// Impeller 没有光栅缓存，相邻区域有动画时整窗静态内容每帧都要重放一遍。
/// 祖先若以不同 pixelRatio 调用 layer.toImage，快照会被最近邻缩放；应用内没有此类调用。
class RasterCacheLayer extends OffsetLayer {
  RasterCacheLayer({RasterCachePromotionPolicy? policy})
    : _policy = policy ?? RasterCachePromotionPolicy();

  static const int maxDimension = 8192;
  static const int maxPixels = 3840 * 2160 * 2;

  final RasterCachePromotionPolicy _policy;
  final LayerHandle<_RasterCacheContentLayer> _contentHandle = LayerHandle(
    _RasterCacheContentLayer(),
  );

  _RasterCacheSnapshot? _snapshot;
  Rect _contentBounds = Rect.zero;
  bool _enabled = true;
  bool _blockedUntilContentChanges = false;
  bool _frameCallbackScheduled = false;
  bool _disposed = false;
  int _stableFrames = 0;

  /// 渲染对象把全部内容画进这一层，它的重新入场就是内容变化的信号。
  ContainerLayer get content => _contentHandle.layer!;

  @visibleForTesting
  bool get isCached => _snapshot != null;

  @visibleForTesting
  RasterCachePromotionPolicy get policy => _policy;

  set contentBounds(Rect value) => _contentBounds = value;

  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (value) {
      _scheduleFrameCallback();
    } else if (_snapshot != null) {
      markNeedsAddToScene();
    }
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final snapshot = _snapshot;
    if (snapshot != null) {
      if (_canKeep(snapshot)) {
        snapshot.displayedFrames += 1;
        engineLayer = builder.pushOffset(
          offset.dx,
          offset.dy,
          oldLayer: engineLayer as ui.OffsetEngineLayer?,
        );
        builder.addPicture(Offset.zero, snapshot.picture);
        builder.pop();
        _scheduleFrameCallback();
        return;
      }
      _evict();
    } else {
      _blockedUntilContentChanges = false;
    }
    _stableFrames = 0;
    super.addToScene(builder);
    _scheduleFrameCallback();
  }

  bool _canKeep(_RasterCacheSnapshot snapshot) {
    if (!_enabled) return false;
    final transform = _contentTransform();
    if (transform == null ||
        !transform.isWholePixelShiftOf(snapshot.geometry.transform)) {
      return false;
    }
    return !_contentChangedSinceSnapshot();
  }

  // 内容层干净时框架只会 addRetained，不调用它的 addToScene。
  bool _contentChangedSinceSnapshot() {
    final contentLayer = _contentHandle.layer!..addedToScene = false;
    final probe = ui.SceneBuilder();
    addChildrenToScene(probe);
    probe.build().dispose();
    return contentLayer.addedToScene;
  }

  void _scheduleFrameCallback() {
    if (_frameCallbackScheduled || _disposed) return;
    _frameCallbackScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(
      _onFrameCompleted,
      debugLabel: 'RasterCacheLayer.frame',
    );
  }

  void _onFrameCompleted(Duration _) {
    _frameCallbackScheduled = false;
    if (_disposed) return;
    if (!attached) {
      // 旧 engine layer 仍引用快照；不标脏的话重新挂上时会被原样 addRetained。
      if (_snapshot != null) markNeedsAddToScene();
      _evict(recordEviction: false);
      return;
    }
    if (_snapshot != null) {
      // 下一帧重新入场才能校验祖先位移和内容变化。
      markNeedsAddToScene();
      return;
    }
    if (!_enabled || _blockedUntilContentChanges) return;
    _stableFrames += 1;
    if (_stableFrames < _policy.stableFramesRequired) {
      _scheduleFrameCallback();
      return;
    }
    _promote();
  }

  void _promote() {
    final contentLayer = _contentHandle.layer!;
    if (!_isRasterizable(contentLayer)) {
      _blockedUntilContentChanges = true;
      return;
    }
    final transform = _contentTransform();
    final geometry = transform == null
        ? null
        : RasterCacheGeometry.tryCreate(
            contentBounds: _contentBounds,
            transform: transform,
            maxDimension: maxDimension,
            maxPixels: maxPixels,
          );
    if (geometry == null) {
      _policy.recordRejectedAttempt();
      _stableFrames = 0;
      _scheduleFrameCallback();
      return;
    }
    final image = _rasterize(geometry);
    _snapshot = _RasterCacheSnapshot(
      geometry: geometry,
      image: image,
      picture: _recordPicture(image, geometry),
    );
    contentLayer.addedToScene = false;
    markNeedsAddToScene();
  }

  ui.Image _rasterize(RasterCacheGeometry geometry) {
    final builder = ui.SceneBuilder()
      ..pushTransform(geometry.snapshotTransform.storage);
    addChildrenToScene(builder);
    builder.pop();
    final scene = builder.build();
    try {
      return scene.toImageSync(geometry.width, geometry.height);
    } finally {
      scene.dispose();
    }
  }

  static ui.Picture _recordPicture(
    ui.Image image,
    RasterCacheGeometry geometry,
  ) {
    final recorder = ui.PictureRecorder();
    // 快照像素与屏幕像素一一对应，双线性采样会引入 1/255 的舍入差。
    Canvas(recorder).drawImageRect(
      image,
      Rect.fromLTWH(
        0,
        0,
        geometry.width.toDouble(),
        geometry.height.toDouble(),
      ),
      geometry.destination,
      Paint()..filterQuality = FilterQuality.none,
    );
    return recorder.endRecording();
  }

  DevicePixelTransform? _contentTransform() {
    final chain = <ContainerLayer>[_contentHandle.layer!, this];
    for (var ancestor = parent; ancestor != null; ancestor = ancestor.parent) {
      chain.add(ancestor);
    }
    final matrix = Matrix4.identity();
    for (var index = chain.length - 1; index > 0; index -= 1) {
      chain[index].applyTransform(chain[index - 1], matrix);
    }
    return DevicePixelTransform.fromMatrix(matrix);
  }

  // 外部纹理和平台视图在图层不变时也会换帧；背景滤镜依赖子树之外的像素。
  static bool _isRasterizable(Layer layer) {
    if (layer is TextureLayer ||
        layer is PlatformViewLayer ||
        layer is PerformanceOverlayLayer ||
        layer is BackdropFilterLayer) {
      return false;
    }
    if (layer is ContainerLayer) {
      for (
        var child = layer.firstChild;
        child != null;
        child = child.nextSibling
      ) {
        if (!_isRasterizable(child)) return false;
      }
    }
    return true;
  }

  void _evict({bool recordEviction = true}) {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    _snapshot = null;
    if (recordEviction) {
      _policy.recordEviction(displayedFrames: snapshot.displayedFrames);
    }
    snapshot.dispose();
  }

  @override
  void detach() {
    super.detach();
    // 祖先重绘时会先摘下再挂回；到帧尾仍未挂回才释放快照。
    _scheduleFrameCallback();
  }

  @override
  void dispose() {
    _disposed = true;
    _evict(recordEviction: false);
    _contentHandle.layer = null;
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('cached', value: isCached, ifTrue: 'cached'))
      ..add(FlagProperty('enabled', value: _enabled, ifFalse: 'disabled'))
      ..add(IntProperty('stableFramesRequired', _policy.stableFramesRequired));
  }
}

class _RasterCacheContentLayer extends OffsetLayer {
  bool addedToScene = false;

  @override
  void addToScene(ui.SceneBuilder builder) {
    addedToScene = true;
    super.addToScene(builder);
  }
}

class _RasterCacheSnapshot {
  _RasterCacheSnapshot({
    required this.geometry,
    required this.image,
    required this.picture,
  });

  final RasterCacheGeometry geometry;
  final ui.Image image;
  final ui.Picture picture;
  int displayedFrames = 0;

  void dispose() {
    picture.dispose();
    image.dispose();
  }
}
