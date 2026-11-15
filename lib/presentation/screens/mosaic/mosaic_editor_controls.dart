import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/mosaic/mosaic_settings.dart';
import '../../widgets/common/horizontal_segmented_control.dart';
import '../../widgets/common/labeled_slider_rows.dart';
import 'mosaic_editor_region_controls.dart';

/// 马赛克编辑器右侧/底部参数控制面板。
class MosaicEditorControlsPanel extends StatelessWidget {
  const MosaicEditorControlsPanel({
    super.key,
    required this.settings,
    required this.regions,
    required this.selectedRegion,
    required this.selectedId,
    required this.drawShape,
    required this.onPushUndo,
    required this.onChangeSettings,
    required this.onDrawShapeChanged,
    required this.onAddCentered,
    required this.onAddFullImageRegion,
    required this.onClearAll,
    required this.onPickFillColor,
    required this.onSelectRegion,
    required this.onUpdateRegion,
    required this.onSetSelectedShape,
    required this.onSetSelectedBrushSize,
    required this.onDuplicateSelected,
    required this.onDeleteSelected,
  });

  final MosaicSettings settings;
  final List<MosaicRegion> regions;
  final MosaicRegion? selectedRegion;
  final String? selectedId;
  final MosaicShape drawShape;
  final VoidCallback onPushUndo;
  final void Function(MosaicSettings value, {bool recordUndo}) onChangeSettings;
  final ValueChanged<MosaicShape> onDrawShapeChanged;
  final ValueChanged<MosaicShape> onAddCentered;
  final VoidCallback onAddFullImageRegion;
  final VoidCallback onClearAll;
  final void Function(Color initial, ValueChanged<Color> onChanged)
  onPickFillColor;
  final ValueChanged<String?> onSelectRegion;
  final void Function(MosaicRegion value, {bool recordUndo}) onUpdateRegion;
  final ValueChanged<MosaicShape> onSetSelectedShape;
  final ValueChanged<double> onSetSelectedBrushSize;
  final VoidCallback onDuplicateSelected;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final selected = selectedRegion;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        ..._buildExportControls(context),
        ..._buildDrawingControls(context),
        ..._buildEffectControls(context),
        ..._buildMaskControls(context),
        ...buildMosaicRegionListControls(
          context: context,
          regions: regions,
          selectedId: selectedId,
          onSelectRegion: onSelectRegion,
        ),
        if (selected != null)
          ...buildMosaicSelectedRegionControls(
            context: context,
            selected: selected,
            onPushUndo: onPushUndo,
            onUpdateRegion: onUpdateRegion,
            onSetSelectedShape: onSetSelectedShape,
            onSetSelectedBrushSize: onSetSelectedBrushSize,
            onDuplicateSelected: onDuplicateSelected,
            onDeleteSelected: onDeleteSelected,
          ),
        const SizedBox(height: 12),
        Text(
          context.l10n.mosaic_keyboardHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  List<Widget> _buildExportControls(BuildContext context) => [
    Text(
      '${_effectName(context, settings.effect)} · ${context.l10n.mosaic_regions}: ${regions.length}',
      style: Theme.of(context).textTheme.labelLarge,
    ),
    Text(
      context.l10n.mosaic_canvasHint,
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: 12),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        settings.preserveMetadata
            ? Icons.data_object_outlined
            : Icons.remove_circle_outline,
      ),
      title: Text(context.l10n.settings_mosaicPreserveMetadata),
      subtitle: Text(context.l10n.settings_mosaicPreserveMetadataHint),
      value: settings.preserveMetadata,
      onChanged: (value) =>
          onChangeSettings(settings.copyWith(preserveMetadata: value)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.history_toggle_off_outlined),
      title: Text(context.l10n.settings_mosaicRememberStyle),
      subtitle: Text(context.l10n.settings_mosaicRememberStyleHint),
      value: settings.rememberLastStyle,
      onChanged: (value) =>
          onChangeSettings(settings.copyWith(rememberLastStyle: value)),
    ),
    const Divider(),
  ];

  List<Widget> _buildDrawingControls(BuildContext context) => [
    buildMosaicSectionTitle(context, context.l10n.mosaic_drawTool),
    const SizedBox(height: 8),
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
        selected: {drawShape},
        onSelectionChanged: (value) => onDrawShapeChanged(value.first),
      ),
    ),
    const SizedBox(height: 8),
    Text(
      context.l10n.mosaic_drawHint,
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: 10),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => onAddCentered(drawShape),
          icon: const Icon(Icons.add_box_outlined),
          label: Text(context.l10n.mosaic_addRegion),
        ),
        OutlinedButton.icon(
          onPressed: onAddFullImageRegion,
          icon: const Icon(Icons.fullscreen),
          label: Text(context.l10n.mosaic_fullImage),
        ),
        OutlinedButton.icon(
          onPressed: regions.isEmpty ? null : onClearAll,
          icon: const Icon(Icons.layers_clear_outlined),
          label: Text(context.l10n.mosaic_clearAll),
        ),
      ],
    ),
    const Divider(height: 28),
  ];

  List<Widget> _buildEffectControls(BuildContext context) => [
    buildMosaicSectionTitle(context, context.l10n.mosaic_effect),
    const SizedBox(height: 8),
    HorizontalSegmentedControl(
      child: SegmentedButton<MosaicEffect>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: MosaicEffect.pixelate,
            icon: const Icon(Icons.grid_on_rounded),
            label: Text(context.l10n.mosaic_effectPixelate),
          ),
          ButtonSegment(
            value: MosaicEffect.blur,
            icon: const Icon(Icons.blur_on_outlined),
            label: Text(context.l10n.mosaic_effectBlur),
          ),
          ButtonSegment(
            value: MosaicEffect.solid,
            icon: const Icon(Icons.crop_square_rounded),
            label: Text(context.l10n.mosaic_effectSolid),
          ),
        ],
        selected: {settings.effect},
        onSelectionChanged: (value) =>
            onChangeSettings(settings.copyWith(effect: value.first)),
      ),
    ),
    const SizedBox(height: 10),
    if (settings.effect == MosaicEffect.pixelate)
      LabeledSliderRows(
        sliders: [
          buildMosaicRatioSlider(
            label: context.l10n.mosaic_pixelSize,
            value: settings.pixelSizeRatio,
            min: 0.004,
            max: 0.08,
            onPushUndo: onPushUndo,
            onChanged: (value) => onChangeSettings(
              settings.copyWith(pixelSizeRatio: value),
              recordUndo: false,
            ),
          ),
        ],
      ),
    if (settings.effect == MosaicEffect.blur)
      LabeledSliderRows(
        sliders: [
          buildMosaicRatioSlider(
            label: context.l10n.mosaic_blurStrength,
            value: settings.blurSigmaRatio,
            min: 0.003,
            max: 0.06,
            onPushUndo: onPushUndo,
            onChanged: (value) => onChangeSettings(
              settings.copyWith(blurSigmaRatio: value),
              recordUndo: false,
            ),
          ),
        ],
      ),
    if (settings.effect == MosaicEffect.solid)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Color(settings.fillColorArgb),
          child: const Icon(Icons.palette_outlined),
        ),
        title: Text(context.l10n.mosaic_color),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onPickFillColor(
          Color(settings.fillColorArgb),
          (color) => onChangeSettings(
            settings.copyWith(fillColorArgb: color.toARGB32()),
          ),
        ),
      ),
  ];

  List<Widget> _buildMaskControls(BuildContext context) => [
    LabeledSliderRows(
      sliders: [
        buildMosaicRatioSlider(
          label: context.l10n.mosaic_opacity,
          value: settings.opacity,
          min: 0.1,
          max: 1,
          onPushUndo: onPushUndo,
          onChanged: (value) => onChangeSettings(
            settings.copyWith(opacity: value),
            recordUndo: false,
          ),
        ),
        buildMosaicRatioSlider(
          label: context.l10n.mosaic_cornerRadius,
          value: settings.cornerRadiusRatio,
          min: 0,
          max: 0.5,
          onPushUndo: onPushUndo,
          onChanged: (value) => onChangeSettings(
            settings.copyWith(cornerRadiusRatio: value),
            recordUndo: false,
          ),
        ),
        buildMosaicRatioSlider(
          label: context.l10n.mosaic_brushSize,
          value: settings.brushSizeRatio,
          min: 0.01,
          max: 0.16,
          onPushUndo: onPushUndo,
          onChanged: (value) {
            onChangeSettings(
              settings.copyWith(brushSizeRatio: value),
              recordUndo: false,
            );
            if (selectedRegion?.shape == MosaicShape.brush) {
              onSetSelectedBrushSize(value);
            }
          },
        ),
      ],
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.flip),
      title: Text(context.l10n.mosaic_invertMask),
      subtitle: Text(context.l10n.mosaic_invertMaskHint),
      value: settings.invertMask,
      onChanged: (value) =>
          onChangeSettings(settings.copyWith(invertMask: value)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.numbers),
      title: Text(context.l10n.mosaic_showLabels),
      value: settings.showRegionLabels,
      onChanged: (value) =>
          onChangeSettings(settings.copyWith(showRegionLabels: value)),
    ),
    const Divider(height: 28),
  ];

  String _effectName(BuildContext context, MosaicEffect effect) =>
      switch (effect) {
        MosaicEffect.pixelate => context.l10n.mosaic_effectPixelate,
        MosaicEffect.blur => context.l10n.mosaic_effectBlur,
        MosaicEffect.solid => context.l10n.mosaic_effectSolid,
      };
}
