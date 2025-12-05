import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';
import 'tool_base.dart';

/// 拾色器工具
class ColorPickerTool extends EditorTool {
  /// 静态取色方法（供其他工具在 Alt 模式下调用）
  /// 返回指定画布坐标位置的颜色
  static Future<Color?> pickColorAt(Offset canvasPoint, EditorState state) async {
    final canvasWidth = state.canvasSize.width.toInt();
    final canvasHeight = state.canvasSize.height.toInt();

    // 检查是否在画布范围内
    if (canvasPoint.dx < 0 ||
        canvasPoint.dy < 0 ||
        canvasPoint.dx >= canvasWidth ||
        canvasPoint.dy >= canvasHeight) {
      return null;
    }

    // 优先使用缓存快照（同步采样）
    final cachedColor = state.layerManager.getPixelColor(
      canvasPoint.dx.toInt(),
      canvasPoint.dy.toInt(),
    );
    if (cachedColor != null) {
      return cachedColor;
    }

    // 回退到异步采样（渲染小区域）
    const sampleRegionSize = 5;
    final centerX = canvasPoint.dx.toInt();
    final centerY = canvasPoint.dy.toInt();
    final halfRegion = sampleRegionSize ~/ 2;

    final regionLeft = (centerX - halfRegion).clamp(0, canvasWidth - 1);
    final regionTop = (centerY - halfRegion).clamp(0, canvasHeight - 1);
    final regionRight = (centerX + halfRegion + 1).clamp(0, canvasWidth);
    final regionBottom = (centerY + halfRegion + 1).clamp(0, canvasHeight);
    final regionWidth = regionRight - regionLeft;
    final regionHeight = regionBottom - regionTop;

    if (regionWidth <= 0 || regionHeight <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.translate(-regionLeft.toDouble(), -regionTop.toDouble());
    canvas.clipRect(Rect.fromLTWH(
      regionLeft.toDouble(),
      regionTop.toDouble(),
      regionWidth.toDouble(),
      regionHeight.toDouble(),
    ));

    // 绘制白色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      Paint()..color = Colors.white,
    );

    state.layerManager.renderAll(canvas, state.canvasSize);

    final picture = recorder.endRecording();
    final image = await picture.toImage(regionWidth, regionHeight);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();

    if (byteData == null) return null;

    final localX = centerX - regionLeft;
    final localY = centerY - regionTop;
    final offset = (localY * regionWidth + localX) * 4;

    if (offset >= 0 && offset + 3 < byteData.lengthInBytes) {
      final r = byteData.getUint8(offset);
      final g = byteData.getUint8(offset + 1);
      final b = byteData.getUint8(offset + 2);
      final a = byteData.getUint8(offset + 3);
      return Color.fromARGB(a, r, g, b);
    }

    return null;
  }

  /// 取样范围
  ColorPickerSampleMode _sampleMode = ColorPickerSampleMode.point;
  ColorPickerSampleMode get sampleMode => _sampleMode;

  /// 取样来源
  ColorPickerSource _source = ColorPickerSource.allLayers;
  ColorPickerSource get source => _source;

  /// 预览颜色
  Color? _previewColor;
  Color? get previewColor => _previewColor;

  /// 预览位置
  Offset? _previewPosition;
  Offset? get previewPosition => _previewPosition;

  /// 放大镜像素数据 (11x11 网格)
  static const int _magnifierGridSize = 11;
  List<List<Color>>? _magnifierPixels;
  List<List<Color>>? get magnifierPixels => _magnifierPixels;

  /// Debounce 定时器：确保最后一次请求能执行
  Timer? _debounceTimer;

  /// 待处理的位置
  Offset? _pendingPosition;

  /// 待处理的状态引用
  EditorState? _pendingState;

  /// 采样版本号（用于取消过期的异步操作）
  int _samplingVersion = 0;

  /// 记录使用的快照版本（用于判断是否需要更新）
  int _usedSnapshotVersion = -1;

  /// 是否正在更新快照（防止并发更新）
  bool _isUpdatingSnapshot = false;

  @override
  String get id => 'color_picker';

  @override
  String get name => '拾色器';

  @override
  IconData get icon => Icons.colorize;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyP;

  /// 设置取样模式
  void setSampleMode(ColorPickerSampleMode mode) {
    _sampleMode = mode;
  }

  /// 设置取样来源
  void setSource(ColorPickerSource source) {
    _source = source;
  }

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    // 按下时更新预览
    _updatePreviewDebounced(event.localPosition, state);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    _updatePreviewDebounced(event.localPosition, state);
  }

  @override
  void onPointerHover(PointerHoverEvent event, EditorState state) {
    _updatePreviewDebounced(event.localPosition, state);
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    // 松开时采样并设置颜色
    debugPrint('[ColorPicker] onPointerUp at ${event.localPosition}');
    _sampleAndApplyColor(event.localPosition, state);
  }

  /// 采样并应用颜色（用于点击取色）
  Future<void> _sampleAndApplyColor(Offset canvasPoint, EditorState state) async {
    debugPrint('[ColorPicker] _sampleAndApplyColor at $canvasPoint');
    final color = await _sampleColorAt(canvasPoint, state);
    debugPrint('[ColorPicker] sampled color: $color');
    if (color != null) {
      debugPrint('[ColorPicker] setting foreground color to $color');
      state.setForegroundColor(color);
    } else {
      debugPrint('[ColorPicker] color is null, not setting');
    }
    // 切回上一个工具
    state.switchToPreviousTool();
    _clearPreview(state);
  }

  @override
  void onPointerCancel(EditorState state) {
    _clearPreview(state);
    state.cancelStroke();
  }

  /// 快速停用（同步，无异步操作）
  /// 仅清理内存中的临时状态，用于即时工具切换
  @override
  void onDeactivateFast(EditorState state) {
    // 递增版本号使任何遗留的异步操作失效
    _samplingVersion++;

    // 同步取消定时器和待处理请求
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingPosition = null;
    _pendingState = null;

    // 清理预览状态，避免显示旧数据
    _previewColor = null;
    _previewPosition = null;
    _magnifierPixels = null;

    // 不调用 requestUiUpdate()，由框架负责 UI 更新
  }

  /// 延迟激活（下一帧异步执行）
  /// 用于预热快照缓存，不阻塞工具切换
  @override
  void onActivateDeferred(EditorState state) {
    // 异步预热快照（确保拾色器可用时有最新快照）
    _ensureSnapshotReady(state);
  }

  /// 确保快照可用（异步操作）
  Future<void> _ensureSnapshotReady(EditorState state) async {
    // 防止并发更新
    if (_isUpdatingSnapshot) return;

    final currentVersion = state.canvasSnapshotVersion;

    // 如果快照已有效且版本匹配，无需更新
    if (state.hasValidCanvasSnapshot && _usedSnapshotVersion == currentVersion) {
      return;
    }

    _isUpdatingSnapshot = true;
    try {
      await state.updateCanvasSnapshot();
      _usedSnapshotVersion = state.canvasSnapshotVersion;
    } finally {
      _isUpdatingSnapshot = false;
    }
  }

  /// 使用同步优先、异步回退的策略更新预览
  /// 优先级：区域缓存 > 全局快照缓存 > 异步采样
  void _updatePreviewDebounced(Offset screenPosition, EditorState state) {
    // 立即更新位置，让放大镜跟随鼠标
    final positionChanged = _previewPosition != screenPosition;
    _previewPosition = screenPosition;

    final centerX = screenPosition.dx.toInt();
    final centerY = screenPosition.dy.toInt();

    // 1. 尝试从区域缓存同步采样（最快，O(1)）
    if (_source == ColorPickerSource.allLayers) {
      final regionalPixels = state.layerManager.getRegionalMagnifierPixels(
        centerX, centerY, _magnifierGridSize,
      );
      if (regionalPixels != null) {
        _magnifierPixels = regionalPixels;
        const halfGrid = _magnifierGridSize ~/ 2;
        final centerColor = regionalPixels[halfGrid][halfGrid];

        if (_sampleMode == ColorPickerSampleMode.point) {
          _previewColor = centerColor;
        } else {
          // 区域采样（3x3平均）
          int totalR = 0, totalG = 0, totalB = 0, totalA = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              final color = regionalPixels[halfGrid + dy][halfGrid + dx];
              totalR += color.red;
              totalG += color.green;
              totalB += color.blue;
              totalA += color.alpha;
            }
          }
          _previewColor = Color.fromARGB(
            (totalA / 9).round(),
            (totalR / 9).round(),
            (totalG / 9).round(),
            (totalB / 9).round(),
          );
        }
        state.requestUiUpdate();
        return;
      }
    }

    // 2. 尝试从全局快照缓存同步采样
    final syncResult = _sampleColorSync(screenPosition, state);
    if (syncResult != null) {
      _previewColor = syncResult.color;
      _magnifierPixels = syncResult.pixels;
      state.requestUiUpdate();
      // 异步预热区域缓存（为下次移动做准备）
      _scheduleRegionalCacheUpdate(centerX, centerY, state);
      return;
    }

    // 3. 位置变化时立即更新 UI，让放大镜位置跟随鼠标（即使像素内容还没更新）
    if (positionChanged && _magnifierPixels != null) {
      state.requestUiUpdate();
    }

    // 4. 回退到异步采样 + 区域缓存预热
    _scheduleAsyncSamplingWithRegionalCache(centerX, centerY, screenPosition, state);
  }

  /// 异步预热区域缓存（为下次移动做准备）
  void _scheduleRegionalCacheUpdate(int centerX, int centerY, EditorState state) {
    final currentVersion = _samplingVersion;
    // 使用很短的延迟，让当前帧先完成
    Future.microtask(() async {
      if (_samplingVersion != currentVersion) return; // 版本变化则取消
      await state.layerManager.updateRegionalSnapshot(
        centerX, centerY, state.canvasSize,
      );
    });
  }

  /// 异步采样 + 区域缓存预热
  void _scheduleAsyncSamplingWithRegionalCache(
    int centerX,
    int centerY,
    Offset screenPosition,
    EditorState state,
  ) {
    _pendingPosition = screenPosition;
    _pendingState = state;

    _debounceTimer?.cancel();
    final currentVersion = _samplingVersion;

    // 使用较短的 debounce 时间（8ms ≈ 120fps）减少放大镜延迟
    _debounceTimer = Timer(const Duration(milliseconds: 8), () async {
      if (_samplingVersion != currentVersion) return;

      final position = _pendingPosition;
      final currentState = _pendingState;
      if (position == null || currentState == null) return;

      // 同时启动异步采样和区域缓存更新
      final sampleFuture = _sampleColorAt(position, currentState);
      final cacheFuture = currentState.layerManager.updateRegionalSnapshot(
        centerX, centerY, currentState.canvasSize,
      );

      final color = await sampleFuture;
      await cacheFuture; // 等待缓存更新完成

      if (_samplingVersion != currentVersion) return;

      if (color != null) {
        _previewColor = color;
        _previewPosition = position;
        currentState.requestUiUpdate();
      }
    });
  }

  /// 同步采样（使用缓存快照）
  /// 返回采样结果，如果缓存不可用则返回 null
  _SyncSampleResult? _sampleColorSync(Offset canvasPoint, EditorState state) {
    // 仅当取样来源是"所有图层"时才使用缓存
    // 因为缓存的是合成后的所有图层
    if (_source != ColorPickerSource.allLayers) return null;

    final centerX = canvasPoint.dx.toInt();
    final centerY = canvasPoint.dy.toInt();

    // 从缓存获取放大镜像素
    final pixels = state.layerManager.getMagnifierPixels(
      centerX,
      centerY,
      _magnifierGridSize,
    );

    if (pixels == null) return null;

    final halfGrid = _magnifierGridSize ~/ 2;
    final centerColor = pixels[halfGrid][halfGrid];

    Color finalColor;
    if (_sampleMode == ColorPickerSampleMode.point) {
      finalColor = centerColor;
    } else {
      // 区域采样（3x3平均）
      int totalR = 0, totalG = 0, totalB = 0, totalA = 0;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final color = pixels[halfGrid + dy][halfGrid + dx];
          totalR += color.red;
          totalG += color.green;
          totalB += color.blue;
          totalA += color.alpha;
        }
      }
      finalColor = Color.fromARGB(
        (totalA / 9).round(),
        (totalR / 9).round(),
        (totalG / 9).round(),
        (totalB / 9).round(),
      );
    }

    return _SyncSampleResult(color: finalColor, pixels: pixels);
  }

  /// 清理预览状态
  /// [notifyUi] 是否通知 UI 更新（工具切换时由框架负责，不需要额外通知）
  void _clearPreview(EditorState state, {bool notifyUi = true}) {
    // 增加版本号，使所有正在进行的异步采样操作失效
    _samplingVersion++;

    // 取消待处理的请求
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingPosition = null;
    _pendingState = null;

    _previewColor = null;
    _previewPosition = null;
    _magnifierPixels = null;

    // 只在需要时通知 UI 更新
    if (notifyUi) {
      state.requestUiUpdate();
    }
  }

  /// 采样区域大小（只渲染这么大的区域，而不是整个画布）
  /// 需要包含放大镜网格 + 边缘缓冲
  static const int _sampleRegionSize = 33;

  /// 在指定画布坐标位置采样颜色
  /// 所见即所得：采样所有可见图层合成后的实际显示颜色
  Future<Color?> _sampleColorAt(Offset canvasPoint, EditorState state) async {
    final canvasWidth = state.canvasSize.width.toInt();
    final canvasHeight = state.canvasSize.height.toInt();

    debugPrint('[ColorPicker] _sampleColorAt: canvasPoint=$canvasPoint, canvasSize=${canvasWidth}x$canvasHeight');

    // 检查是否在画布范围内
    if (canvasPoint.dx < 0 ||
        canvasPoint.dy < 0 ||
        canvasPoint.dx >= canvasWidth ||
        canvasPoint.dy >= canvasHeight) {
      debugPrint('[ColorPicker] _sampleColorAt: out of bounds');
      _magnifierPixels = null;
      return null;
    }

    final centerX = canvasPoint.dx.toInt();
    final centerY = canvasPoint.dy.toInt();
    final halfRegion = _sampleRegionSize ~/ 2;

    // 计算采样区域的边界（裁剪到画布范围）
    final regionLeft = (centerX - halfRegion).clamp(0, canvasWidth - 1);
    final regionTop = (centerY - halfRegion).clamp(0, canvasHeight - 1);
    final regionRight = (centerX + halfRegion + 1).clamp(0, canvasWidth);
    final regionBottom = (centerY + halfRegion + 1).clamp(0, canvasHeight);
    final regionWidth = regionRight - regionLeft;
    final regionHeight = regionBottom - regionTop;

    if (regionWidth <= 0 || regionHeight <= 0) {
      _magnifierPixels = null;
      return null;
    }

    // 创建小区域的临时图像
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 平移画布，使采样区域位于原点
    canvas.translate(-regionLeft.toDouble(), -regionTop.toDouble());

    // 裁剪到采样区域，避免绘制不必要的内容
    canvas.clipRect(Rect.fromLTWH(
      regionLeft.toDouble(),
      regionTop.toDouble(),
      regionWidth.toDouble(),
      regionHeight.toDouble(),
    ));

    // 绘制白色背景（与画布显示一致）
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      Paint()..color = Colors.white,
    );

    // 所见即所得：始终渲染所有可见图层的合成结果
    state.layerManager.renderAll(canvas, state.canvasSize);

    final picture = recorder.endRecording();
    // 只生成小区域的图像，而非整个画布
    final image = await picture.toImage(regionWidth, regionHeight);

    // 获取像素颜色
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();

    if (byteData == null) {
      _magnifierPixels = null;
      return null;
    }

    // 计算光标在采样区域内的相对位置
    final localX = centerX - regionLeft;
    final localY = centerY - regionTop;
    final halfGrid = _magnifierGridSize ~/ 2;

    // 获取放大镜区域的像素
    _magnifierPixels = List.generate(_magnifierGridSize, (row) {
      return List.generate(_magnifierGridSize, (col) {
        final px = (localX + col - halfGrid).clamp(0, regionWidth - 1);
        final py = (localY + row - halfGrid).clamp(0, regionHeight - 1);
        final offset = (py * regionWidth + px) * 4;

        if (offset >= 0 && offset + 3 < byteData.lengthInBytes) {
          final r = byteData.getUint8(offset);
          final g = byteData.getUint8(offset + 1);
          final b = byteData.getUint8(offset + 2);
          final a = byteData.getUint8(offset + 3);
          return Color.fromARGB(a, r, g, b);
        }
        return Colors.transparent;
      });
    });

    if (_sampleMode == ColorPickerSampleMode.point) {
      // 单点采样 - 返回中心像素
      return _magnifierPixels![halfGrid][halfGrid];
    } else {
      // 区域采样（3x3平均）
      int totalR = 0, totalG = 0, totalB = 0, totalA = 0;
      int count = 0;

      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final color = _magnifierPixels![halfGrid + dy][halfGrid + dx];
          totalR += color.red;
          totalG += color.green;
          totalB += color.blue;
          totalA += color.alpha;
          count++;
        }
      }

      if (count > 0) {
        return Color.fromARGB(
          (totalA / count).round(),
          (totalR / count).round(),
          (totalG / count).round(),
          (totalB / count).round(),
        );
      }
    }

    return null;
  }

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return _ColorPickerSettingsPanel(
      tool: this,
      onSettingsChanged: () {
        state.requestUiUpdate();
      },
    );
  }

  @override
  Widget? buildCursor(EditorState state, {Offset? screenCursorPosition}) {
    // 使用屏幕坐标定位预览气泡，确保在画布旋转/镜像时位置正确
    final position = screenCursorPosition ?? _previewPosition;
    if (_previewColor != null && position != null && _magnifierPixels != null) {
      // 放大镜显示在光标右侧，不遮挡光标
      return Positioned(
        left: position.dx + 20,
        top: position.dy - 40,
        child: _ColorPickerMagnifier(
          color: _previewColor!,
          pixels: _magnifierPixels!,
          gridSize: _magnifierGridSize,
        ),
      );
    }
    return null;
  }
}

/// 取样模式
enum ColorPickerSampleMode {
  /// 单点取样
  point,
  /// 区域取样（3x3）
  area,
}

extension ColorPickerSampleModeExtension on ColorPickerSampleMode {
  String get label {
    switch (this) {
      case ColorPickerSampleMode.point:
        return '单点';
      case ColorPickerSampleMode.area:
        return '区域';
    }
  }
}

/// 取样来源
enum ColorPickerSource {
  /// 当前图层
  currentLayer,
  /// 所有图层
  allLayers,
}

extension ColorPickerSourceExtension on ColorPickerSource {
  String get label {
    switch (this) {
      case ColorPickerSource.currentLayer:
        return '当前图层';
      case ColorPickerSource.allLayers:
        return '所有图层';
    }
  }
}

class _ColorPickerSettingsPanel extends StatelessWidget {
  final ColorPickerTool tool;
  final VoidCallback onSettingsChanged;

  const _ColorPickerSettingsPanel({
    required this.tool,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            '拾色器',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),

        // 使用提示
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '点击画布任意位置取色，松开后自动切回上一工具',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 取样模式
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text('取样', style: theme.textTheme.bodySmall),
              ),
              Expanded(
                child: SegmentedButton<ColorPickerSampleMode>(
                  segments: ColorPickerSampleMode.values.map((mode) {
                    return ButtonSegment<ColorPickerSampleMode>(
                      value: mode,
                      label: Text(mode.label),
                    );
                  }).toList(),
                  selected: {tool.sampleMode},
                  onSelectionChanged: (selected) {
                    tool.setSampleMode(selected.first);
                    onSettingsChanged();
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(theme.textTheme.bodySmall),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 取样来源
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text('来源', style: theme.textTheme.bodySmall),
              ),
              Expanded(
                child: SegmentedButton<ColorPickerSource>(
                  segments: ColorPickerSource.values.map((source) {
                    return ButtonSegment<ColorPickerSource>(
                      value: source,
                      label: Text(source.label),
                    );
                  }).toList(),
                  selected: {tool.source},
                  onSelectionChanged: (selected) {
                    tool.setSource(selected.first);
                    onSettingsChanged();
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(theme.textTheme.bodySmall),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 拾色器放大镜
class _ColorPickerMagnifier extends StatelessWidget {
  final Color color;
  final List<List<Color>> pixels;
  final int gridSize;

  /// 缓存的阴影装饰，避免每次构建时创建新对象
  static final _shadowDecoration = BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  const _ColorPickerMagnifier({
    required this.color,
    required this.pixels,
    required this.gridSize,
  });

  @override
  Widget build(BuildContext context) {
    const magnifierSize = 77.0; // 11 * 7
    const pixelSize = 7.0;

    // 使用 RepaintBoundary 隔离重绘区域
    return RepaintBoundary(
      child: Container(
        decoration: _shadowDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 放大镜圆形区域
          ClipOval(
            child: Container(
              width: magnifierSize,
              height: magnifierSize,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                shape: BoxShape.circle,
              ),
              child: CustomPaint(
                size: const Size(magnifierSize, magnifierSize),
                painter: _MagnifierPainter(
                  pixels: pixels,
                  gridSize: gridSize,
                  pixelSize: pixelSize,
                ),
              ),
            ),
          ),
          // 连接线
          Container(
            width: 2,
            height: 8,
            color: Colors.white,
          ),
          // 颜色信息卡片
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black87,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// 放大镜像素绘制器
class _MagnifierPainter extends CustomPainter {
  final List<List<Color>> pixels;
  final int gridSize;
  final double pixelSize;

  /// 缓存的像素哈希值，用于快速比较
  final int _pixelsHash;

  _MagnifierPainter({
    required this.pixels,
    required this.gridSize,
    required this.pixelSize,
  }) : _pixelsHash = _computePixelsHash(pixels);

  /// 计算像素数据的哈希值
  static int _computePixelsHash(List<List<Color>> pixels) {
    int hash = 0;
    for (final row in pixels) {
      for (final color in row) {
        hash = hash ^ color.value;
        hash = (hash << 1) | (hash >> 31); // 简单的位旋转
      }
    }
    return hash;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final center = gridSize ~/ 2;

    // 绘制棋盘格背景（表示透明）
    final checkerPaint1 = Paint()..color = Colors.grey.shade300;
    final checkerPaint2 = Paint()..color = Colors.grey.shade100;

    // 绘制像素
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final rect = Rect.fromLTWH(
          col * pixelSize,
          row * pixelSize,
          pixelSize,
          pixelSize,
        );

        // 棋盘格背景
        final isEven = (row + col) % 2 == 0;
        canvas.drawRect(rect, isEven ? checkerPaint1 : checkerPaint2);

        // 像素颜色
        if (pixels[row][col].alpha > 0) {
          paint.color = pixels[row][col];
          canvas.drawRect(rect, paint);
        }
      }
    }

    // 绘制网格线
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= gridSize; i++) {
      // 垂直线
      canvas.drawLine(
        Offset(i * pixelSize, 0),
        Offset(i * pixelSize, size.height),
        gridPaint,
      );
      // 水平线
      canvas.drawLine(
        Offset(0, i * pixelSize),
        Offset(size.width, i * pixelSize),
        gridPaint,
      );
    }

    // 中心像素高亮框
    final centerRect = Rect.fromLTWH(
      center * pixelSize,
      center * pixelSize,
      pixelSize,
      pixelSize,
    );

    // 黑色外框
    canvas.drawRect(
      centerRect.inflate(1),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // 白色内框
    canvas.drawRect(
      centerRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _MagnifierPainter oldDelegate) {
    // 只在像素数据变化时重绘
    return _pixelsHash != oldDelegate._pixelsHash ||
           gridSize != oldDelegate.gridSize ||
           pixelSize != oldDelegate.pixelSize;
  }
}

/// 同步采样结果
class _SyncSampleResult {
  final Color color;
  final List<List<Color>> pixels;

  _SyncSampleResult({required this.color, required this.pixels});
}
