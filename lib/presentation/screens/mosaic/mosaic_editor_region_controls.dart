import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/mosaic/mosaic_settings.dart';
import '../../widgets/common/horizontal_segmented_control.dart';
import '../../widgets/common/labeled_slider_rows.dart';
import 'mosaic_editor_geometry.dart';

LabeledSlider buildMosaicRatioSlider({
  required String label,
  required double value,
  required double min,
  required double max,
  required VoidCallback onPushUndo,
  required ValueChanged<double>? onChanged,
}) {
  // 选区贴边时可移动范围会收成一点，滑块区间不能为空
  final safeMax = math.max(min + 0.000001, max);
  return LabeledSlider(
    label: label,
    value: value.clamp(min, safeMax).toDouble(),
    min: min,
    max: safeMax,
    valueText: mosaicPercentText,
    onChangeStart: onChanged == null ? null : (_) => onPushUndo(),
    onChanged: onChanged,
  );
}

Widget buildMosaicSectionTitle(BuildContext context, String text) => Text(
  text,
  style: Theme.of(
    context,
  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
);

IconData mosaicShapeIcon(MosaicShape shape) => switch (shape) {
  MosaicShape.roundedRectangle => Icons.rectangle_outlined,
  MosaicShape.ellipse => Icons.circle_outlined,
  MosaicShape.brush => Icons.brush_outlined,
};

List<Widget> buildMosaicRegionListControls({
  required BuildContext context,
  required List<MosaicRegion> regions,
  required String? selectedId,
  required ValueChanged<String?> onSelectRegion,
}) => [
  Row(
    children: [
      Expanded(
        child: buildMosaicSectionTitle(context, context.l10n.mosaic_regions),
      ),
      Text('${regions.length}'),
    ],
  ),
  const SizedBox(height: 8),
  if (regions.isEmpty)
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        context.l10n.mosaic_noRegions,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    )
  else
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var index = 0; index < regions.length; index++)
          ChoiceChip(
            selected: regions[index].id == selectedId,
            avatar: Icon(mosaicShapeIcon(regions[index].shape), size: 16),
            label: Text('#${index + 1}'),
            onSelected: (_) => onSelectRegion(regions[index].id),
          ),
      ],
    ),
];

List<Widget> buildMosaicSelectedRegionControls({
  required BuildContext context,
  required MosaicRegion selected,
  required VoidCallback onPushUndo,
  required void Function(MosaicRegion value, {bool recordUndo}) onUpdateRegion,
  required ValueChanged<MosaicShape> onSetSelectedShape,
  required ValueChanged<double> onSetSelectedBrushSize,
  required VoidCallback onDuplicateSelected,
  required VoidCallback onDeleteSelected,
}) => [
  const SizedBox(height: 10),
  SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(context.l10n.mosaic_regionEnabled),
    value: selected.enabled,
    onChanged: (value) => onUpdateRegion(selected.copyWith(enabled: value)),
  ),
  SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(context.l10n.mosaic_regionLocked),
    value: selected.locked,
    onChanged: (value) => onUpdateRegion(selected.copyWith(locked: value)),
  ),
  HorizontalSegmentedControl(
    child: SegmentedButton<MosaicShape>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: MosaicShape.roundedRectangle,
          icon: const Icon(Icons.rectangle_outlined),
          label: Text(context.l10n.mosaic_shapeRectangle),
        ),
        ButtonSegment(
          value: MosaicShape.ellipse,
          icon: const Icon(Icons.circle_outlined),
          label: Text(context.l10n.mosaic_shapeEllipse),
        ),
        ButtonSegment(
          value: MosaicShape.brush,
          icon: const Icon(Icons.brush_outlined),
          label: Text(context.l10n.mosaic_shapeBrush),
        ),
      ],
      selected: {selected.shape},
      onSelectionChanged: selected.locked
          ? null
          : (value) => onSetSelectedShape(value.first),
    ),
  ),
  ..._buildRegionGeometryControls(
    context: context,
    selected: selected,
    onPushUndo: onPushUndo,
    onUpdateRegion: onUpdateRegion,
    onSetSelectedBrushSize: onSetSelectedBrushSize,
  ),
  const SizedBox(height: 8),
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: onDuplicateSelected,
        icon: const Icon(Icons.copy_all_outlined),
        label: Text(context.l10n.mosaic_duplicate),
      ),
      OutlinedButton.icon(
        onPressed: onDeleteSelected,
        icon: const Icon(Icons.delete_outline),
        label: Text(context.l10n.mosaic_delete),
      ),
    ],
  ),
];

List<Widget> _buildRegionGeometryControls({
  required BuildContext context,
  required MosaicRegion selected,
  required VoidCallback onPushUndo,
  required void Function(MosaicRegion value, {bool recordUndo}) onUpdateRegion,
  required ValueChanged<double> onSetSelectedBrushSize,
}) => [
  if (selected.shape != MosaicShape.brush) ...[
    const SizedBox(height: 8),
    LabeledSliderRows(
      sliders: [
        buildMosaicRatioSlider(
          label: context.l10n.mosaic_positionX,
          value: selected.left,
          min: 0,
          max: math.max(0.001, 1 - selected.width),
          onPushUndo: onPushUndo,
          onChanged: selected.locked
              ? null
              : (value) => onUpdateRegion(
                  selected.copyWith(left: value),
                  recordUndo: false,
                ),
        ),
        buildMosaicRatioSlider(
          label: context.l10n.mosaic_positionY,
          value: selected.top,
          min: 0,
          max: math.max(0.001, 1 - selected.height),
          onPushUndo: onPushUndo,
          onChanged: selected.locked
              ? null
              : (value) => onUpdateRegion(
                  selected.copyWith(top: value),
                  recordUndo: false,
                ),
        ),
        buildMosaicRatioSlider(
          label: context.l10n.mosaic_width,
          value: selected.width,
          min: 0.02,
          max: math.max(0.02, 1 - selected.left),
          onPushUndo: onPushUndo,
          onChanged: selected.locked
              ? null
              : (value) => onUpdateRegion(
                  selected.copyWith(width: value),
                  recordUndo: false,
                ),
        ),
        buildMosaicRatioSlider(
          label: context.l10n.mosaic_height,
          value: selected.height,
          min: 0.02,
          max: math.max(0.02, 1 - selected.top),
          onPushUndo: onPushUndo,
          onChanged: selected.locked
              ? null
              : (value) => onUpdateRegion(
                  selected.copyWith(height: value),
                  recordUndo: false,
                ),
        ),
      ],
    ),
  ] else
    LabeledSliderRows(
      sliders: [
        buildMosaicRatioSlider(
          label: context.l10n.mosaic_brushSize,
          value: selected.brushSizeRatio,
          min: 0.01,
          max: 0.16,
          onPushUndo: onPushUndo,
          onChanged: selected.locked ? null : onSetSelectedBrushSize,
        ),
      ],
    ),
];
