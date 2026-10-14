import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../widgets/common/themed_input.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final transformer = state.layerTransformer;
    final enabled = !transformer.isDragging;
    final widthPercent = params.scaleX.abs() * 100;
    final heightPercent = params.scaleY.abs() * 100;
    final size = params.size;

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
              control: _TransformNumberField(
                label: l10n.editor_transformWidth,
                value: widthPercent,
                enabled: enabled,
                onSubmitted: (value) => setScale(widthValue: value),
              ),
              trailing: const _UnitText('%'),
            ),
            ToolSettingRow(
              label: l10n.editor_transformHeight,
              control: _TransformNumberField(
                label: l10n.editor_transformHeight,
                value: heightPercent,
                enabled: enabled,
                onSubmitted: (value) => setScale(heightValue: value),
              ),
              trailing: const _UnitText('%'),
            ),
            ToolSettingRow(
              label: l10n.editor_transformAngle,
              control: _TransformNumberField(
                label: l10n.editor_transformAngle,
                value: params.rotation * 180 / math.pi,
                enabled: enabled,
                allowNegative: true,
                onSubmitted: (degrees) => transformer.update(
                  (current) => current.withRotation(degrees * math.pi / 180),
                ),
              ),
              trailing: const _UnitText('°'),
            ),
            ToolSettingRow(
              label: l10n.editor_transformCenterX,
              control: _TransformNumberField(
                label: l10n.editor_transformCenterX,
                value: params.center.dx,
                enabled: enabled,
                allowNegative: true,
                onSubmitted: (x) => transformer.update(
                  (current) =>
                      current.translated(Offset(x - current.center.dx, 0)),
                ),
              ),
              trailing: const _UnitText('px'),
            ),
            ToolSettingRow(
              label: l10n.editor_transformCenterY,
              control: _TransformNumberField(
                label: l10n.editor_transformCenterY,
                value: params.center.dy,
                enabled: enabled,
                allowNegative: true,
                onSubmitted: (y) => transformer.update(
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

/// 失焦或回车时提交；改动未提交前不被外部数值覆盖
class _TransformNumberField extends StatefulWidget {
  const _TransformNumberField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onSubmitted,
    this.allowNegative = false,
  });

  final String label;
  final double value;
  final bool enabled;
  final bool allowNegative;
  final ValueChanged<double> onSubmitted;

  @override
  State<_TransformNumberField> createState() => _TransformNumberFieldState();
}

class _TransformNumberFieldState extends State<_TransformNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  final FocusNode _focusNode = FocusNode();
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_TransformNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_edited && oldWidget.value != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _submit(_controller.text);
  }

  void _submit(String text) {
    final edited = _edited;
    _edited = false;
    final parsed = double.tryParse(text.trim());
    final valid =
        parsed != null &&
        parsed.isFinite &&
        (widget.allowNegative || parsed > 0);
    if (edited && valid && _format(parsed) != _format(widget.value)) {
      widget.onSubmitted(parsed);
      // 结果可能被夹紧或没有可变换的内容，以父组件重建后的实际数值为准
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_edited) _controller.text = _format(widget.value);
      });
      return;
    }
    _controller.text = _format(widget.value);
  }

  static String _format(double value) {
    final rounded = (value * 10).roundToDouble() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return ThemedInput(
      controller: _controller,
      focusNode: _focusNode,
      semanticLabel: widget.label,
      enabled: widget.enabled,
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      keyboardType: TextInputType.numberWithOptions(
        signed: widget.allowNegative,
        decimal: true,
      ),
      onChanged: (_) => _edited = true,
      onSubmitted: _submit,
    );
  }
}
