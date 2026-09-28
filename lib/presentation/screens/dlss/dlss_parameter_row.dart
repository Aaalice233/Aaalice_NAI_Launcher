import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps explanations available without turning every parameter into a paragraph.
class DlssParameterRow extends StatefulWidget {
  const DlssParameterRow({
    super.key,
    required this.label,
    required this.description,
    this.trailing,
    this.error,
    this.valueLabel,
  });
  final String label;
  final String description;
  final Widget? trailing;
  final String? error;
  final String? valueLabel;

  @override
  State<DlssParameterRow> createState() => _DlssParameterRowState();
}

class _DlssParameterRowState extends State<DlssParameterRow> {
  bool _showHelp = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('dlss-help-${widget.label}'),
                tooltip: widget.label,
                isSelected: _showHelp,
                onPressed: () => setState(() => _showHelp = !_showHelp),
                icon: const Icon(Icons.info_outline, size: 17),
                selectedIcon: const Icon(Icons.info, size: 17),
                color: theme.colorScheme.onSurfaceVariant,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: math.min(
                    constraints.maxWidth * 0.42,
                    96 * math.sqrt(MediaQuery.textScalerOf(context).scale(1)),
                  ),
                  child: widget.trailing,
                ),
              ],
            ],
          ),
        ),
        if (widget.valueLabel != null)
          Text(
            widget.valueLabel!,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (_showHelp)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              widget.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        if (widget.error != null)
          Text(
            widget.error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

InputDecoration dlssNumberDecoration(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    filled: true,
    fillColor: colors.surfaceContainerHighest,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: colors.primary),
    ),
  );
}
