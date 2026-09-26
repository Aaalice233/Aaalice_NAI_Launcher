import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../common/compact_icon_button.dart';
import '../core/editor_state.dart';
import '../core/history_manager.dart';
import 'tool_base.dart';
import 'tool_setting_rows.dart';

/// Clone Stamp 工具 - 像素级仿制图章
///
/// 取源点状态下点按画布（或 Alt+点击）设源点并同步捕获画布快照。
/// 绘制时实时显示克隆像素预览，松开后原子应用。
class CloneStampTool extends EditorTool {
  double _size = 20.0;
  double get size => _size;

  double _opacity = 1.0;
  double get opacity => _opacity;

  final ValueNotifier<Offset?> _sourcePoint = ValueNotifier(null);
  Offset? get sourcePoint => _sourcePoint.value;

  // 没有源点时默认处于取源点状态，首次点按即设源点
  final ValueNotifier<bool> _pickingSource = ValueNotifier(true);
  bool get isPickingSource => _pickingSource.value;

  final ValueNotifier<Offset?> _sourceMarker = ValueNotifier(null);

  /// 源点准星的文档坐标：瞄准时跟随指针，涂抹时跟随取样位置
  ValueListenable<Offset?> get sourceMarker => _sourceMarker;

  /// 源点或取源点状态变化时通知
  late final Listenable sourceListenable = Listenable.merge([
    _sourcePoint,
    _pickingSource,
  ]);

  Offset? _sourceOffset;
  Offset? get sourceOffset => _sourceOffset;

  ui.Image? _canvasSnapshot;
  ui.Image? get canvasSnapshot => _canvasSnapshot;

  /// 快照左上角在文档中的位置
  Offset _snapshotOrigin = Offset.zero;

  _CloneGesture? _gesture;

  bool _isApplying = false;

  void setSize(double value) {
    _size = value.clamp(1.0, 200.0);
  }

  void setOpacity(double value) {
    _opacity = value.clamp(0.0, 1.0);
  }

  /// 开启后下一次点按画布设为源点
  void setPickingSource(bool value) {
    _pickingSource.value = value;
  }

  @override
  String get id => 'clone_stamp';

  @override
  String get name => 'Clone Stamp';

  @override
  IconData get icon => Icons.copy_all;

  @override
  bool get isPaintTool => true;

  @override
  bool get handlesAltKey => true;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    final aimsSource = state.isAltPressed || isPickingSource;
    _gesture = _CloneGesture(
      aimsSource: aimsSource,
      offsetBefore: _sourceOffset,
      markerBefore: _sourceMarker.value,
    );
    if (aimsSource) {
      _sourceMarker.value = event.localPosition;
      return;
    }

    final source = _sourcePoint.value;
    if (source == null || _canvasSnapshot == null) return;

    state.startStroke(event.localPosition);
    // 按裁进取景框后的起笔点对齐，首个取样点恰好落在源点
    final start = state.currentStrokePoints.first;
    final offset = _sourceOffset ??= start - source;
    _sourceMarker.value = start - offset;
  }

  // 松开才提交：双指缩放的第一根手指、系统取消都不会误设源点
  void _commitSource(
    Offset position,
    EditorState state,
    _CloneGesture gesture,
  ) {
    // 框外只有透明像素可仿制
    if (!state.frame.contains(position)) {
      _restore(gesture);
      return;
    }
    _sourcePoint.value = position;
    _sourceOffset = null;
    _pickingSource.value = false;
    _sourceMarker.value = position;
    _captureSnapshotSync(state);
  }

  void _restore(_CloneGesture gesture) {
    _sourceOffset = gesture.offsetBefore;
    _sourceMarker.value = gesture.markerBefore;
  }

  /// 同步捕获画布快照（保证设源点后立即可用）
  void _captureSnapshotSync(EditorState state) {
    _canvasSnapshot?.dispose();
    _canvasSnapshot = null;

    final region = state.frame;
    final w = region.width.toInt();
    final h = region.height.toInt();
    if (w <= 0 || h <= 0) return;

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.translate(-region.left, -region.top);
    state.layerManager.renderAll(c);
    final pic = rec.endRecording();
    _canvasSnapshot = pic.toImageSync(w, h);
    _snapshotOrigin = region.topLeft;
    pic.dispose();
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    final gesture = _gesture;
    if (gesture == null) return;
    if (gesture.aimsSource) {
      _sourceMarker.value = event.localPosition;
      return;
    }

    final offset = _sourceOffset;
    if (offset == null || !state.isDrawing) return;
    state.updateStroke(event.localPosition);
    _sourceMarker.value = state.currentStrokePoints.last - offset;
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    final gesture = _gesture;
    _gesture = null;
    if (gesture != null && gesture.aimsSource) {
      _commitSource(event.localPosition, state, gesture);
      return;
    }

    if (!state.isDrawing || state.currentStrokePoints.isEmpty) {
      // 笔画已被 Esc 等外部操作取消，由它确立的对齐一并作废
      if (gesture != null) _restore(gesture);
      state.endStroke();
      return;
    }

    final points = List<Offset>.from(state.currentStrokePoints);
    state.endStroke();
    if (_isApplying) return;
    _applyClone(state, points);
  }

  @override
  void onPointerCancel(EditorState state) {
    final gesture = _gesture;
    _gesture = null;
    if (gesture != null) _restore(gesture);
    super.onPointerCancel(state);
  }

  Future<void> _applyClone(EditorState state, List<Offset> points) async {
    final activeLayer = state.layerManager.activeLayer;
    if (activeLayer == null || activeLayer.locked) return;
    // 等待图层渲染期间可能重设源点或切换工具，合成只用此刻定格的取样参数
    final sample = _liveSample?.frozen();
    if (sample == null) return;
    _isApplying = true;

    try {
      final region = state.frame;

      final layerImg = await activeLayer.renderToImage(region);

      final result = _compositeCloneSync(layerImg, sample, points, region);
      layerImg.dispose();

      final pngData = await result.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) {
        result.dispose();
        return;
      }

      state.historyManager.execute(
        ReplaceLayerImageAction(
          layerId: activeLayer.id,
          newImageBytes: pngData.buffer.asUint8List(),
          newImage: result,
          newImageOffset: region.topLeft,
          actionDescription: 'Clone Stamp',
        ),
        state,
      );
    } finally {
      sample.snapshot.dispose();
      _isApplying = false;
    }
  }

  /// 当前取样参数；快照是工具持有的实例，跨异步等待使用前须 [_CloneSample.frozen]
  _CloneSample? get _liveSample {
    final snapshot = _canvasSnapshot;
    final offset = _sourceOffset;
    if (snapshot == null || offset == null) return null;
    return _CloneSample(
      snapshot: snapshot,
      origin: _snapshotOrigin,
      offset: offset,
      size: _size,
      opacity: _opacity,
    );
  }

  /// 同步合成克隆结果，输出 [region] 大小的图像
  ui.Image _compositeCloneSync(
    ui.Image layerImage,
    _CloneSample sample,
    List<Offset> points,
    Rect region,
  ) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.translate(-region.left, -region.top);

    c.drawImage(layerImage, region.topLeft, Paint());

    _drawClonePoints(c, sample, points);

    final pic = rec.endRecording();
    final img = pic.toImageSync(region.width.toInt(), region.height.toInt());
    pic.dispose();
    return img;
  }

  /// 在画布上绘制克隆点（含插值，共用于实时预览和最终应用）
  void _drawClonePoints(Canvas c, _CloneSample sample, List<Offset> points) {
    final paint = Paint()
      ..color = Color.fromRGBO(255, 255, 255, sample.opacity);

    void drawAt(Offset pt) {
      c.save();
      c.clipPath(
        Path()..addOval(
          Rect.fromCenter(center: pt, width: sample.size, height: sample.size),
        ),
      );
      c.drawImage(sample.snapshot, sample.origin + sample.offset, paint);
      c.restore();
    }

    for (final pt in points) {
      drawAt(pt);
    }

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final dist = (b - a).distance;
      if (dist < 1) continue;
      final steps = (dist / (sample.size * 0.25)).ceil();
      for (int s = 1; s < steps; s++) {
        drawAt(Offset.lerp(a, b, s / steps)!);
      }
    }
  }

  /// 绘制实时克隆预览（由 StrokePreviewPainter 调用）
  void drawRealtimePreview(Canvas canvas, List<Offset> points) {
    final sample = _liveSample;
    if (sample == null) return;
    _drawClonePoints(canvas, sample, points);
  }

  @override
  void onDeactivateFast(EditorState state) {
    _gesture = null;
    _sourcePoint.value = null;
    _sourceOffset = null;
    // 下次选中时没有源点，直接进入取源点状态
    _pickingSource.value = true;
    _sourceMarker.value = null;
    _canvasSnapshot?.dispose();
    _canvasSnapshot = null;
  }

  @override
  double getCursorRadius(EditorState state) => _size / 2;

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.editor_toolCloneStamp,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _CloneSourceControls(tool: this),
              const SizedBox(height: 8),
              ToolSettingRows(
                rowPadding: const EdgeInsets.symmetric(vertical: 4),
                rows: [
                  ToolSettingRow.slider(
                    label: context.l10n.editor_size,
                    value: _size,
                    min: 1,
                    max: 200,
                    onChanged: (v) => setState(() => setSize(v)),
                  ),
                  ToolSettingRow.slider(
                    label: context.l10n.editor_opacity,
                    value: _opacity * 100,
                    min: 0,
                    max: 100,
                    suffix: '%',
                    onChanged: (v) => setState(() => setOpacity(v / 100)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 一次按下到松开的手势；取消时据此还原
class _CloneGesture {
  const _CloneGesture({
    required this.aimsSource,
    required this.offsetBefore,
    required this.markerBefore,
  });

  /// 本次按下用于选取源点，松开时提交
  final bool aimsSource;
  final Offset? offsetBefore;
  final Offset? markerBefore;
}

/// 一次仿制绘制的取样参数
class _CloneSample {
  const _CloneSample({
    required this.snapshot,
    required this.origin,
    required this.offset,
    required this.size,
    required this.opacity,
  });

  final ui.Image snapshot;
  final Offset origin;
  final Offset offset;
  final double size;
  final double opacity;

  /// 改持快照副本，用完由调用方释放
  _CloneSample frozen() => _CloneSample(
    snapshot: snapshot.clone(),
    origin: origin,
    offset: offset,
    size: size,
    opacity: opacity,
  );
}

/// 源点开关与状态；宿主面板只在切换工具时重建，画布点按引起的变化靠监听刷新
class _CloneSourceControls extends StatelessWidget {
  const _CloneSourceControls({required this.tool});

  final CloneStampTool tool;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tool.sourceListenable,
      builder: (context, _) {
        final theme = Theme.of(context);
        final picking = tool.isPickingSource;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompactIconButton(
              icon: Icons.my_location,
              label: context.l10n.editor_cloneStampSetSource,
              tooltip: context.l10n.editor_cloneStampSetSourceTooltip,
              isActive: picking,
              toggleable: true,
              onPressed: () => tool.setPickingSource(!picking),
            ),
            const SizedBox(height: 4),
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                _statusText(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _statusText(BuildContext context) {
    if (tool.isPickingSource) return context.l10n.editor_cloneStampPickingHint;
    final source = tool.sourcePoint;
    if (source == null) return context.l10n.editor_cloneStampNoSourceHint;
    return context.l10n.editor_cloneStampSourceReadout(
      source.dx.round(),
      source.dy.round(),
    );
  }
}
