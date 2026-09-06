import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_options.dart';
import 'dlss_parameter_row.dart';

class DlssParameterSlider extends StatefulWidget {
  const DlssParameterSlider({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.minimum = 0,
    this.maximum,
    this.valueLabel,
  });

  final String label;
  final String description;
  final double value;
  final ValueChanged<double>? onChanged;
  final double minimum;
  final double? maximum;
  final String? valueLabel;

  @override
  State<DlssParameterSlider> createState() => _DlssParameterSliderState();
}

class _DlssParameterSliderState extends State<DlssParameterSlider> {
  late final TextEditingController _text;
  final _focus = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _formattedValue);
    _focus.addListener(_onFocusChanged);
  }

  String get _formattedValue => widget.value.toString();

  @override
  void didUpdateWidget(covariant DlssParameterSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _text.text = _formattedValue;
      _invalid = false;
    }
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _submit();
  }

  void _submit() {
    if (!mounted || widget.onChanged == null) return;
    final value = double.tryParse(_text.text.trim());
    final valid =
        value != null &&
        value.isFinite &&
        value >= widget.minimum &&
        value <= (widget.maximum ?? DlssOptions.maximumStrength);
    setState(() => _invalid = !valid);
    if (valid && value != widget.value) widget.onChanged!(value);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maximum = math.max(
      math.min(widget.maximum ?? 2.0, 4.0),
      widget.value,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DlssParameterRow(
            label: widget.label,
            description: widget.description,
            valueLabel: widget.valueLabel,
            error: _invalid ? context.l10n.dlss_invalidNumber : null,
            trailing: Semantics(
              label: widget.label,
              child: TextField(
                key: ValueKey('dlss-value-${widget.label}'),
                controller: _text,
                focusNode: _focus,
                enabled: widget.onChanged != null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.end,
                decoration: dlssNumberDecoration(context),
                onSubmitted: (_) => _submit(),
                onTapOutside: (_) => _focus.unfocus(),
              ),
            ),
          ),
          Slider(
            value: widget.value,
            min: widget.minimum,
            max: maximum,
            divisions: maximum <= 2
                ? ((maximum - widget.minimum) / 0.05).round()
                : null,
            label: widget.valueLabel ?? widget.value.toString(),
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }
}
