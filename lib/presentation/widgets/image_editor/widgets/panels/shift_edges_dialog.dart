import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/utils/inpaint_outpaint_utils.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../../widgets/common/themed_input.dart';

class ShiftEdgesResult {
  final OutpaintEdges requestedEdges;
  final OutpaintEdges appliedEdges;
  final int width;
  final int height;
  final OutpaintHorizontalSnapTarget horizontalSnapTarget;
  final OutpaintVerticalSnapTarget verticalSnapTarget;

  const ShiftEdgesResult({
    required this.requestedEdges,
    required this.appliedEdges,
    required this.width,
    required this.height,
    required this.horizontalSnapTarget,
    required this.verticalSnapTarget,
  });
}

class ShiftEdgesDialog extends StatefulWidget {
  final int sourceWidth;
  final int sourceHeight;
  final ScrollController? scrollController;

  const ShiftEdgesDialog({
    super.key,
    required this.sourceWidth,
    required this.sourceHeight,
    this.scrollController,
  });

  static Future<ShiftEdgesResult?> show(
    BuildContext context, {
    required int sourceWidth,
    required int sourceHeight,
  }) {
    return AdaptivePresenter.showForm<ShiftEdgesResult>(
      context: context,
      dialogWidth: 480,
      titleBuilder: (context) => Text(
        context.l10n.editor_shiftEdges,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      builder: (context, scrollController) => ShiftEdgesDialog(
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        scrollController: scrollController,
      ),
    );
  }

  @override
  State<ShiftEdgesDialog> createState() => _ShiftEdgesDialogState();
}

class _ShiftEdgesDialogState extends State<ShiftEdgesDialog> {
  static const int _snapSize = 64;
  static const int _maxDimension = 4096;

  final _topController = TextEditingController(text: '0');
  final _rightController = TextEditingController(text: '0');
  final _bottomController = TextEditingController(text: '0');
  final _leftController = TextEditingController(text: '0');

  final OutpaintHorizontalSnapTarget _horizontalSnapTarget =
      OutpaintHorizontalSnapTarget.right;
  final OutpaintVerticalSnapTarget _verticalSnapTarget =
      OutpaintVerticalSnapTarget.bottom;

  @override
  void dispose() {
    _topController.dispose();
    _rightController.dispose();
    _bottomController.dispose();
    _leftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): _ConfirmIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
      },
      child: Actions(
        actions: {
          _ConfirmIntent: CallbackAction<_ConfirmIntent>(
            onInvoke: (_) {
              if (_canConfirm(preview)) {
                _confirm(preview);
              }
              return null;
            },
          ),
          _CancelIntent: CallbackAction<_CancelIntent>(
            onInvoke: (_) {
              Navigator.pop(context);
              return null;
            },
          ),
        },
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('shift_edges_scroll'),
                controller: widget.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    context.l10n.editor_currentSize(
                      widget.sourceWidth,
                      widget.sourceHeight,
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _EdgeInputRow(
                    first: _EdgeInput(
                      key: const Key('shift_edges_left'),
                      label: context.l10n.editor_edgeLeft,
                      controller: _leftController,
                      errorText: _edgeErrorText(_leftController.text),
                      onChanged: _handleChanged,
                    ),
                    second: _EdgeInput(
                      key: const Key('shift_edges_right'),
                      label: context.l10n.editor_edgeRight,
                      controller: _rightController,
                      errorText: _edgeErrorText(_rightController.text),
                      onChanged: _handleChanged,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EdgeInputRow(
                    first: _EdgeInput(
                      key: const Key('shift_edges_top'),
                      label: context.l10n.editor_edgeTop,
                      controller: _topController,
                      errorText: _edgeErrorText(_topController.text),
                      onChanged: _handleChanged,
                    ),
                    second: _EdgeInput(
                      key: const Key('shift_edges_bottom'),
                      label: context.l10n.editor_edgeBottom,
                      controller: _bottomController,
                      errorText: _edgeErrorText(_bottomController.text),
                      onChanged: _handleChanged,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SizeSummary(preview: preview),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildActions(preview),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(_ShiftEdgesPreview preview) {
    final cancel = TextButton(
      key: const Key('shift_edges_cancel'),
      onPressed: () => Navigator.pop(context),
      child: Text(context.l10n.common_cancel, textAlign: TextAlign.center),
    );
    final confirm = FilledButton(
      key: const Key('shift_edges_confirm'),
      onPressed: _canConfirm(preview) ? () => _confirm(preview) : null,
      child: Text(context.l10n.editor_shiftEdges, textAlign: TextAlign.center),
    );
    if (MediaQuery.textScalerOf(context).scale(1) >= 2) {
      return HorizontalActionStrip(
        reverse: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [cancel, const SizedBox(width: 8), confirm],
        ),
      );
    }
    return Row(
      children: [
        Expanded(child: cancel),
        const SizedBox(width: 8),
        Expanded(child: confirm),
      ],
    );
  }

  _ShiftEdgesPreview get _preview {
    final left = _parseEdge(_leftController.text);
    final top = _parseEdge(_topController.text);
    final right = _parseEdge(_rightController.text);
    final bottom = _parseEdge(_bottomController.text);

    if (left == null || top == null || right == null || bottom == null) {
      return _ShiftEdgesPreview.invalid();
    }

    final requestedWidth = widget.sourceWidth + left + right;
    final requestedHeight = widget.sourceHeight + top + bottom;
    final widthRemainder = _snapRemainder(requestedWidth);
    final heightRemainder = _snapRemainder(requestedHeight);

    var appliedLeft = left;
    var appliedTop = top;
    var appliedRight = right;
    var appliedBottom = bottom;

    if (_horizontalSnapTarget == OutpaintHorizontalSnapTarget.left) {
      appliedLeft += widthRemainder;
    } else {
      appliedRight += widthRemainder;
    }

    if (_verticalSnapTarget == OutpaintVerticalSnapTarget.top) {
      appliedTop += heightRemainder;
    } else {
      appliedBottom += heightRemainder;
    }

    return _ShiftEdgesPreview(
      requestedEdges: OutpaintEdges(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
      appliedEdges: OutpaintEdges(
        left: appliedLeft,
        top: appliedTop,
        right: appliedRight,
        bottom: appliedBottom,
      ),
      requestedWidth: requestedWidth,
      requestedHeight: requestedHeight,
      appliedWidth: requestedWidth + widthRemainder,
      appliedHeight: requestedHeight + heightRemainder,
    );
  }

  int? _parseEdge(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
  }

  String? _edgeErrorText(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return context.l10n.editor_enterNumber;
    }
    if (parsed < 0) {
      return context.l10n.editor_nonNegativeNumber;
    }
    return null;
  }

  int _snapRemainder(int value) {
    return (_snapSize - value % _snapSize) % _snapSize;
  }

  bool _canConfirm(_ShiftEdgesPreview preview) {
    if (!preview.isValid) {
      return false;
    }
    if (preview.requestedEdges.isEmpty) {
      return false;
    }
    return preview.appliedWidth <= _maxDimension &&
        preview.appliedHeight <= _maxDimension;
  }

  void _confirm(_ShiftEdgesPreview preview) {
    Navigator.pop(
      context,
      ShiftEdgesResult(
        requestedEdges: preview.requestedEdges,
        appliedEdges: preview.appliedEdges,
        width: preview.appliedWidth,
        height: preview.appliedHeight,
        horizontalSnapTarget: _horizontalSnapTarget,
        verticalSnapTarget: _verticalSnapTarget,
      ),
    );
  }

  void _handleChanged(String _) {
    setState(() {});
  }
}

class _EdgeInputRow extends StatelessWidget {
  const _EdgeInputRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumFieldWidth = MediaQuery.textScalerOf(context).scale(104);
        if (constraints.maxWidth >= minimumFieldWidth * 2 + 12) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          );
        }
        return Column(children: [first, const SizedBox(height: 12), second]);
      },
    );
  }
}

class _EdgeInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const _EdgeInput({
    super.key,
    required this.label,
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedInput(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'px',
        isDense: true,
        errorText: errorText,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
    );
  }
}

class _SizeSummary extends StatelessWidget {
  final _ShiftEdgesPreview preview;

  const _SizeSummary({required this.preview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final hasOversizedAppliedDimensions =
        preview.isValid &&
        (preview.appliedWidth > _ShiftEdgesDialogState._maxDimension ||
            preview.appliedHeight > _ShiftEdgesDialogState._maxDimension);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.isValid
                ? l10n.editor_requestedSize(
                    preview.requestedWidth,
                    preview.requestedHeight,
                  )
                : l10n.editor_requestedSizeInvalid,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            preview.isValid
                ? l10n.editor_appliedSize(
                    preview.appliedWidth,
                    preview.appliedHeight,
                  )
                : l10n.editor_appliedSizeInvalid,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasOversizedAppliedDimensions
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            preview.isValid
                ? l10n.editor_appliedEdges(
                    preview.appliedEdges.left,
                    preview.appliedEdges.top,
                    preview.appliedEdges.right,
                    preview.appliedEdges.bottom,
                  )
                : l10n.editor_appliedEdgesInvalid,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          if (hasOversizedAppliedDimensions) ...[
            const SizedBox(height: 8),
            Text(
              l10n.editor_appliedDimensionLimit(
                _ShiftEdgesDialogState._maxDimension,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftEdgesPreview {
  final OutpaintEdges requestedEdges;
  final OutpaintEdges appliedEdges;
  final int requestedWidth;
  final int requestedHeight;
  final int appliedWidth;
  final int appliedHeight;
  final bool isValid;

  const _ShiftEdgesPreview({
    required this.requestedEdges,
    required this.appliedEdges,
    required this.requestedWidth,
    required this.requestedHeight,
    required this.appliedWidth,
    required this.appliedHeight,
    this.isValid = true,
  });

  factory _ShiftEdgesPreview.invalid() {
    return const _ShiftEdgesPreview(
      requestedEdges: OutpaintEdges(),
      appliedEdges: OutpaintEdges(),
      requestedWidth: 0,
      requestedHeight: 0,
      appliedWidth: 0,
      appliedHeight: 0,
      isValid: false,
    );
  }
}

class _ConfirmIntent extends Intent {
  const _ConfirmIntent();
}

class _CancelIntent extends Intent {
  const _CancelIntent();
}
