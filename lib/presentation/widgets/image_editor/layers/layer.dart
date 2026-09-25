import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/hard_edge_mask_exporter.dart';
import '../core/history_manager.dart';
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

/// 拖动中的平移预览，只影响屏幕绘制，松手提交前不改动图层数据
class LayerMovePreview {
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

  Rect affectedBounds(Rect contentBounds) {
    final selected = region;
    if (selected == null) return contentBounds.shift(offset);
    return contentBounds.expandToInclude(selected.getBounds().shift(offset));
  }
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

  LayerMovePreview? _movePreview;
  LayerMovePreview? get movePreview => _movePreview;

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

  /// 光栅化后的图像缓存（笔画合并后），覆盖 [_rasterBounds]
  ui.Image? _rasterizedImage;
  ui.Image? get rasterizedImage => _rasterizedImage;
  Rect _rasterBounds = Rect.zero;

  /// 合并缓存（基础图像 + 光栅化笔画），覆盖 [_compositeBounds]
  ui.Image? _compositedCache;
  ui.Image? get compositedCache => _compositedCache;
  Rect _compositeBounds = Rect.zero;

  /// 超出后不建缓存、直接绘制，避免超过 GPU 纹理上限
  static const int _maxCacheExtent = 8192;

  /// 是否需要重新光栅化
  bool _needsRasterize = true;
  bool get needsRasterize => _needsRasterize;

  /// 是否需要重新合成
  bool _needsComposite = true;

  /// 缩略图
  ui.Image? _thumbnail;
  ui.Image? get thumbnail => _thumbnail;

  /// 是否需要更新缩略图
  bool _needsThumbnailUpdate = true;
  bool get needsThumbnailUpdate => _needsThumbnailUpdate;
  Rect? _thumbnailRegion;

  /// 延迟光栅化计时器（空闲时执行）
  DateTime? _lastStrokeTime;
  static const Duration _rasterizeDelay = Duration(milliseconds: 500);

  /// 未光栅化的笔画数量阈值（超过此数量强制光栅化）
  static const int _maxPendingStrokes = 20;

  /// 已光栅化的笔画索引
  int _rasterizedStrokeCount = 0;

  /// 是否正在执行光栅化（防止并发）
  bool _isRasterizing = false;

  /// 是否正在更新合成缓存
  bool _isCompositing = false;

  /// 笔画版本号（每次笔画变化时递增，用于检测竞态）
  int _strokeGeneration = 0;

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

  /// 待处理的笔画数量
  int get pendingStrokeCount => _strokes.length - _rasterizedStrokeCount;

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

  /// 是否应该延迟光栅化
  bool get shouldDeferRasterize {
    if (_lastStrokeTime == null) return false;
    return DateTime.now().difference(_lastStrokeTime!) < _rasterizeDelay;
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
      _invalidateRasterState();
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
    _invalidateRasterState();
  }

  /// 同步替换底图，接管 [raster] 的一份持有
  void setBaseRaster(LayerRaster raster, {Offset offset = Offset.zero}) {
    _swapBase(raster);
    _baseImageOffset = offset;
    _invalidateRasterState();
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
    _strokeGeneration++;
    _invalidateRasterState();
  }

  /// 清除基础图像
  void clearBaseImage() {
    _swapBase(null);
    _baseImageOffset = Offset.zero;
    _invalidateRasterState();
  }

  /// 新底图的持有先到位再归还旧的，两者是同一份时不会被提前释放
  void _swapBase(LayerRaster? next) {
    final previous = _base;
    _base = next;
    previous?.release();
  }

  void setBaseImageOffset(Offset offset) {
    _baseImageOffset = offset;
    _invalidateRasterState();
  }

  /// 平移全部内容；整数位移直接挪动已有缓存，避免重新光栅化
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
    _strokeGeneration++;

    final isIntegral =
        delta.dx == delta.dx.roundToDouble() &&
        delta.dy == delta.dy.roundToDouble();
    if (!isIntegral || _isRasterizing || _isCompositing) {
      _invalidateRasterState();
      return;
    }
    _contentRevision++;
    _rasterBounds = _rasterBounds.shift(delta);
    _compositeBounds = _compositeBounds.shift(delta);
    _bounds = _bounds?.shift(delta);
    _needsThumbnailUpdate = true;
  }

  void setMovePreview(LayerMovePreview? preview) {
    _movePreview = preview;
  }

  void _invalidateRasterState() {
    _contentRevision++;
    _rasterizedStrokeCount = 0;
    _needsRasterize = true;
    _needsComposite = true;
    _needsThumbnailUpdate = true;
    _bounds = null;

    if (!_isRasterizing) {
      _rasterizedImage?.dispose();
      _rasterizedImage = null;
    }
    if (!_isCompositing) {
      _compositedCache?.dispose();
      _compositedCache = null;
    }
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
    _contentRevision++;
    _strokeGeneration++; // 递增版本号
    _lastStrokeTime = DateTime.now();
    _needsRasterize = true;
    _needsComposite = true;
    _needsThumbnailUpdate = true;
    _bounds = null; // 清除边界缓存，下次渲染时重新计算

    // 如果待处理笔画过多，标记需要强制光栅化
    if (pendingStrokeCount > _maxPendingStrokes) {
      _needsRasterize = true;
    }
  }

  /// 内部添加笔画（用于批量操作，不设置标志）
  /// 调用者负责在批量操作结束后设置标志
  void addStrokeInternal(StrokeData stroke) {
    _strokes.add(stroke);
    _contentRevision++;
    _strokeGeneration++; // 递增版本号
    _needsRasterize = true;
    _needsComposite = true;
    _needsThumbnailUpdate = true;
    _bounds = null; // 清除边界缓存
  }

  /// 移除最后一个笔画
  ///
  /// 注意：通过 _strokeGeneration 版本号机制避免与 rasterize() 的竞态条件。
  StrokeData? removeLastStroke() {
    if (_strokes.isEmpty) return null;

    // 在移除前检查该笔画是否已光栅化
    final wasRasterized = _rasterizedStrokeCount >= _strokes.length;
    final stroke = _strokes.removeLast();
    _contentRevision++;
    _strokeGeneration++; // 递增版本号，使正在进行的光栅化失效

    if (wasRasterized) {
      // 需要重新光栅化所有内容
      _rasterizedStrokeCount = 0;
      if (!_isRasterizing) {
        // 只有在不光栅化时才立即清除缓存
        // 如果正在光栅化，版本号变化会让 rasterize() 完成时不更新计数
        _rasterizedImage?.dispose();
        _rasterizedImage = null;
        _compositedCache?.dispose();
        _compositedCache = null;
      }
    }

    _needsRasterize = true; // 总是标记需要重新光栅化
    _needsComposite = true;
    _needsThumbnailUpdate = true;
    _bounds = null; // 清除边界缓存
    return stroke;
  }

  /// 清除所有笔画
  List<StrokeData> clearStrokes() {
    final oldStrokes = List<StrokeData>.from(_strokes);
    _strokes.clear();
    _contentRevision++;
    _strokeGeneration++; // 递增版本号
    _rasterizedStrokeCount = 0;
    _needsRasterize = true;
    _needsComposite = true;
    _needsThumbnailUpdate = true;
    _bounds = null; // 清除边界缓存
    if (!_isRasterizing) {
      _rasterizedImage?.dispose();
      _rasterizedImage = null;
      _compositedCache?.dispose();
      _compositedCache = null;
    }
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

  /// 以文档坐标绘制图层内容
  void render(Canvas canvas, {FilterQuality filterQuality = FilterQuality.none}) {
    if (!visible) return;
    _renderContent(
      canvas,
      filterQuality: filterQuality,
      layerPaint: _layerPaint(filterQuality),
    );
  }

  /// [layerPaint] 为 null 表示不透明度与混合模式已由调用方的 saveLayer 承担
  void _renderContent(
    Canvas canvas, {
    required FilterQuality filterQuality,
    Paint? layerPaint,
  }) {
    canvas.save();

    final imagePaint = Paint()..filterQuality = filterQuality;

    // BlendMode.clear 需要在隔离的 saveLayer 中绘制，否则会擦穿到下层。
    // 当存在 baseImage 时，已光栅化的 eraser 也需要 saveLayer，
    // 因为 rasterizedImage 是在透明画布上绘制的，clear 对透明像素无效。
    final hasEraserInPending = _strokes
        .skip(_rasterizedStrokeCount)
        .any((s) => s.isEraser);
    final hasAnyEraser = _strokes.any((s) => s.isEraser);
    final eraserNeedsSaveLayer =
        hasEraserInPending || (hasAnyEraser && _base != null);

    final appliesLayerPaint = layerPaint != null && _hasLayerEffects;
    final needsLayer = appliesLayerPaint || eraserNeedsSaveLayer;
    if (needsLayer) {
      final layerBounds = contentBounds;
      canvas.saveLayer(
        layerBounds.isEmpty ? null : layerBounds,
        layerPaint ?? imagePaint,
      );
    }

    // 优先使用合成缓存
    if (_compositedCache != null && !_needsComposite) {
      canvas.drawImage(
        _compositedCache!,
        _compositeBounds.topLeft,
        imagePaint,
      );
    } else if (hasAnyEraser && _base != null) {
      // eraser + baseImage: 必须在 saveLayer 中先绘制 base 再绘制全部笔画，
      // 这样 BlendMode.clear 才能正确擦除 base 的像素。
      _drawBaseImage(canvas, imagePaint);
      for (final stroke in _strokes) {
        _drawStroke(canvas, stroke);
      }
    } else {
      // 绘制基础图像
      _drawBaseImage(canvas, imagePaint);

      // 使用光栅化缓存绘制已处理的笔画
      if (_rasterizedImage != null && _rasterizedStrokeCount > 0) {
        canvas.drawImage(
          _rasterizedImage!,
          _rasterBounds.topLeft,
          imagePaint,
        );
      }

      // 绘制未光栅化的笔画
      for (int i = _rasterizedStrokeCount; i < _strokes.length; i++) {
        _drawStroke(canvas, _strokes[i]);
      }
    }

    if (needsLayer) {
      canvas.restore();
    }

    canvas.restore();
  }

  /// 使用缓存渲染（优先使用缓存，性能更好）；移动预览只在这里生效
  void renderWithCache(
    Canvas canvas, {
    Rect? viewportBounds,
    FilterQuality filterQuality = FilterQuality.none,
  }) {
    if (!visible) return;

    final preview = _movePreview;
    final bounds = preview == null
        ? contentBounds
        : preview.affectedBounds(contentBounds);
    // 空间剔除优化：放大查看局部时跳过不在视口内的图层
    if (viewportBounds != null && !bounds.overlaps(viewportBounds)) {
      return;
    }

    if (preview == null) {
      _drawCachedOrRender(
        canvas,
        filterQuality: filterQuality,
        layerPaint: _layerPaint(filterQuality),
      );
      return;
    }

    // 预览分两块绘制，不透明度与混合模式要在合拢后统一施加一次
    final isolated = _hasLayerEffects;
    canvas.save();
    if (isolated) {
      canvas.saveLayer(
        bounds.isEmpty ? null : bounds,
        _layerPaint(filterQuality),
      );
    }
    final region = preview.region;
    if (region == null) {
      canvas.translate(preview.offset.dx, preview.offset.dy);
      _drawCachedOrRender(canvas, filterQuality: filterQuality);
    } else {
      canvas.save();
      canvas.clipPath(preview._remainder!);
      _drawCachedOrRender(canvas, filterQuality: filterQuality);
      canvas.restore();
      canvas.save();
      canvas.translate(preview.offset.dx, preview.offset.dy);
      canvas.clipPath(region);
      _drawCachedOrRender(canvas, filterQuality: filterQuality);
      canvas.restore();
    }
    if (isolated) {
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawCachedOrRender(
    Canvas canvas, {
    required FilterQuality filterQuality,
    Paint? layerPaint,
  }) {
    final cache = _compositedCache;
    if (cache != null && !_needsComposite) {
      canvas.drawImage(
        cache,
        _compositeBounds.topLeft,
        layerPaint ?? (Paint()..filterQuality = filterQuality),
      );
      return;
    }
    _renderContent(
      canvas,
      filterQuality: filterQuality,
      layerPaint: layerPaint,
    );
  }

  /// 只画像素本身：不受可见性、不透明度与混合模式影响，烘焙后这些属性仍由图层承担
  void renderPixels(Canvas canvas) {
    _renderContent(canvas, filterQuality: FilterQuality.none);
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

      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = double.negativeInfinity;
      double maxY = double.negativeInfinity;
      for (final point in stroke.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }

      // 软笔刷的模糊光晕约延伸 3 个 sigma，缓存必须把它包进去
      final blurSigma = stroke.hardness < 1.0
          ? stroke.size * (1.0 - stroke.hardness) * 0.5
          : 0.0;
      final extent = stroke.size / 2 + blurSigma * 3;
      final strokeBounds = Rect.fromLTRB(
        minX - extent,
        minY - extent,
        maxX + extent,
        maxY + extent,
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
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isEraser
          ? const Color(0xFFFFFFFF) // 颜色无所谓，clear 模式会忽略
          : stroke.color.withValues(alpha: stroke.opacity)
      ..strokeWidth = stroke.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // 橡皮擦使用 clear 模式真正擦除像素
    if (stroke.isEraser) {
      paint.blendMode = BlendMode.clear;
    }

    // 应用硬度（通过MaskFilter模拟）
    if (stroke.hardness < 1.0) {
      final sigma = stroke.size * (1.0 - stroke.hardness) * 0.5;
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    }

    if (stroke.points.length == 1) {
      // 单点绘制圆形
      canvas.drawCircle(
        stroke.points.first,
        stroke.size / 2,
        paint..style = PaintingStyle.fill,
      );
    } else {
      // 多点绘制平滑路径
      final path = _createSmoothPath(stroke.points);
      canvas.drawPath(path, paint);
    }
  }

  /// 创建平滑路径
  Path _createSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
    } else {
      for (int i = 1; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }
      path.lineTo(points.last.dx, points.last.dy);
    }

    return path;
  }

  /// 光栅化图层（增量光栅化），缓存覆盖笔画在文档中的外接矩形
  Future<void> rasterize() async {
    if (!_needsRasterize && _rasterizedImage != null) return;
    if (_strokes.isEmpty && _rasterizedImage != null) return;
    if (_isRasterizing) return; // 防止并发重入

    final rasterBounds = _cacheRectFor(_calculateStrokeBounds());
    if (rasterBounds == null) return;

    _isRasterizing = true;
    try {
      // 快照当前状态，用于检测竞态条件
      final strokeCount = _strokes.length;
      final startGeneration = _strokeGeneration;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.translate(-rasterBounds.left, -rasterBounds.top);

      // 先用透明色清除整个画布，避免显示 GPU 垃圾数据
      canvas.drawRect(
        rasterBounds,
        Paint()
          ..color = const Color(0x00000000)
          ..blendMode = BlendMode.src,
      );

      // 检查待光栅化的笔画中是否有橡皮擦
      // BlendMode.clear 需要在已有内容上操作，所以橡皮擦需要完整重绘
      final hasEraserInPending = _strokes
          .skip(_rasterizedStrokeCount)
          .any((s) => s.isEraser);

      // 如果有橡皮擦，需要完整重绘（不能增量）
      final needsFullRedraw =
          hasEraserInPending ||
          _rasterizedStrokeCount == 0 ||
          _rasterizedImage == null;

      if (needsFullRedraw) {
        // 完整重绘所有笔画
        for (int i = 0; i < strokeCount; i++) {
          _drawStroke(canvas, _strokes[i]);
        }
      } else {
        // 增量绘制（无橡皮擦时）：新边界总是包含旧边界
        canvas.drawImage(_rasterizedImage!, _rasterBounds.topLeft, Paint());

        // 只绘制未光栅化的笔画
        for (int i = _rasterizedStrokeCount; i < strokeCount; i++) {
          _drawStroke(canvas, _strokes[i]);
        }
      }

      final picture = recorder.endRecording();
      final oldImage = _rasterizedImage;
      _rasterizedImage = await picture.toImage(
        rasterBounds.width.toInt(),
        rasterBounds.height.toInt(),
      );
      _rasterBounds = rasterBounds;
      picture.dispose();
      oldImage?.dispose();

      // 检查版本号：如果笔画在光栅化期间被修改，不更新计数
      // 这避免了 removeLastStroke/clearStrokes 与 rasterize 的竞态条件
      if (_strokeGeneration == startGeneration) {
        _rasterizedStrokeCount = strokeCount;
        _needsRasterize = false;
      }
      // 如果版本号变化，保持 _needsRasterize = true，下次调用会重新光栅化
      _needsComposite = true;
    } finally {
      _isRasterizing = false;
    }
  }

  /// 更新合成缓存（基础图像 + 光栅化笔画），缓存覆盖整个内容外接矩形
  Future<void> updateCompositeCache() async {
    if (!_needsComposite && _compositedCache != null) return;
    if (_isCompositing) return; // 防止并发重入

    final compositeBounds = _cacheRectFor(contentBounds);
    if (compositeBounds == null) return;

    _isCompositing = true;
    try {
      final startGeneration = _strokeGeneration;

      // 确保笔画已光栅化
      if (_needsRasterize && _strokes.isNotEmpty) {
        await rasterize();
      }

      final hasAnyEraser = _strokes.any((s) => s.isEraser);
      final usesStrokeRaster = !(hasAnyEraser && _base != null);
      // 光栅缓存没覆盖全部笔画时（过大或并发修改）不能拼出完整合成图
      if (usesStrokeRaster &&
          _strokes.isNotEmpty &&
          (_rasterizedImage == null ||
              _rasterizedStrokeCount < _strokes.length)) {
        return;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.translate(-compositeBounds.left, -compositeBounds.top);

      // 先用透明色清除整个画布，避免显示 GPU 垃圾数据
      canvas.drawRect(
        compositeBounds,
        Paint()
          ..color = const Color(0x00000000)
          ..blendMode = BlendMode.src,
      );

      if (!usesStrokeRaster) {
        // eraser + baseImage: saveLayer 内先绘制 base 再绘制全部笔画
        canvas.saveLayer(compositeBounds, Paint());
        _drawBaseImage(canvas, Paint());
        for (final stroke in _strokes) {
          _drawStroke(canvas, stroke);
        }
        canvas.restore();
      } else {
        _drawBaseImage(canvas, Paint());
        if (_rasterizedImage != null) {
          canvas.drawImage(_rasterizedImage!, _rasterBounds.topLeft, Paint());
        }
      }

      final picture = recorder.endRecording();
      final oldCache = _compositedCache;
      _compositedCache = await picture.toImage(
        compositeBounds.width.toInt(),
        compositeBounds.height.toInt(),
      );
      _compositeBounds = compositeBounds;
      picture.dispose();
      oldCache?.dispose();

      if (_strokeGeneration == startGeneration) {
        _needsComposite = false;
      }
    } finally {
      _isCompositing = false;
    }
  }

  /// 检查是否应该执行光栅化（用于空闲时处理）
  bool shouldRasterizeNow() {
    if (!_needsRasterize) return false;
    if (_strokes.isEmpty) return false;

    // 如果待处理笔画过多，强制光栅化
    if (pendingStrokeCount > _maxPendingStrokes) return true;

    // 如果距离上次笔画足够久，执行光栅化
    if (_lastStrokeTime != null) {
      return DateTime.now().difference(_lastStrokeTime!) >= _rasterizeDelay;
    }

    return false;
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
    render(canvas);

    final picture = recorder.endRecording();
    _thumbnail?.dispose();
    _thumbnail = await picture.toImage(thumbWidth, thumbHeight);
    picture.dispose();

    _needsThumbnailUpdate = false;
    _thumbnailRegion = region;
  }

  /// 标记需要更新
  void markNeedsUpdate() {
    _needsRasterize = true;
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
        _invalidateRasterState();
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
        _strokeGeneration++;
        _invalidateRasterState();
        break;
    }
  }

  /// 释放资源
  void dispose() {
    _movePreview = null;

    // 释放通知器
    isActiveNotifier.dispose();

    // 释放图像资源
    _rasterizedImage?.dispose();
    _rasterizedImage = null;
    _compositedCache?.dispose();
    _compositedCache = null;
    _swapBase(null);
    _thumbnail?.dispose();
    _thumbnail = null;

    // 清理笔画数据
    _strokes.clear();
    _baseImageOffset = Offset.zero;

    // 重置计数器和标志
    _rasterizedStrokeCount = 0;
    _strokeGeneration = 0;
    _needsRasterize = true;
    _needsComposite = true;
    _needsThumbnailUpdate = true;
    _lastStrokeTime = null;
    _isRasterizing = false;
    _isCompositing = false;
  }
}
