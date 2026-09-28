import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../adaptive/interaction_policy.dart';
import '../../themes/core/input_surface_style.dart';

class EditableDoubleField extends StatefulWidget {
  const EditableDoubleField({
    super.key,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.decimals = 2,
    this.width = 64,
    this.textStyle,
    this.enabled = true,
  }) : assert(min == null || max == null || min <= max);

  final double value;
  final double? min;
  final double? max;
  final ValueChanged<double> onChanged;
  final int decimals;
  final double width;
  final TextStyle? textStyle;
  final bool enabled;

  @override
  State<EditableDoubleField> createState() => _EditableDoubleFieldState();
}

class _EditableDoubleFieldState extends State<EditableDoubleField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant EditableDoubleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || !parsed.isFinite) {
      _controller.text = _format(widget.value);
      return;
    }

    var normalized = parsed;
    final min = widget.min;
    final max = widget.max;
    if (min != null && normalized < min) {
      normalized = min;
    }
    if (max != null && normalized > max) {
      normalized = max;
    }
    if (normalized != widget.value) {
      widget.onChanged(normalized);
    }
    _controller.text = _format(normalized);
  }

  String _format(double value) => value.toStringAsFixed(widget.decimals);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = widget.textStyle ?? theme.textTheme.bodyLarge;
    final textPainter = TextPainter(
      text: TextSpan(text: _format(widget.value), style: textStyle),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final responsiveWidth = (textPainter.width + 16)
        .clamp(widget.width, double.infinity)
        .toDouble();

    return SizedBox(
      width: responsiveWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: context.interactionPolicy.minimumControlExtent,
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]')),
          ],
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            filled: true,
            fillColor: inputSurfaceFillColor(theme.colorScheme),
            border: inputSurfaceBorder(
              theme.colorScheme,
              BorderRadius.circular(8),
            ),
            enabledBorder: inputSurfaceBorder(
              theme.colorScheme,
              BorderRadius.circular(8),
            ),
            focusedBorder: inputSurfaceBorder(
              theme.colorScheme,
              BorderRadius.circular(8),
              focused: true,
            ),
          ),
          style: widget.textStyle,
          onSubmitted: (_) => _commit(),
        ),
      ),
    );
  }
}
