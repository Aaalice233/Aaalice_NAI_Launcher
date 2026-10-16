import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/editable_double_field.dart';
import '../../../widgets/common/themed_divider.dart';
import '../core/editor_state.dart';
import '../core/transform_geometry.dart';
import 'tool_setting_rows.dart';

/// 移动工具面板：操作提示与自由变换的数值输入
class MoveToolPanel extends StatelessWidget {
  const MoveToolPanel({super.key, required this.state});

  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transformer = state.layerTransformer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            context.l10n.editor_toolMove,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const ThemedDivider(height: 1),
        ListenableBuilder(
          listenable: Listenable.merge([
            state.selectionManager.selectionNotifier,
            state.layerManager.activeLayerNotifier,
            transformer,
          ]),
          builder: (context, _) {
            final params = transformer.params;
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MoveHints(state: state, transformable: params != null),
                  if (params != null) ...[
                    const SizedBox(height: 16),
                    _TransformSection(state: state, params: params),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MoveHints extends StatelessWidget {
  const _MoveHints({required this.state, required this.transformable});

  final EditorState state;
  final bool transformable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layer = state.layerManager.activeLayer;
    final moveHint = switch ((layer, state.selectionPath)) {
      (null, _) => l10n.editor_moveNoLayer,
      (_, final _?) => l10n.editor_moveSelectionHint,
      (final active?, null) when !state.layerMover.canMoveWholeLayer(active) =>
        l10n.editor_moveBaseLayerHint,
      _ => l10n.editor_moveLayerHint,
    };
    final touch = context.interactionPolicy.shouldExposeTouchAlternatives;
    final hints = [
      moveHint,
      if (transformable) l10n.editor_transformHandlesHint,
      if (transformable)
        touch ? l10n.editor_transformTouchHint : l10n.editor_transformKeysHint,
      if (!touch) l10n.editor_moveNudgeHint,
    ];
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, hint) in hints.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          Text(hint, style: style),
        ],
      ],
    );
  }
}

/// 数值调整都以中心为基准，每次提交写回一步，整次会话仍只采样一次
class _TransformSection extends StatelessWidget {
  const _TransformSection({required this.state, required this.params});

  final EditorState state;
  final TransformParams params;

  static const _decimals = 1;

  // 宽高必须为正；更小的比例由几何计算夹到至少 1 像素
  static const _minScalePercent = 0.1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final transformer = state.layerTransformer;
    final enabled = !transformer.isDragging;
    final widthPercent = params.scaleX.abs() * 100;
    final heightPercent = params.scaleY.abs() * 100;
    final size = params.size;
    final fieldStyle = theme.textTheme.bodySmall;

    void setScale({double? widthValue, double? heightValue}) {
      final ratio = params.scaleY.abs() / params.scaleX.abs();
      final keep = transformer.keepAspect;
      final x = widthValue != null
          ? widthValue / 100
          : (keep ? heightValue! / 100 / ratio : null);
      final y = heightValue != null
          ? heightValue / 100
          : (keep ? widthValue! / 100 * ratio : null);
      transformer.update((current) => current.withScale(x: x, y: y));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.editor_transformSection,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ToolSettingRows(
          rowPadding: const EdgeInsets.symmetric(vertical: 4),
          rows: [
            ToolSettingRow(
              label: l10n.editor_transformWidth,
              control: EditableDoubleField(
                semanticLabel: l10n.editor_transformWidth,
                value: widthPercent,
                min: _minScalePercent,
                decimals: _decimals,
                textStyle: fieldStyle,
                enabled: enabled,
                onChanged: (value) => setScale(widthValue: value),
              ),
              trailing: const _UnitText('%'),
            ),
            ToolSettingRow(
              label: l10n.editor_transformHeight,
              control: EditableDoubleField(
                semanticLabel: l10n.editor_transformHeight,
                value: heightPercent,
                min: _minScalePercent,
                decimals: _decimals,
                textStyle: fieldStyle,
                enabled: enabled,
                onChanged: (value) => setScale(heightValue: value),
              ),
              trailing: const _UnitText('%'),
            ),
            ToolSettingRow(
              label: l10n.editor_transformAngle,
              control: EditableDoubleField(
                semanticLabel: l10n.editor_transformAngle,
                value: params.rotation * 180 / math.pi,
                decimals: _decimals,
                textStyle: fieldStyle,
                enabled: enabled,
                onChanged: (degrees) => transformer.update(
                  (current) => current.withRotation(degrees * math.pi / 180),
                ),
              ),
              trailing: const _UnitText('°'),
            ),
            ToolSettingRow(
              label: l10n.editor_transformCenterX,
              control: EditableDoubleField(
                semanticLabel: l10n.editor_transformCenterX,
                value: params.center.dx,
                decimals: _decimals,
                textStyle: fieldStyle,
                enabled: enabled,
                onChanged: (x) => transformer.update(
                  (current) =>
                      current.translated(Offset(x - current.center.dx, 0)),
                ),
              ),
              trailing: const _UnitText('px'),
            ),
            ToolSettingRow(
              label: l10n.editor_transformCenterY,
              control: EditableDoubleField(
                semanticLabel: l10n.editor_transformCenterY,
                value: params.center.dy,
                decimals: _decimals,
                textStyle: fieldStyle,
                enabled: enabled,
                onChanged: (y) => transformer.update(
                  (current) =>
                      current.translated(Offset(0, y - current.center.dy)),
                ),
              ),
              trailing: const _UnitText('px'),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            l10n.editor_transformKeepAspect,
            style: theme.textTheme.bodySmall,
          ),
          value: transformer.keepAspect,
          onChanged: (value) => transformer.keepAspect = value,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: enabled
                  ? () => transformer.flip(horizontal: true)
                  : null,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(l10n.editor_transformFlipHorizontal),
            ),
            TextButton.icon(
              onPressed: enabled
                  ? () => transformer.flip(horizontal: false)
                  : null,
              icon: const Icon(Icons.swap_vert, size: 18),
              label: Text(l10n.editor_transformFlipVertical),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.editor_transformSizeReadout(
            size.width.round(),
            size.height.round(),
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _UnitText extends StatelessWidget {
  const _UnitText(this.unit);

  final String unit;

  @override
  Widget build(BuildContext context) {
    return Text(
      unit,
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }
}
