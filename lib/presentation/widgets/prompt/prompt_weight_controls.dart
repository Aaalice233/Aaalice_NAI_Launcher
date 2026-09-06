import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../themes/core/layered_surface_style.dart';

class PromptWeightControls extends StatefulWidget {
  const PromptWeightControls({
    super.key,
    required this.weight,
    required this.onWeight,
    required this.onStep,
    this.enabled = true,
    this.trailing = const [],
    this.caption,
    this.onClose,
    this.onEdit,
    this.showEdit = false,
  });
  final double? weight;
  final ValueChanged<double> onWeight;
  final ValueChanged<double> onStep;
  final bool enabled;
  final List<Widget> trailing;
  final Widget? caption;
  final VoidCallback? onClose;
  final VoidCallback? onEdit;
  final bool showEdit;
  @override
  State<PromptWeightControls> createState() => _PromptWeightControlsState();
}

class _PromptWeightControlsState extends State<PromptWeightControls> {
  late final TextEditingController _input;
  final FocusNode _focus = FocusNode();
  bool _invalid = false;
  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: _value);
  }

  String get _value => widget.weight?.toStringAsFixed(2) ?? '';
  @override
  void didUpdateWidget(PromptWeightControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weight != widget.weight) {
      _input.text = _value;
      _invalid = false;
    }
  }

  void _submit(String value) {
    final weight = double.tryParse(value);
    if (weight == null || !weight.isFinite || weight < 0.1 || weight > 3) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _invalid = false);
    widget.onWeight(weight);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final extent = context.interactionPolicy.minimumControlExtent.clamp(
      44.0,
      double.infinity,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildStepper(context, extent),
            if (widget.showEdit)
              TextButton.icon(
                key: const ValueKey('tag-edit-button'),
                onPressed: widget.onEdit,
                style: TextButton.styleFrom(minimumSize: Size(extent, extent)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.common_edit),
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: l10n.tooltip_resetWeight,
                  onPressed: widget.enabled ? () => widget.onWeight(1) : null,
                  constraints: BoxConstraints.tightFor(
                    width: extent,
                    height: extent,
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                ),
                ...widget.trailing,
                if (widget.onClose != null)
                  IconButton(
                    tooltip: l10n.common_close,
                    onPressed: widget.onClose,
                    constraints: BoxConstraints.tightFor(
                      width: extent,
                      height: extent,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepper(BuildContext context, double extent) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Material(
      color: controlSurfaceColor(theme.colorScheme),
      borderRadius: BorderRadius.circular(8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            tooltip: l10n.tooltip_decreaseWeight,
            onPressed: widget.enabled ? () => widget.onStep(-0.05) : null,
            constraints: BoxConstraints.tightFor(width: extent, height: extent),
            icon: const Icon(Icons.remove, size: 18),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.caption != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: widget.caption,
                  ),
                _buildValueInput(context),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.tooltip_increaseWeight,
            onPressed: widget.enabled ? () => widget.onStep(0.05) : null,
            constraints: BoxConstraints.tightFor(width: extent, height: extent),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildValueInput(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SizedBox(
      width: 24 + MediaQuery.textScalerOf(context).scale(40),
      child: Semantics(
        label: l10n.tagMode_weight,
        child: TextField(
          key: const ValueKey('prompt-weight-value'),
          controller: _input,
          focusNode: _focus,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            hintText: l10n.tagMode_mixedWeights,
            errorText: _invalid ? '0.10–3.00' : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.error),
            ),
          ),
          onSubmitted: _submit,
        ),
      ),
    );
  }
}
