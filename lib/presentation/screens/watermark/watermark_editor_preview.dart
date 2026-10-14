import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/watermark/watermark_auto_placement.dart';
import '../../../core/watermark/watermark_scene.dart';
import '../../../data/models/watermark/watermark_settings.dart';
import '../../widgets/common/horizontal_action_strip.dart';
import 'watermark_editor_controls.dart';

enum WatermarkPreviewAnalysis { pending, ready, failed }

/// 水印编辑器的预览区；拖动、方向键和读屏动作统一以「画面上的位移」上报，单位为预览短边
class WatermarkEditorPreview extends StatelessWidget {
  const WatermarkEditorPreview({
    super.key,
    required this.source,
    required this.aspectRatio,
    required this.settings,
    required this.decision,
    required this.analysis,
    required this.logo,
    required this.selectedLayer,
    required this.layoutKind,
    required this.focusNode,
    required this.onMove,
    this.onLayoutKindChanged,
  });

  final ui.Image source;
  final double aspectRatio;
  final WatermarkSettings settings;
  final WatermarkAutoDecision decision;
  final WatermarkPreviewAnalysis analysis;
  final ui.Image? logo;
  final WatermarkEditableLayer selectedLayer;
  final WatermarkLayoutKind layoutKind;

  /// 由页面持有：断点切换会把预览挂到别的父节点下，焦点不能跟着重建丢失
  final FocusNode focusNode;
  final ValueChanged<Offset> onMove;

  /// 仅编辑默认方案时提供，用于切换示例比例
  final ValueChanged<WatermarkLayoutKind>? onLayoutKindChanged;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    child: Column(
      children: [
        if (onLayoutKindChanged case final onChanged?)
          _LayoutKindStrip(selected: layoutKind, onChanged: onChanged),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: _PreviewCanvas(
                  source: source,
                  settings: settings,
                  decision: decision,
                  logo: logo,
                  selectedLayer: selectedLayer,
                  focusNode: focusNode,
                  onMove: onMove,
                ),
              ),
            ),
          ),
        ),
        _PreviewStatus(
          settings: settings,
          decision: decision,
          analysis: analysis,
          layoutKind: layoutKind,
        ),
      ],
    ),
  );
}

class _LayoutKindStrip extends StatelessWidget {
  const _LayoutKindStrip({required this.selected, required this.onChanged});

  final WatermarkLayoutKind selected;
  final ValueChanged<WatermarkLayoutKind> onChanged;

  @override
  Widget build(BuildContext context) => HorizontalActionStrip(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: SegmentedButton<WatermarkLayoutKind>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: WatermarkLayoutKind.universal,
          label: Text(context.l10n.watermark_ratioOriginal),
        ),
        ButtonSegment(
          value: WatermarkLayoutKind.portrait,
          label: Text(context.l10n.watermark_ratioPortrait),
        ),
        ButtonSegment(
          value: WatermarkLayoutKind.square,
          label: Text(context.l10n.watermark_ratioSquare),
        ),
        ButtonSegment(
          value: WatermarkLayoutKind.landscape,
          label: Text(context.l10n.watermark_ratioLandscape),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
    ),
  );
}

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.source,
    required this.settings,
    required this.decision,
    required this.logo,
    required this.selectedLayer,
    required this.focusNode,
    required this.onMove,
  });

  static const double _semanticsStep = 0.01;
  static const double _keyStep = 0.002;
  static const double _shiftKeyStep = 0.01;

  final ui.Image source;
  final WatermarkSettings settings;
  final WatermarkAutoDecision decision;
  final ui.Image? logo;
  final WatermarkEditableLayer selectedLayer;
  final FocusNode focusNode;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layerName = selectedLayer == WatermarkEditableLayer.text
        ? l10n.watermark_textLayer
        : l10n.watermark_logoLayer;
    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) => Semantics(
          label: '$layerName. ${l10n.watermark_dragHint}',
          customSemanticsActions: {
            CustomSemanticsAction(label: l10n.watermark_moveLeft): () =>
                onMove(const Offset(-_semanticsStep, 0)),
            CustomSemanticsAction(label: l10n.watermark_moveRight): () =>
                onMove(const Offset(_semanticsStep, 0)),
            CustomSemanticsAction(label: l10n.watermark_moveUp): () =>
                onMove(const Offset(0, -_semanticsStep)),
            CustomSemanticsAction(label: l10n.watermark_moveDown): () =>
                onMove(const Offset(0, _semanticsStep)),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => focusNode.requestFocus(),
            onPanStart: (_) => focusNode.requestFocus(),
            onPanUpdate: (details) {
              final size = constraints.biggest;
              final shortEdge = math.min(size.width, size.height);
              if (shortEdge > 0) onMove(details.delta / shortEdge);
            },
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(
                    image: source,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                  CustomPaint(
                    painter: _WatermarkPreviewPainter(
                      settings: settings,
                      decision: decision,
                      logo: logo,
                      selectedLayer: selectedLayer,
                      selectionColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = HardwareKeyboard.instance.isShiftPressed
        ? _shiftKeyStep
        : _keyStep;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
      LogicalKeyboardKey.arrowRight => Offset(step, 0),
      LogicalKeyboardKey.arrowUp => Offset(0, -step),
      LogicalKeyboardKey.arrowDown => Offset(0, step),
      _ => null,
    };
    if (delta == null) return KeyEventResult.ignored;
    onMove(delta);
    return KeyEventResult.handled;
  }
}

class _PreviewStatus extends StatelessWidget {
  const _PreviewStatus({
    required this.settings,
    required this.decision,
    required this.analysis,
    required this.layoutKind,
  });

  final WatermarkSettings settings;
  final WatermarkAutoDecision decision;
  final WatermarkPreviewAnalysis analysis;
  final WatermarkLayoutKind layoutKind;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final autoStatus = _autoStatus(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          Text(_layoutStatus(context), style: textTheme.labelLarge),
          if (autoStatus != null)
            Text(
              autoStatus,
              textAlign: TextAlign.center,
              style: textTheme.labelMedium,
            ),
          Text(
            context.l10n.watermark_dragHint,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _layoutStatus(BuildContext context) {
    final l10n = context.l10n;
    if (!settings.rememberLayoutsByOrientation) {
      return l10n.watermark_layoutUniversal;
    }
    return switch (layoutKind) {
      WatermarkLayoutKind.portrait => l10n.watermark_layoutPortrait,
      WatermarkLayoutKind.square => l10n.watermark_layoutSquare,
      WatermarkLayoutKind.landscape => l10n.watermark_layoutLandscape,
      WatermarkLayoutKind.universal => l10n.watermark_layoutUniversal,
    };
  }

  String? _autoStatus(BuildContext context) {
    final l10n = context.l10n;
    if (!settings.usesSourceAnalysis) return null;
    return switch (analysis) {
      WatermarkPreviewAnalysis.pending => l10n.watermark_autoAnalyzing,
      WatermarkPreviewAnalysis.failed => l10n.watermark_autoAnalysisFailed,
      WatermarkPreviewAnalysis.ready when !settings.autoPlacement => null,
      WatermarkPreviewAnalysis.ready => switch (decision.mirror) {
        WatermarkMirror.none => l10n.watermark_autoPlacementKept,
        WatermarkMirror.horizontal =>
          l10n.watermark_autoPlacementMirroredHorizontal,
        WatermarkMirror.vertical =>
          l10n.watermark_autoPlacementMirroredVertical,
        WatermarkMirror.both => l10n.watermark_autoPlacementMirroredBoth,
      },
    };
  }
}

class _WatermarkPreviewPainter extends CustomPainter {
  const _WatermarkPreviewPainter({
    required this.settings,
    required this.decision,
    required this.logo,
    required this.selectedLayer,
    required this.selectionColor,
  });

  final WatermarkSettings settings;
  final WatermarkAutoDecision decision;
  final ui.Image? logo;
  final WatermarkEditableLayer selectedLayer;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    final result = WatermarkScene.paint(
      canvas: canvas,
      canvasSize: size,
      settings: settings,
      logo: logo,
      decision: decision,
    );
    final kind = selectedLayer == WatermarkEditableLayer.text
        ? WatermarkLayerKind.text
        : WatermarkLayerKind.logo;
    final bounds = result.boundsFor(kind);
    if (bounds != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds.inflate(4), const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = selectionColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WatermarkPreviewPainter oldDelegate) =>
      oldDelegate.settings != settings ||
      oldDelegate.decision != decision ||
      oldDelegate.logo != logo ||
      oldDelegate.selectedLayer != selectedLayer ||
      oldDelegate.selectionColor != selectionColor;
}
