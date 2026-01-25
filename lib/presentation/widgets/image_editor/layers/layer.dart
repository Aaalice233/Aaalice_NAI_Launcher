import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/app_logger.dart';
import '../core/history_manager.dart';

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
        return '裁剪';
      case CanvasResizeMode.pad:
        return '填充';
      case CanvasResizeMode.stretch:
        return '拉伸';
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

  String get label {
    switch (this) {
      case LayerBlendMode.normal:
        return '正常';
      case LayerBlendMode.multiply:
        return '正片叠底';
      case LayerBlendMode.screen:
        return '滤色';
      case LayerBlendMode.overlay:
        return '叠加';
      case LayerBlendMode.darken:
        return '变暗';
      case LayerBlendMode.lighten:
        return '变亮';
      case LayerBlendMode.colorDodge:
        return '颜色减淡';
      case LayerBlendMode.colorBurn:
        return '颜色加深';
      case LayerBlendMode.hardLight:
        return '强光';
      case LayerBlendMode.softLight:
        return '柔光';
      case LayerBlendMode.difference:
        return '差值';
      case LayerBlendMode.exclusion:
        return '排除';
    }
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

  /// 笔画列表
  final List<StrokeData> _strokes = [];
  List<StrokeData> get strokes => List.unmodifiable(_strokes);

  /// 导入的基础图像（作为图层底图）
  ui.Image? _baseImage;
  ui.Image? get baseImage => _baseImage;
  Uint8List? _baseImageBytes;
  Uint8List? get baseImageBytes => _baseImageBytes;

  /// 光栅化后的图像缓存（笔画合并后）
  ui.Image? _rasterizedImage;
  ui.Image? get rasterizedImage => _rasterizedImage;

  /// 合并缓存（基础图像 + 光栅化笔画）
  ui.Image? _compositedCache;
  ui.Image? get compositedCache => _compositedCache;

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

  Layer({
    String? id,
    this.name = '新图层',
    this.visible = true,
    this.locked = false,
    this.opacity = 1.0,
    this.blendMode = LayerBlendMode.normal,
  }) : id = id ?? const Uuid().v4();

  /// 是否有基础图像
  bool get hasBaseImage => _baseImage != null;

  /// 是否有内容
  bool get hasContent => _baseImage != null || _strokes.isNotEmpty;

  /// 待处理的笔画数量
  int get pendingStrokeCount => _strokes.length - _rasterizedStrokeCount;

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
      _baseImage?.dispose();
      _baseImage = frame.image;
      _baseImageBytes = bytes;
      _needsComposite = true;
      _needsThumbnailUpdate = true;
      _bounds = null; // 清除边界缓存，下次渲染时重新计算
    } catch (e) {
      AppLogger.w('Failed to decode base image: $e', 'ImageEditor');
      rethrow;
    } finally {
      codec?.dispose();
    }
  }

  /// 从 ui.Image 设置基础图像
  void setBaseImageFromImage(ui.Image image) {
    _baseImage?.dispose();
    _baseImage = image;
    _needsComposite = true;
    _needsThumbnailUpdate = true;
    _bounds = null; // 清除边界缓存
  }

  /// 清除基础图像
  void clearBaseImage() {
    _baseImage?.dispose();
    _baseImage = null;
    _baseImageBytes = null;
    _needsComposite = true;
    _needsThumbnailUpdate = true;
    _bounds = null; // 清除边界缓存
  }

  /// 添加笔画
  void addStroke(StrokeData stroke) {
    _strokes.add(stroke);
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

  /// 绘制图层内容到画布
  void render(Canvas canvas, Size canvasSize) {
    if (!visible) return;

    // 保存当前状态
    canvas.save();

    // 应用不透明度和混合模式
    final layerPaint = Paint();
    if (opacity < 1.0) {
      layerPaint.color = Color.fromRGBO(255, 255, 255, opacity);
    }
    if (blendMode != LayerBlendMode.normal) {
      layerPaint.blendMode = blendMode.toFlutterBlendMode();
    }

    // 检查未光栅化的笔画中是否有橡皮擦
    // BlendMode.clear 需要在隔离的 layer 中绘制，否则会擦穿到下层
    final hasEraserInPending =
        _strokes.skip(_rasterizedStrokeCount).any((s) => s.isEraser);

    final needsLayer = opacity < 1.0 ||
        blendMode != LayerBlendMode.normal ||
        hasEraserInPending;
    if (needsLayer) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        layerPaint,
      );
    }

    // 优先使用合成缓存
    if (_compositedCache != null && !_needsComposite) {
      canvas.drawImage(_compositedCache!, Offset.zero, Paint());
    } else {
      // 绘制基础图像
      if (_baseImage != null) {
        canvas.drawImage(_baseImage!, Offset.zero, Paint());
      }

      // 使用光栅化缓存绘制已处理的笔画
      if (_rasterizedImage != null && _rasterizedStrokeCount > 0) {
        canvas.drawImage(_rasterizedImage!, Offset.zero, Paint());
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

  /// 使用缓存渲染（优先使用缓存，性能更好）
  void renderWithCache(Canvas canvas, Size canvasSize, {Rect? viewportBounds}) {
    if (!visible) return;

    // 空间剔除优化：如果图层边界与视口不相交，则跳过渲染
    // 这在放大查看画布的某一部分时特别有效，可以避免渲染不可见的图层
    if (viewportBounds != null) {
      // 确保边界已计算
      _bounds ??= _calculateBounds(canvasSize);

      // 如果图层边界存在且与视口不相交，则跳过渲染
      if (_bounds != null && !_bounds!.overlaps(viewportBounds)) {
        return;
      }
    }

    canvas.save();

    final layerPaint = Paint();
    if (opacity < 1.0) {
      layerPaint.color = Color.fromRGBO(255, 255, 255, opacity);
    }
    if (blendMode != LayerBlendMode.normal) {
      layerPaint.blendMode = blendMode.toFlutterBlendMode();
    }

    // 如果有合成缓存且不需要更新，直接使用
    if (_compositedCache != null && !_needsComposite) {
      canvas.drawImage(_compositedCache!, Offset.zero, layerPaint);
    } else {
      // 否则走正常渲染流程
      render(canvas, canvasSize);
    }

    canvas.restore();
  }

  /// 计算图层边界
  Rect _calculateBounds(Size canvasSize) {
    // 如果没有内容，边界为空
    if (!hasContent) {
      return Rect.zero;
    }

    // 如果有基础图像，使用画布尺寸作为边界
    if (_baseImage != null) {
      return Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    }

    // 否则根据笔画计算边界
    if (_strokes.isEmpty) {
      return Rect.zero;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in _strokes) {
      for (final point in stroke.points) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
    }

    // 添加笔画半径的边距
    final maxRadius = _strokes
        .map((s) => s.size / 2)
        .fold<double>(0.0, (max, radius) => radius > max ? radius : max);

    return Rect.fromLTRB(
      minX - maxRadius,
      minY - maxRadius,
      maxX + maxRadius,
      maxY + maxRadius,
    );
  }

  /// 绘制单个笔画
  void _drawStroke(Canvas canvas, StrokeData stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isEraser
          ? const Color(0xFFFFFFFF) // 颜色无所谓，clear 模式会忽略
          : stroke.color.withOpacity(stroke.opacity)
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

  /// 光栅化图层（增量光栅化）
  Future<void> rasterize(Size canvasSize) async {
    if (!_needsRasterize && _rasterizedImage != null) return;
    if (_strokes.isEmpty && _rasterizedImage != null) return;
    if (_isRasterizing) return; // 防止并发重入
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    _isRasterizing = true;
    try {
      // 快照当前状态，用于检测竞态条件
      final strokeCount = _strokes.length;
      final startGeneration = _strokeGeneration;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 先用透明色清除整个画布，避免显示 GPU 垃圾数据
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        Paint()
          ..color = const Color(0x00000000)
          ..blendMode = BlendMode.src,
      );

      if (_strokes.isEmpty) {
        // 没有笔画时，直接返回透明画布
      } else {
        // 检查待光栅化的笔画中是否有橡皮擦
        // BlendMode.clear 需要在已有内容上操作，所以橡皮擦需要完整重绘
        final hasEraserInPending =
            _strokes.skip(_rasterizedStrokeCount).any((s) => s.isEraser);

        // 如果有橡皮擦，需要完整重绘（不能增量）
        final needsFullRedraw =
            hasEraserInPending || _rasterizedStrokeCount == 0;

        if (needsFullRedraw) {
          // 完整重绘所有笔画
          for (int i = 0; i < strokeCount; i++) {
            _drawStroke(canvas, _strokes[i]);
          }
        } else {
          // 增量绘制（无橡皮擦时）
          if (_rasterizedImage != null && _rasterizedStrokeCount > 0) {
            canvas.drawImage(_rasterizedImage!, Offset.zero, Paint());
          }

          // 只绘制未光栅化的笔画
          for (int i = _rasterizedStrokeCount; i < strokeCount; i++) {
            _drawStroke(canvas, _strokes[i]);
          }
        }
      }

      final picture = recorder.endRecording();
      final oldImage = _rasterizedImage;
      _rasterizedImage = await picture.toImage(
        canvasSize.width.toInt(),
        canvasSize.height.toInt(),
      );
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

  /// 更新合成缓存（基础图像 + 光栅化笔画）
  Future<void> updateCompositeCache(Size canvasSize) async {
    if (!_needsComposite && _compositedCache != null) return;
    if (_isCompositing) return; // 防止并发重入
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    _isCompositing = true;
    try {
      // 确保笔画已光栅化
      if (_needsRasterize && _strokes.isNotEmpty) {
        await rasterize(canvasSize);
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 先用透明色清除整个画布，避免显示 GPU 垃圾数据
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        Paint()
          ..color = const Color(0x00000000)
          ..blendMode = BlendMode.src,
      );

      // 绘制基础图像
      if (_baseImage != null) {
        canvas.drawImage(_baseImage!, Offset.zero, Paint());
      }

      // 绘制光栅化的笔画
      if (_rasterizedImage != null) {
        canvas.drawImage(_rasterizedImage!, Offset.zero, Paint());
      }

      final picture = recorder.endRecording();
      final oldCache = _compositedCache;
      _compositedCache = await picture.toImage(
        canvasSize.width.toInt(),
        canvasSize.height.toInt(),
      );
      picture.dispose();
      oldCache?.dispose();

      _needsComposite = false;
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

  /// 更新缩略图
  Future<void> updateThumbnail(Size canvasSize, {int maxSize = 64}) async {
    if (!_needsThumbnailUpdate && _thumbnail != null) return;

    // 计算缩略图尺寸
    final aspect = canvasSize.width / canvasSize.height;
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
    final scale = thumbWidth / canvasSize.width;
    canvas.scale(scale);
    render(canvas, canvasSize);

    final picture = recorder.endRecording();
    _thumbnail?.dispose();
    _thumbnail = await picture.toImage(thumbWidth, thumbHeight);
    picture.dispose();

    _needsThumbnailUpdate = false;
  }

  /// 标记需要更新
  void markNeedsUpdate() {
    _needsRasterize = true;
    _needsThumbnailUpdate = true;
  }

  /// 转换为数据对象
  LayerData toData() {
    return LayerData(
      id: id,
      name: name,
      visible: visible,
      locked: locked,
      opacity: opacity,
      blendMode: blendMode,
      strokes: List.from(_strokes),
    );
  }

  /// 从数据对象创建图层
  factory Layer.fromData(LayerData data) {
    final layer = Layer(
      id: data.id,
      name: data.name,
      visible: data.visible,
      locked: data.locked,
      opacity: data.opacity,
      blendMode: data.blendMode,
    );
    for (final stroke in data.strokes) {
      layer.addStroke(stroke);
    }
    return layer;
  }

  /// 克隆图层
  ///
  /// 注意：如果图层有 baseImage，需要调用 [cloneAsync] 来正确克隆基础图像
  Layer clone({String? newName}) {
    final cloned = Layer(
      name: newName ?? '$name 副本',
      visible: visible,
      locked: locked,
      opacity: opacity,
      blendMode: blendMode,
    );

    // 复制基础图像字节（延迟解码）
    if (_baseImageBytes != null) {
      cloned._baseImageBytes = Uint8List.fromList(_baseImageBytes!);
    }

    for (final stroke in _strokes) {
      cloned.addStroke(stroke.copyWith());
    }
    return cloned;
  }

  /// 异步克隆图层（包括解码基础图像）
  Future<Layer> cloneAsync({String? newName}) async {
    final cloned = clone(newName: newName);

    // 如果有基础图像字节，重新解码
    if (cloned._baseImageBytes != null) {
      await cloned.setBaseImage(cloned._baseImageBytes!);
    }

    return cloned;
  }

  /// 变换图层内容以适应新画布尺寸
  ///
  /// [oldSize] 原画布尺寸
  /// [newSize] 新画布尺寸
  /// [mode] 变换模式
  void transformContent(Size oldSize, Size newSize, CanvasResizeMode mode) {
    if (oldSize == newSize) return;
    if (_strokes.isEmpty && _baseImage == null) return;

    switch (mode) {
      case CanvasResizeMode.crop:
      case CanvasResizeMode.pad:
        // 裁剪和填充模式：保持笔画原位置，渲染时自动裁剪
        // 不需要变换笔画坐标
        _needsRasterize = true;
        _needsComposite = true;
        _needsThumbnailUpdate = true;
        break;

      case CanvasResizeMode.stretch:
        // 拉伸模式：缩放所有笔画坐标
        final scaleX = newSize.width / oldSize.width;
        final scaleY = newSize.height / oldSize.height;

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
        _rasterizedStrokeCount = 0;
        _needsRasterize = true;
        _needsComposite = true;
        _needsThumbnailUpdate = true;

        // 清除缓存，强制重新生成
        _rasterizedImage?.dispose();
        _rasterizedImage = null;
        _compositedCache?.dispose();
        _compositedCache = null;
        break;
    }
  }

  /// 释放资源
  void dispose() {
    // 释放通知器
    isActiveNotifier.dispose();

    // 释放图像资源
    _rasterizedImage?.dispose();
    _rasterizedImage = null;
    _compositedCache?.dispose();
    _compositedCache = null;
    _baseImage?.dispose();
    _baseImage = null;
    _thumbnail?.dispose();
    _thumbnail = null;

    // 清理笔画数据
    _strokes.clear();
    _baseImageBytes = null;

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
