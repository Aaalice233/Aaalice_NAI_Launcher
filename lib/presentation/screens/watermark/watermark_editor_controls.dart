import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/watermark/watermark_font_catalog.dart';
import '../../../data/models/watermark/watermark_settings.dart';
import '../../widgets/image_editor/widgets/color_picker.dart';

class WatermarkEditorControls extends StatelessWidget {
  const WatermarkEditorControls({
    super.key,
    required this.settings,
    required this.layout,
    required this.selectedLayer,
    required this.logoAvailable,
    required this.preserveMetadata,
    required this.onOpenMetadataSettings,
    required this.onSettingsChanged,
    required this.onLayoutChanged,
    required this.onSelectedLayerChanged,
    required this.onChooseLogo,
  });

  final WatermarkSettings settings;
  final WatermarkLayout layout;
  final WatermarkEditableLayer selectedLayer;
  final bool logoAvailable;
  final bool preserveMetadata;
  final VoidCallback onOpenMetadataSettings;
  final ValueChanged<WatermarkSettings> onSettingsChanged;
  final ValueChanged<WatermarkLayout> onLayoutChanged;
  final ValueChanged<WatermarkEditableLayer> onSelectedLayerChanged;
  final VoidCallback onChooseLogo;

  @override
  Widget build(BuildContext context) {
    final text = settings.textStyle;
    final logo = settings.logoStyle;
    final selectedPlacement = selectedLayer == WatermarkEditableLayer.text
        ? layout.textPlacement
        : layout.logoPlacement;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            preserveMetadata
                ? Icons.data_object_outlined
                : Icons.remove_circle_outline,
          ),
          title: Text(
            preserveMetadata
                ? context.l10n.watermark_metadataPreserved
                : context.l10n.watermark_metadataRemoved,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.settings_outlined),
          onTap: onOpenMetadataSettings,
        ),
        const SizedBox(height: 8),
        SegmentedButton<WatermarkEditableLayer>(
          segments: [
            ButtonSegment(
              value: WatermarkEditableLayer.text,
              icon: const Icon(Icons.text_fields),
              label: Text(context.l10n.watermark_textLayer),
            ),
            ButtonSegment(
              value: WatermarkEditableLayer.logo,
              icon: const Icon(Icons.image_outlined),
              label: Text(context.l10n.watermark_logoLayer),
            ),
          ],
          selected: {selectedLayer},
          onSelectionChanged: (value) => onSelectedLayerChanged(value.first),
        ),
        const SizedBox(height: 12),
        if (selectedLayer == WatermarkEditableLayer.text) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.watermark_enableLayer),
            value: text.enabled,
            onChanged: (value) => onSettingsChanged(
              settings.copyWith(textStyle: text.copyWith(enabled: value)),
            ),
          ),
          _WatermarkTextField(
            value: text.text,
            label: context.l10n.watermark_text,
            onChanged: (value) => onSettingsChanged(
              settings.copyWith(textStyle: text.copyWith(text: value)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: WatermarkFontCatalog.contains(text.fontFamily)
                ? text.fontFamily
                : WatermarkFontCatalog.options.first.family,
            decoration: _controlDecoration(
              context,
              context.l10n.watermark_font,
            ),
            items: [
              for (final option in WatermarkFontCatalog.options)
                DropdownMenuItem(
                  value: option.family,
                  child: Text(
                    text.text.trim().isEmpty ? option.sample : text.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: option.family,
                      fontFamilyFallback: WatermarkFontCatalog.fallbackFamilies,
                      fontSize: 20,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onSettingsChanged(
                  settings.copyWith(
                    textStyle: text.copyWith(fontFamily: value),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Color(text.colorArgb),
              child: const Icon(Icons.palette_outlined),
            ),
            title: Text(context.l10n.editor_toolColorPicker),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickColor(context, Color(text.colorArgb), (color) {
              onSettingsChanged(
                settings.copyWith(
                  textStyle: text.copyWith(colorArgb: color.toARGB32()),
                ),
              );
            }),
          ),
          Text(
            context.l10n.watermark_alignment,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<WatermarkTextAlignment>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: WatermarkTextAlignment.left,
                icon: const Icon(Icons.format_align_left),
                label: Text(context.l10n.watermark_alignLeft),
                tooltip: context.l10n.watermark_alignLeft,
              ),
              ButtonSegment(
                value: WatermarkTextAlignment.center,
                icon: const Icon(Icons.format_align_center),
                label: Text(context.l10n.watermark_alignCenter),
                tooltip: context.l10n.watermark_alignCenter,
              ),
              ButtonSegment(
                value: WatermarkTextAlignment.right,
                icon: const Icon(Icons.format_align_right),
                label: Text(context.l10n.watermark_alignRight),
                tooltip: context.l10n.watermark_alignRight,
              ),
            ],
            selected: {text.alignment},
            onSelectionChanged: (value) => onSettingsChanged(
              settings.copyWith(
                textStyle: text.copyWith(alignment: value.first),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _RatioSlider(
            label: context.l10n.watermark_letterSpacing,
            value: text.letterSpacingRatio,
            min: -0.02,
            max: 0.08,
            onChanged: (value) => onSettingsChanged(
              settings.copyWith(
                textStyle: text.copyWith(letterSpacingRatio: value),
              ),
            ),
          ),
          _RatioSlider(
            label: context.l10n.watermark_stroke,
            value: text.strokeWidthRatio,
            min: 0,
            max: 0.012,
            onChanged: (value) => onSettingsChanged(
              settings.copyWith(
                textStyle: text.copyWith(strokeWidthRatio: value),
              ),
            ),
          ),
          _RatioSlider(
            label: context.l10n.watermark_shadow,
            value: text.shadowBlurRatio,
            min: 0,
            max: 0.04,
            onChanged: (value) => onSettingsChanged(
              settings.copyWith(
                textStyle: text.copyWith(shadowBlurRatio: value),
              ),
            ),
          ),
        ] else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.watermark_enableLayer),
            subtitle: !logoAvailable && logo.enabled
                ? Text(
                    context.l10n.watermark_logoMissing,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : null,
            value: logo.enabled,
            onChanged: (value) => onSettingsChanged(
              settings.copyWith(logoStyle: logo.copyWith(enabled: value)),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onChooseLogo,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              logoAvailable
                  ? context.l10n.watermark_replaceLogo
                  : context.l10n.watermark_chooseLogo,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _RatioSlider(
          label: context.l10n.watermark_opacity,
          value: selectedLayer == WatermarkEditableLayer.text
              ? text.opacity
              : logo.opacity,
          min: 0.05,
          max: 1,
          onChanged: (value) => onSettingsChanged(
            selectedLayer == WatermarkEditableLayer.text
                ? settings.copyWith(textStyle: text.copyWith(opacity: value))
                : settings.copyWith(logoStyle: logo.copyWith(opacity: value)),
          ),
        ),
        _RatioSlider(
          label: context.l10n.watermark_size,
          value: selectedPlacement.sizeRatio,
          min: 0.02,
          max: selectedLayer == WatermarkEditableLayer.text ? 0.25 : 0.6,
          onChanged: (value) =>
              _updatePlacement(selectedPlacement.copyWith(sizeRatio: value)),
        ),
        _RatioSlider(
          label: context.l10n.watermark_margin,
          value: selectedPlacement.marginRatio,
          min: 0,
          max: 0.2,
          onChanged: (value) =>
              _updatePlacement(selectedPlacement.copyWith(marginRatio: value)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<WatermarkAnchor>(
          initialValue: selectedPlacement.anchor,
          decoration: _controlDecoration(
            context,
            context.l10n.watermark_anchor,
          ),
          items: [
            for (final anchor in WatermarkAnchor.values)
              DropdownMenuItem(
                value: anchor,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_anchorIcon(anchor), size: 20),
                    const SizedBox(width: 8),
                    Flexible(child: Text(_anchorName(context, anchor))),
                  ],
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              _updatePlacement(
                selectedPlacement.copyWith(
                  anchor: value,
                  offsetXRatio: 0,
                  offsetYRatio: 0,
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<WatermarkLayerArrangement>(
          initialValue: settings.composition.arrangement,
          decoration: _controlDecoration(
            context,
            context.l10n.watermark_layerArrangement,
          ),
          items: [
            DropdownMenuItem(
              value: WatermarkLayerArrangement.independent,
              child: Text(context.l10n.watermark_arrangementIndependent),
            ),
            DropdownMenuItem(
              value: WatermarkLayerArrangement.horizontal,
              child: Text(context.l10n.watermark_arrangementHorizontal),
            ),
            DropdownMenuItem(
              value: WatermarkLayerArrangement.vertical,
              child: Text(context.l10n.watermark_arrangementVertical),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onSettingsChanged(
                settings.copyWith(
                  composition: settings.composition.copyWith(
                    arrangement: value,
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            final other = selectedLayer == WatermarkEditableLayer.text
                ? layout.logoPlacement
                : layout.textPlacement;
            _updatePlacement(
              selectedPlacement.copyWith(zIndex: other.zIndex + 1),
            );
          },
          icon: const Icon(Icons.flip_to_front_outlined),
          label: Text(context.l10n.watermark_zOrder),
        ),
      ],
    );
  }

  InputDecoration _controlDecoration(BuildContext context, String label) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainer,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );

  void _updatePlacement(WatermarkPlacement placement) {
    onLayoutChanged(
      selectedLayer == WatermarkEditableLayer.text
          ? layout.copyWith(textPlacement: placement)
          : layout.copyWith(logoPlacement: placement),
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    Color initial,
    ValueChanged<Color> onChanged,
  ) async {
    var selected = initial;
    final result = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        title: Text(context.l10n.editor_toolColorPicker),
        content: SizedBox(
          width: math.min(320, MediaQuery.sizeOf(dialogContext).width - 64),
          child: HSVColorPicker(
            color: initial,
            hexLabel: context.l10n.editor_colorHex,
            saturationBrightnessLabel:
                context.l10n.editor_colorSaturationBrightness,
            hueLabel: context.l10n.editor_colorHue,
            hueHeight: 48,
            onColorChanged: (value) => selected = value,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(selected),
            child: Text(context.l10n.common_confirm),
          ),
        ],
      ),
    );
    if (result != null) onChanged(result);
  }

  static IconData _anchorIcon(WatermarkAnchor anchor) => switch (anchor) {
    WatermarkAnchor.topLeft => Icons.north_west,
    WatermarkAnchor.topCenter => Icons.north,
    WatermarkAnchor.topRight => Icons.north_east,
    WatermarkAnchor.centerLeft => Icons.west,
    WatermarkAnchor.center => Icons.center_focus_weak,
    WatermarkAnchor.centerRight => Icons.east,
    WatermarkAnchor.bottomLeft => Icons.south_west,
    WatermarkAnchor.bottomCenter => Icons.south,
    WatermarkAnchor.bottomRight => Icons.south_east,
  };

  static String _anchorName(BuildContext context, WatermarkAnchor anchor) =>
      switch (anchor) {
        WatermarkAnchor.topLeft => context.l10n.watermark_anchorTopLeft,
        WatermarkAnchor.topCenter => context.l10n.watermark_anchorTopCenter,
        WatermarkAnchor.topRight => context.l10n.watermark_anchorTopRight,
        WatermarkAnchor.centerLeft => context.l10n.watermark_anchorCenterLeft,
        WatermarkAnchor.center => context.l10n.watermark_anchorCenter,
        WatermarkAnchor.centerRight => context.l10n.watermark_anchorCenterRight,
        WatermarkAnchor.bottomLeft => context.l10n.watermark_anchorBottomLeft,
        WatermarkAnchor.bottomCenter =>
          context.l10n.watermark_anchorBottomCenter,
        WatermarkAnchor.bottomRight => context.l10n.watermark_anchorBottomRight,
      };
}

enum WatermarkEditableLayer { text, logo }

class _RatioSlider extends StatelessWidget {
  const _RatioSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '${(value * 100).toStringAsFixed(1)}%',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final percentage = Text('${(value * 100).toStringAsFixed(0)}%');
        final slider = Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        );
        if (constraints.maxWidth < 350 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              Row(
                children: [
                  Expanded(child: slider),
                  percentage,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 112, child: Text(label)),
            Expanded(child: slider),
            SizedBox(width: 52, child: percentage),
          ],
        );
      },
    ),
  );
}

class _WatermarkTextField extends StatefulWidget {
  const _WatermarkTextField({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_WatermarkTextField> createState() => _WatermarkTextFieldState();
}

class _WatermarkTextFieldState extends State<_WatermarkTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _WatermarkTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    maxLines: 3,
    minLines: 1,
    decoration: InputDecoration(
      labelText: widget.label,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainer,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    ),
    onChanged: widget.onChanged,
  );
}
