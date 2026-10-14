import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/hard_edge_mask_exporter.dart';
import '../core/history_manager.dart';
import '../core/mask_paint_style.dart';
import '../core/stroke_rendering.dart';
import 'layer_raster.dart';
import 'layer_role.dart';
import 'model3d_layer_data.dart';

/// 画布调整模式
enum CanvasResizeMode {
  /// 裁剪模式：画布变小时裁剪内容，变大时保持内容位置
  crop,

  /// 填充模式：保持内容位置，画布变化不影响内容位置
  pad,

  /// 拉伸模式：缩放内容以适应新画布尺寸
  stretch,
}

extension CanvasResizeModeExtension on CanvasResizeMode {
  String get label {
    switch (this) {
      case CanvasResizeMode.crop:
        return 'Crop';
      case CanvasResizeMode.pad:
        return 'Pad';
      case CanvasResizeMode.stretch:
        return 'Stretch';
    }
  }
}

/// 图层混合模式
enum LayerBlendMode {
  normal,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
}

extension LayerBlendModeExtension on LayerBlendMode {
  /// 转换为字符串（用于序列化）
  String get stringValue => name;

  /// 从字符串解析（用于反序列化）
  static LayerBlendMode fromString(String value) {
    return LayerBlendMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LayerBlendMode.normal,
    );
  }

  BlendMode toFlutterBlendMode() {
    switch (this) {
      case LayerBlendMode.normal:
        return BlendMode.srcOver;
      case LayerBlendMode.multiply:
        return BlendMode.multiply;
      case LayerBlendMode.screen:
        return BlendMode.screen;
      case LayerBlendMode.overlay:
        return BlendMode.overlay;
      case LayerBlendMode.darken:
        return BlendMode.darken;
      case LayerBlendMode.lighten:
        return BlendMode.lighten;
      case LayerBlendMode.colorDodge:
        return BlendMode.colorDodge;
      case LayerBlendMode.colorBurn:
        return BlendMode.colorBurn;
      case LayerBlendMode.hardLight:
        return BlendMode.hardLight;
      case LayerBlendMode.softLight:
        return BlendMode.softLight;
      case LayerBlendMode.difference:
        return BlendMode.difference;
      case LayerBlendMode.exclusion:
        return BlendMode.exclusion;
    }
  }
}

/// 图层内容快照（底图、偏移、笔画），供撤销在同步阶段整体恢复
class LayerContentSnapshot {
  /// [baseImage] 的所有权移交给快照，由 [dispose] 释放
  LayerContentSnapshot({
    ui.Image? baseImage,
    Uint8List? baseImageBytes,
    Offset baseImageOffset = Offset.zero,
    List<StrokeData> strokes = const [],
  }) : this.shared(
         baseRaster: baseImage == null
             ? null
             : LayerRaster(baseImage, bytes: baseImageBytes),
         baseImageOffset: baseImageOffset,
         strokes: strokes,
       );

  /// 快照占用 [baseRaster] 的一份持有，由 [dispose] 归还
  LayerContentSnapshot.shared({
    LayerRaster? baseRaster,
    this.baseImageOffset = Offset.zero,
    List<StrokeData> strokes = const [],
  }) : _baseRaster = baseRaster,
       strokes = List.unmodifiable(strokes);

  const LayerContentSnapshot.empty()
    : _baseRaster = null,
      baseImageOffset = Offset.zero,
      strokes = const [];

  final LayerRaster? _baseRaster;
  final Offset baseImageOffset;
  final List<StrokeData> strokes;

  bool get hasBaseImage => _baseRaster != null;

  Uint8List? get baseImageBytes => _baseRaster?.bytes;

  /// 为恢复出的图层另占一份底图
  LayerRaster? retainBaseRaster() => _baseRaster?.retain();

  void dispose() {
    _baseRaster?.release();
  }
}

/// 拖动中的预览，只影响屏幕绘制，提交前不改动图层数据
sealed class LayerPreview {
  const LayerPreview();

  /// 预览时屏幕上的绘制范围
  Rect affectedBounds(Rect contentBounds);
}

/// 平移预览：从图层现有像素里挪动一部分或全部
final class LayerMovePreview extends LayerPreview {
  /// 整层平移
  LayerMovePreview.whole(this.offset) : region = null, _remainder = null;

  /// 只平移 [region] 内的像素；[extent] 需覆盖图层内容与区域
  LayerMovePreview.region(Path this.region, this.offset, Rect extent)
    : _remainder = Path.combine(
        PathOperation.difference,
        Path()..addRect(extent.expandToInclude(region.getBounds()).inflate(1)),
        region,
      );

  final Path? region;
  final Offset offset;
  final Path? _remainder;

  LayerMovePreview withOffset(Offset next) {
    final selected = region;
    if (selected == null) return LayerMovePreview.whole(next);
    return LayerMovePreview._(selected, next, _remainder);
  }

  LayerMovePreview._(this.region, this.offset, this._remainder);

  @override
  Rect affectedBounds(Rect contentBounds) {
    final selected = region;
    if (selected == null) return contentBounds.shift(offset);
    return contentBounds.expandToInclude(selected.getBounds().shift(offset));
  }
}

/// 自由变换预览：图层现有像素不参与绘制，由 [paintPixels] 画出变换后的像素
final class LayerTransformPreview extends LayerPreview {
  const LayerTransformPreview({
    required this.bounds,
    required this.paintPixels,
  });

  final Rect bounds;
  final void Function(Canvas canvas, Paint paint) paintPixels;

  @override
  Rect affectedBounds(Rect contentBounds) => bounds;
}

/// 图层类
class Layer {
  /// 图层ID
  final String id;

  /// 图层名称
  String name;

  /// 活动状态通知器（仅此图层是否为活动图层）
  /// 用于精确重建：切换图层时仅通知相关的 2 个图层，而非所有图层
  final ValueNotifier<bool> isActiveNotifier = ValueNotifier(false);

  /// 是否可见
  bool visible;

  /// 是否锁定
  bool locked;

  /// 不透明度 (0.0 - 1.0)
  double opacity;

  /// 混合模式
  LayerBlendMode blendMode;

  /// 重绘会话里决定图层进入底图还是蒙版；编辑模式恒为图片层
  LayerRole role;

  /// 内容每变一次加一，用来判断底图是否被改过
  int _contentRevision = 0;
  int get contentRevision => _contentRevision;

  LayerPreview? _preview;
  LayerPreview? get preview => _preview;

  /// 笔画列表
  final List<StrokeData> _strokes = [];
  List<StrokeData> get strokes => List.unmodifiable(_strokes);

  /// 图层底图
  LayerRaster? _base;
  ui.Image? get baseImage => _base?.image;

  /// 底图的 PNG 字节；同步写回的底图没有现成字节，需要时用 [resolveBaseImageBytes]
  Uint8List? get baseImageBytes => _base?.bytes;
  Offset _baseImageOffset = Offset.zero;
  Offset get baseImageOffset => _baseImageOffset;

  /// 底图叠上前 [_flattenedStrokeCount] 笔后的文档分辨率像素，覆盖 [_flattenedBounds]。
  /// 屏幕上只贴这张图：Impeller 没有光栅缓存，矢量笔画会每帧按屏幕尺寸重新绘制
  ui.Image? _flattened;
  Rect _flattenedBounds = Rect.zero;
  int _flattenedStrokeCount = 0;

  /// 缓存图在本设备上绘制失败过，之后一律直接绘制
  bool _flattenUnsupported = false;

  /// 超出后不建缓存、直接绘制，避免超过 GPU 纹理上限
  static const int _maxCacheExtent = 8192;

  /// 缩略图
  ui.Image? _thumbnail;
  ui.Image? get thumbnail => _thumbnail;

  /// 是否需要更新缩略图
  bool _needsThumbnailUpdate = true;
  bool get needsThumbnailUpdate => _needsThumbnailUpdate;
  Rect? _thumbnailRegion;

  // 异步渲染回来时图层可能已释放，结果无人持有，须当场丢弃
  bool _disposed = false;

  /// 图层边界（用于空间剔除优化）
  /// 当笔画或基础图像变化时需要更新
  Rect? _bounds;

  /// 图层边界（缓存值，用于空间剔除优化）
  /// 如果图层与视口不相交，则可以跳过渲染
  Rect? get bounds => _bounds;

  /// 文档坐标中的内容外接矩形（含笔刷半径与柔边），无内容时为空矩形
  Rect get contentBounds => _bounds ??= _calculateBounds();

  /// 3D 模型图层元数据(null = 普通图层)
  Model3dLayerData? model3d;

  Layer({
    String? id,
    this.name = 'New Layer',
    this.visible = true,
    this.locked = false,
    this.opacity = 1.0,
    this.blendMode = LayerBlendMode.normal,
    this.role = LayerRole.image,
  }) : id = id ?? const Uuid().v4();

  bool get isMask => role == LayerRole.mask;

  /// 是否有基础图像
  bool get hasBaseImage => _base != null;

  /// 是否为 3D 模型图层
  bool get hasModel3d => model3d != null;

  /// 是否有内容
  bool get hasContent => _base != null || _strokes.isNotEmpty;

  /// 底图的 PNG 字节，尚未编码时现编并缓存；没有底图时为 null
  Future<Uint8List?> resolveBaseImageBytes() =>
      _base?.encodePng() ?? Future<Uint8List?>.value();

  /// [origin] 是导出区域在文档中的左上角，输出为区域局部坐标；
  /// 底图尚未编码时返回 null，调用方应先 [resolveBaseImageBytes]
  HardEdgeMaskBaseImage? toHardEdgeBaseMask({Offset origin = Offset.zero}) {
    final bytes = _base?.bytes;
    if (bytes == null) {
      return null;
    }

    final offset = _baseImageOffset - origin;
    return HardEdgeMaskBaseImage(
      bytes: Uint8List.fromList(bytes),
      offsetX: offset.dx.round(),
      offsetY: offset.dy.round(),
    );
  }

  List<HardEdgeMaskStroke> toHardEdgeMaskStrokes({
    Offset origin = Offset.zero,
  }) {
    return _strokes.map((stroke) {
      return HardEdgeMaskStroke(
        points: stroke.points.map((point) => point - origin).toList(),
        size: stroke.size,
        isEraser: stroke.isEraser,
      );
    }).toList();
  }

  List<HardEdgeMaskOperation> toHardEdgeMaskOperations({
    bool includeBaseImage = true,
    Offset origin = Offset.zero,
  }) {
    final operations = <HardEdgeMaskOperation>[];

    if (includeBaseImage) {
      final baseMask = toHardEdgeBaseMask(origin: origin);
      if (baseMask != null) {
        operations.add(HardEdgeMaskBaseImageOperation(baseMask: baseMask));
      }
    }

    for (final stroke in toHardEdgeMaskStrokes(origin: origin)) {
      operations.add(HardEdgeMaskStrokeOperation(stroke: stroke));
    }

    return operations;
  }

  /// 设置基础图像（从导入的图片）
  ///
  /// 如果解码失败会抛出异常，调用方需要处理
  Future<void> setBaseImage(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      // 成功解码后才更新状态
      _swapBase(LayerRaster(frame.image, bytes: bytes));
      _baseImageOffset = Offset.zero;
      _invalidateFlattened();
    } catch (e) {
      AppLogger.w('Failed to decode base image: $e', 'ImageEditor');
      rethrow;
    } finally {
      codec?.dispose();
    }
  }

  /// 从 ui.Image 设置基础图像
  void setBaseImageFromImage(ui.Image image) {
    _swapBase(LayerRaster(image));
    _baseImageOffset = Offset.zero;
    _invalidateFlattened();
  }

  /// 同步替换底图，接管 [raster] 的一份持有
  void setBaseRaster(LayerRaster raster, {Offset offset = Offset.zero}) {
    _swapBase(raster);
    _baseImageOffset = offset;
    _invalidateFlattened();
  }

  /// 快照与图层共用底图，调用者负责释放快照
  LayerContentSnapshot captureContent() {
    return LayerContentSnapshot.shared(
      baseRaster: _base?.retain(),
      baseImageOffset: _baseImageOffset,
      strokes: _strokes,
    );
  }

  /// 恢复为快照内容；快照本身不被消费，可重复用于撤销/重做
  void restoreContent(LayerContentSnapshot snapshot) {
    _swapBase(snapshot.retainBaseRaster());
    _baseImageOffset = snapshot.baseImageOffset;
    _strokes
      ..clear()
      ..addAll(snapshot.strokes);
    _invalidateFlattened();
  }

  /// 清除基础图像
  void clearBaseImage() {
    _swapBase(null);
    _baseImageOffset = Offset.zero;
    _invalidateFlattened();
  }

  /// 新底图的持有先到位再归还旧的，两者是同一份时不会被提前释放
  void _swapBase(LayerRaster? next) {
    final previous = _base;
    _base = next;
    previous?.release();
  }

  void setBaseImageOffset(Offset offset) {
    _baseImageOffset = offset;
    _invalidateFlattened();
  }

  /// 平移全部内容；整数位移直接挪动已有缓存，避免重新烘焙
  void translateContent(Offset delta) {
    if (delta == Offset.zero) return;
    if (_strokes.isNotEmpty) {
      final moved = [
        for (final stroke in _strokes)
          stroke.copyWith(
            points: [for (final point in stroke.points) point + delta],
          ),
      ];
      _strokes
        ..clear()
        ..addAll(moved);
    }
    _baseImageOffset += delta;

    final isIntegral =
        delta.dx == delta.dx.roundToDouble() &&
        delta.dy == delta.dy.roundToDouble();
    if (!isIntegral) {
      _invalidateFlattened();
      return;
    }
    _contentRevision++;
    _needsThumbnailUpdate = true;
    _flattenedBounds = _flattenedBounds.shift(delta);
    _bounds = _bounds?.shift(delta);
  }

  void setPreview(LayerPreview? preview) {
    _preview = preview;
  }

  /// 内容变了但缓存仍对得上：后续笔画在下次绘制时增量叠进缓存
  void _markStrokesChanged() {
    _contentRevision++;
    _needsThumbnailUpdate = true;
    _bounds = null;
  }

  /// 缓存里的像素不再成立，下次绘制时从底图起整体重建
  void _invalidateFlattened() {
    _markStrokesChanged();
    _flattened?.dispose();
    _flattened = null;
    _flattenedStrokeCount = 0;
  }

  void _drawBaseImage(Canvas canvas, Paint paint) {
    final base = _base;
    if (base == null) {
      return;
    }

    canvas.drawImage(base.image, _baseImageOffset, paint);
  }

  /// 添加笔画
  void addStroke(StrokeData stroke) {
    _strokes.add(stroke);
    _markStrokesChanged();
  }

  /// 移除最后一个笔画
  StrokeData? removeLastStroke() {
    if (_strokes.isEmpty) return null;

    final stroke = _strokes.removeLast();
    if (_flattenedStrokeCount > _strokes.length) {
      // 这一笔已压进缓存，像素无法单独扣除
      _invalidateFlattened();
    } else {
      _markStrokesChanged();
    }
    return stroke;
  }

  /// 清除所有笔画
  List<StrokeData> clearStrokes() {
    final oldStrokes = List<StrokeData>.from(_strokes);
    _strokes.clear();
    _invalidateFlattened();
    return oldStrokes;
  }

  bool get _hasLayerEffects =>
      opacity < 1.0 || blendMode != LayerBlendMode.normal;

  Paint _layerPaint(FilterQuality filterQuality) {
    final paint = Paint()..filterQuality = filterQuality;
    if (opacity < 1.0) {
      paint.color = Color.fromRGBO(255, 255, 255, opacity);
    }
    if (blendMode != LayerBlendMode.normal) {
      paint.blendMode = blendMode.toFlutterBlendMode();
    }
    return paint;
  }

  /// 以文档坐标绘制图层内容，带上图层的不透明度与混合模式
  void render(Canvas canvas, {FilterQuality filterQuality = FilterQuality.none}) {
    if (!visible) return;
    _drawPixels(canvas, _layerPaint(filterQuality));
  }

  /// 用 [paint] 贴出图层像素：有笔画时贴缓存图，只有底图时直接贴底图
  void _drawPixels(Canvas canvas, Paint paint) {
    final flattened = _flattenedImage();
    if (flattened != null) {
      try {
        canvas.drawImage(flattened, _flattenedBounds.topLeft, paint);
        return;
      } on ui.PictureRasterizationException catch (e) {
        // toImageSync 失败（如超出设备纹理上限）要到再次绘制时才以异常暴露
        AppLogger.w('Layer cache unavailable: ${e.message}', 'ImageEditor');
        _flattenUnsupported = true;
        _flattened?.dispose();
        _flattened = null;
        _flattenedStrokeCount = 0;
      }
    }
    _drawDirect(canvas, paint);
  }

  /// 不经缓存直接绘制；笔画在独立图层里画，橡皮擦只擦到本图层的像素
  void _drawDirect(Canvas canvas, Paint paint) {
    if (_strokes.isEmpty) {
      _drawBaseImage(canvas, paint);
      return;
    }

    final bounds = contentBounds;
    canvas.saveLayer(bounds.isEmpty ? null : bounds, paint);
    _drawBaseImage(canvas, Paint()..filterQuality = paint.filterQuality);
    for (final stroke in _strokes) {
      _drawStroke(canvas, stroke);
    }
    canvas.restore();
  }

  /// 把还没压进缓存的笔画叠进去；只有底图、内容超限或缓存不可用时返回 null
  ui.Image? _flattenedImage() {
    if (_strokes.isEmpty || _flattenUnsupported) return null;

    final cached = _flattened;
    if (cached != null && _flattenedStrokeCount == _strokes.length) {
      return cached;
    }
    final bounds = _cacheRectFor(contentBounds);
    if (bounds == null) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(-bounds.left, -bounds.top);
    // 先用透明色清除整个画布，避免显示 GPU 垃圾数据
    canvas.drawRect(
      bounds,
      Paint()
        ..color = const Color(0x00000000)
        ..blendMode = BlendMode.src,
    );
    // 缓存已含底图和前面的笔画，橡皮擦叠在上面照样擦得掉
    if (cached == null) {
      _drawBaseImage(canvas, Paint());
    } else {
      canvas.drawImage(cached, _flattenedBounds.topLeft, Paint());
    }
    final firstPending = cached == null ? 0 : _flattenedStrokeCount;
    for (var i = firstPending; i < _strokes.length; i++) {
      _drawStroke(canvas, _strokes[i]);
    }

    final picture = recorder.endRecording();
    try {
      _flattened = picture.toImageSync(
        bounds.width.toInt(),
        bounds.height.toInt(),
      );
    } finally {
      picture.dispose();
    }
    cached?.dispose();
    _flattenedBounds = bounds;
    _flattenedStrokeCount = _strokes.length;
    return _flattened;
  }

  @visibleForTesting
  int get debugFlattenedStrokeCount => _flattenedStrokeCount;

  @visibleForTesting
  Rect? get debugFlattenedBounds => _flattened == null ? null : _flattenedBounds;

  /// 按屏幕显示的样子绘制，优先使用缓存；移动预览只在这里生效。
  /// [pixelScale] 是文档到设备像素的缩放；[liveStroke] 是正在画进本层的一笔，只对蒙版层生效
  void renderWithCache(
    Canvas canvas, {
    Rect? viewportBounds,
    FilterQuality filterQuality = FilterQuality.none,
    double pixelScale = 1,
    StrokeData? liveStroke,
  }) {
    if (isMask) {
      renderMaskOverlay(
        canvas,
        [this],
        viewportBounds: viewportBounds,
        filterQuality: filterQuality,
        pixelScale: pixelScale,
        liveStroke: liveStroke,
        liveLayerId: id,
      );
      return;
    }
    if (!visible) return;

    final preview = _preview;
    final bounds = _displayBounds(null);
    // 空间剔除优化：放大查看局部时跳过不在视口内的图层
    if (viewportBounds != null && !bounds.overlaps(viewportBounds)) {
      return;
    }

    if (preview == null) {
      _drawPixels(canvas, _layerPaint(filterQuality));
      return;
    }

    // 预览分块绘制，不透明度与混合模式要在合拢后统一施加一次
    final isolated = _hasLayerEffects;
    canvas.save();
    if (isolated) {
      canvas.saveLayer(
        bounds.isEmpty ? null : bounds,
        _layerPaint(filterQuality),
      );
    }
    _drawPreviewPixels(canvas, preview, Paint()..filterQuality = filterQuality);
    if (isolated) {
      canvas.restore();
    }
    canvas.restore();
  }

  /// 屏幕上的绘制范围：预览覆盖的区域，加上正在画进本层的一笔
  Rect _displayBounds(StrokeData? liveStroke) {
    final preview = _preview;
    final bounds = preview == null
        ? contentBounds
        : preview.affectedBounds(contentBounds);
    if (liveStroke == null) return bounds;
    final liveBounds = StrokeRendering.bounds(
      liveStroke.points,
      size: liveStroke.size,
      hardness: liveStroke.hardness,
    );
    return bounds.isEmpty ? liveBounds : bounds.expandToInclude(liveBounds);
  }

  /// 相邻蒙版层合成一层叠加色：覆盖取并集，显示透明度整组只施加一次，与导出蒙版取并集一致。
  /// [liveStroke] 是正在画进 [liveLayerId] 的一笔
  static void renderMaskOverlay(
    Canvas canvas,
    Iterable<Layer> masks, {
    Rect? viewportBounds,
    FilterQuality filterQuality = FilterQuality.none,
    double pixelScale = 1,
    StrokeData? liveStroke,
    String? liveLayerId,
  }) {
    final members = <(Layer, Rect, StrokeData?)>[];
    Rect? group;
    for (final mask in masks) {
      if (!mask.visible) continue;
      final live = mask.id == liveLayerId ? liveStroke : null;
      final bounds = mask._displayBounds(live);
      // 空间剔除优化：放大查看局部时跳过不在视口内的图层
      if (bounds.isEmpty ||
          (viewportBounds != null && !bounds.overlaps(viewportBounds))) {
        continue;
      }
      members.add((mask, bounds, live));
      group = group?.expandToInclude(bounds) ?? bounds;
    }
    if (group == null) return;

    final magnified = pixelScale > 1;
    _withMaskOverlay(canvas, group, (overlay) {
      for (final (mask, bounds, live) in members) {
        mask._paintMaskCoverage(
          overlay,
          bounds: bounds,
          viewportBounds: viewportBounds,
          filterQuality: filterQuality,
          magnified: magnified,
          liveStroke: live,
        );
      }
    });
  }

  void _paintMaskCoverage(
    Canvas canvas, {
    required Rect bounds,
    required Rect? viewportBounds,
    required FilterQuality filterQuality,
    required bool magnified,
    required StrokeData? liveStroke,
  }) {
    final sampling = magnified ? FilterQuality.none : filterQuality;
    _withMaskCoverage(canvas, bounds, magnified: magnified, () {
      final preview = _preview;
      if (preview == null) {
        _drawPixels(canvas, Paint()..filterQuality = sampling);
      } else {
        _drawPreviewPixels(canvas, preview, Paint()..filterQuality = sampling);
      }
      if (liveStroke == null) return;
      if (magnified && viewportBounds != null) {
        // 涂抹中就按落笔后的像素网格显示，松手时不会从平滑跳成方块
        StrokeRendering.drawAtDocumentResolution(
          canvas,
          liveStroke.points,
          _strokePaint(liveStroke),
          size: liveStroke.size,
          hardness: liveStroke.hardness,
          visible: viewportBounds,
          sampling: sampling,
        );
      } else {
        _drawStroke(canvas, liveStroke);
      }
    });
  }

  /// 蒙版叠加色的显示透明度只在这里施加一次
  static void _withMaskOverlay(
    Canvas canvas,
    Rect bounds,
    void Function(Canvas overlay) drawCoverage,
  ) {
    // Impeller 的 saveLayer 会沿用同一画面里前面留下的图片着色器（棋盘格）而跳过 colorFilter，嵌套 Picture 回放时画笔状态会重置
    final recorder = ui.PictureRecorder();
    final overlay = Canvas(recorder);
    overlay.saveLayer(
      bounds,
      Paint()
        ..color = const Color.fromRGBO(255, 255, 255, MaskPaintStyle.opacity),
    );
    drawCoverage(overlay);
    overlay.restore();
    final picture = recorder.endRecording();
    canvas.drawPicture(picture);
    picture.dispose();
  }

  /// 蒙版只表达哪里被覆盖：笔迹各自的透明度与重叠先归一成满覆盖，再施加本层的不透明度。
  /// [magnified] 时按真实像素取舍，和导出时“任何不透明像素都算蒙版”一致
  void _withMaskCoverage(
    Canvas canvas,
    Rect bounds,
    void Function() drawContent, {
    required bool magnified,
  }) {
    // 归一会把不透明度一并抹平，所以本层效果要包在外面单独施加
    final isolated = _hasLayerEffects;
    if (isolated) {
      canvas.saveLayer(bounds, _layerPaint(FilterQuality.none));
    }
    canvas.saveLayer(
      bounds,
      Paint()
        ..colorFilter = magnified
            ? MaskPaintStyle.exactCoverage
            : MaskPaintStyle.smoothCoverage,
    );
    drawContent();
    canvas.restore();
    if (isolated) {
      canvas.restore();
    }
  }

  void _drawPreviewPixels(Canvas canvas, LayerPreview preview, Paint paint) {
    switch (preview) {
      case LayerMovePreview():
        _drawMovedPixels(canvas, preview, paint);
      case LayerTransformPreview(:final paintPixels):
        paintPixels(canvas, paint);
    }
  }

  void _drawMovedPixels(Canvas canvas, LayerMovePreview preview, Paint paint) {
    final region = preview.region;
    if (region == null) {
      canvas.save();
      canvas.translate(preview.offset.dx, preview.offset.dy);
      _drawPixels(canvas, paint);
      canvas.restore();
      return;
    }
    canvas.save();
    canvas.clipPath(preview._remainder!);
    _drawPixels(canvas, paint);
    canvas.restore();
    canvas.save();
    canvas.translate(preview.offset.dx, preview.offset.dy);
    canvas.clipPath(region);
    _drawPixels(canvas, paint);
    canvas.restore();
  }

  /// 只画像素本身：不受可见性、不透明度与混合模式影响，烘焙后这些属性仍由图层承担
  void renderPixels(Canvas canvas) {
    _drawPixels(canvas, Paint());
  }

  /// 把图层像素中位于 [region] 的部分渲染成 [region] 大小的图像
  Future<ui.Image> renderToImage(Rect region) async {
    final picture = _recordPixels(region);
    try {
      return await picture.toImage(region.width.round(), region.height.round());
    } finally {
      picture.dispose();
    }
  }

  /// 同 [renderToImage]，结果当帧可用
  ui.Image renderToImageSync(Rect region) {
    final picture = _recordPixels(region);
    try {
      return picture.toImageSync(region.width.round(), region.height.round());
    } finally {
      picture.dispose();
    }
  }

  ui.Picture _recordPixels(Rect region) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(-region.left, -region.top);
    renderPixels(canvas);
    return recorder.endRecording();
  }

  /// 把 [picture]（所有权移交）栅格化成缓存图像；渲染期间图层已释放时丢弃结果并返回 null
  Future<ui.Image?> _renderPicture(
    ui.Picture picture,
    int width,
    int height,
  ) async {
    final ui.Image image;
    try {
      image = await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
    if (!_disposed) return image;
    image.dispose();
    return null;
  }

  /// 计算图层边界
  Rect _calculateBounds() {
    final base = _base;
    final baseBounds = base == null
        ? null
        : Rect.fromLTWH(
            _baseImageOffset.dx,
            _baseImageOffset.dy,
            base.width.toDouble(),
            base.height.toDouble(),
          );
    final strokeBounds = _calculateStrokeBounds();
    if (baseBounds == null) return strokeBounds;
    if (strokeBounds.isEmpty) return baseBounds;
    return baseBounds.expandToInclude(strokeBounds);
  }

  Rect _calculateStrokeBounds() {
    Rect? bounds;
    for (final stroke in _strokes) {
      if (stroke.points.isEmpty) {
        continue;
      }

      final strokeBounds = StrokeRendering.bounds(
        stroke.points,
        size: stroke.size,
        hardness: stroke.hardness,
      );
      bounds = bounds == null
          ? strokeBounds
          : bounds.expandToInclude(strokeBounds);
    }

    return bounds ?? Rect.zero;
  }

  /// 缓存图像覆盖的整数像素区域；过大时返回 null 表示不建缓存
  static Rect? _cacheRectFor(Rect bounds) {
    if (bounds.isEmpty) return null;
    final rect = Rect.fromLTRB(
      bounds.left.floorToDouble(),
      bounds.top.floorToDouble(),
      bounds.right.ceilToDouble(),
      bounds.bottom.ceilToDouble(),
    );
    if (rect.width > _maxCacheExtent || rect.height > _maxCacheExtent) {
      return null;
    }
    return rect;
  }

  /// 绘制单个笔画
  void _drawStroke(Canvas canvas, StrokeData stroke) {
    StrokeRendering.draw(
      canvas,
      stroke.points,
      _strokePaint(stroke),
      size: stroke.size,
      hardness: stroke.hardness,
    );
  }

  static Paint _strokePaint(StrokeData stroke) {
    final paint = Paint()
      ..color = stroke.isEraser
          ? const Color(0xFFFFFFFF) // 颜色无所谓，clear 模式会忽略
          : stroke.color.withValues(alpha: stroke.opacity);

    // 橡皮擦使用 clear 模式真正擦除像素
    if (stroke.isEraser) {
      paint.blendMode = BlendMode.clear;
    }
    return paint;
  }

  /// 缩略图展示的是 [region]（取景框）内的内容，取景框变化后也要重建
  bool needsThumbnailUpdateFor(Rect region) {
    return _needsThumbnailUpdate ||
        _thumbnail == null ||
        _thumbnailRegion != region;
  }

  /// 更新缩略图
  Future<void> updateThumbnail(Rect region, {int maxSize = 64}) async {
    if (!needsThumbnailUpdateFor(region)) return;
    if (region.isEmpty) return;

    // 计算缩略图尺寸
    final aspect = region.width / region.height;
    int thumbWidth, thumbHeight;
    if (aspect > 1) {
      thumbWidth = maxSize;
      thumbHeight = (maxSize / aspect).round();
    } else {
      thumbHeight = maxSize;
      thumbWidth = (maxSize * aspect).round();
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 缩放绘制
    final scale = thumbWidth / region.width;
    canvas.scale(scale);
    canvas.translate(-region.left, -region.top);
    // 缩小时矢量笔画比缓存图降采样清晰，细笔画不会断开
    if (visible && isMask) {
      final bounds = contentBounds;
      _withMaskOverlay(canvas, bounds, (overlay) {
        _withMaskCoverage(
          overlay,
          bounds,
          () => _drawDirect(
            overlay,
            Paint()..filterQuality = FilterQuality.medium,
          ),
          magnified: false,
        );
      });
    } else if (visible) {
      _drawDirect(canvas, _layerPaint(FilterQuality.medium));
    }

    // 新图渲染完成前旧缩略图仍在图层面板上显示，换上新图后才能释放
    final rendered = await _renderPicture(
      recorder.endRecording(),
      thumbWidth,
      thumbHeight,
    );
    if (rendered == null) return;
    _thumbnail?.dispose();
    _thumbnail = rendered;

    _needsThumbnailUpdate = false;
    _thumbnailRegion = region;
  }

  /// 标记缩略图需要更新；不透明度等绘制属性不进缓存，像素无需重建
  void markNeedsUpdate() {
    _needsThumbnailUpdate = true;
  }

  /// 完整数据（含已解码底图的独立克隆），持有者负责 [LayerData.dispose]
  LayerData toData() {
    return LayerData(
      id: id,
      name: name,
      visible: visible,
      locked: locked,
      opacity: opacity,
      blendMode: blendMode,
      role: role,
      model3d: model3d,
      content: captureContent(),
    );
  }

  /// 从数据重建图层；[data] 不被消费，可重复用于撤销/重做
  factory Layer.fromData(LayerData data) {
    final layer = Layer(
      id: data.id,
      name: data.name,
      visible: data.visible,
      locked: data.locked,
      opacity: data.opacity,
      blendMode: data.blendMode,
      role: data.role,
    );
    layer.restoreContent(data.content);
    layer.model3d = data.model3d;
    return layer;
  }

  /// 同步克隆全部内容，新图层使用新 id
  Layer clone({String? newName}) {
    final cloned = Layer(
      name: newName ?? '$name Copy',
      visible: visible,
      locked: locked,
      opacity: opacity,
      blendMode: blendMode,
      role: role,
    );
    final snapshot = captureContent();
    try {
      cloned.restoreContent(snapshot);
    } finally {
      snapshot.dispose();
    }
    cloned.model3d = model3d;
    return cloned;
  }

  /// 变换图层内容以适应新画布尺寸
  ///
  /// [oldSize] 原画布尺寸
  /// [newSize] 新画布尺寸
  /// [mode] 变换模式
  void transformContent(Size oldSize, Size newSize, CanvasResizeMode mode) {
    if (oldSize == newSize) return;
    if (_strokes.isEmpty && _base == null) return;

    switch (mode) {
      case CanvasResizeMode.crop:
      case CanvasResizeMode.pad:
        // 裁剪和填充模式：保持笔画原位置，渲染时自动裁剪
        // 不需要变换笔画坐标
        _invalidateFlattened();
        break;

      case CanvasResizeMode.stretch:
        // 拉伸模式：缩放所有笔画坐标
        final scaleX = newSize.width / oldSize.width;
        final scaleY = newSize.height / oldSize.height;
        _baseImageOffset = Offset(
          _baseImageOffset.dx * scaleX,
          _baseImageOffset.dy * scaleY,
        );

        final transformedStrokes = <StrokeData>[];
        for (final stroke in _strokes) {
          final transformedPoints = stroke.points.map((point) {
            return Offset(point.dx * scaleX, point.dy * scaleY);
          }).toList();

          transformedStrokes.add(
            stroke.copyWith(
              points: transformedPoints,
              size: stroke.size * ((scaleX + scaleY) / 2), // 平均缩放笔刷大小
            ),
          );
        }

        _strokes.clear();
        _strokes.addAll(transformedStrokes);
        _invalidateFlattened();
        break;
    }
  }

  /// 释放资源
  void dispose() {
    _disposed = true;
    _preview = null;

    // 释放通知器
    isActiveNotifier.dispose();

    // 释放图像资源
    _flattened?.dispose();
    _flattened = null;
    _swapBase(null);
    _thumbnail?.dispose();
    _thumbnail = null;

    // 清理笔画数据
    _strokes.clear();
    _baseImageOffset = Offset.zero;

    // 重置计数器和标志
    _flattenedStrokeCount = 0;
    _needsThumbnailUpdate = true;
  }
}
