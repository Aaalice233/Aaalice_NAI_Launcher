part of 'image_editor_screen.dart';

extension _ImageEditorScreenFocused on _ImageEditorScreenState {
  _FocusedInpaintCostEstimate? _resolveFocusedInpaintCostEstimate() {
    final config = widget.focusedInpaintCostConfig;
    if (!_isInpaintMode || !_focusedInpaintEnabled || config == null) {
      return null;
    }

    final focusAreaRect = _focusedSelectionState.resolveActiveRect(
      previewPath: _state.previewPath,
    );
    if (focusAreaRect == null) {
      return null;
    }

    final requestSize = FocusedInpaintUtils.resolveRequestSizeForSelection(
      sourceWidth: _state.canvasSize.width.round(),
      sourceHeight: _state.canvasSize.height.round(),
      selectionRect: focusAreaRect,
      minContextMegaPixels: _minimumContextMegaPixels,
    );
    if (requestSize == null) {
      return null;
    }

    final cost = config.estimate(width: requestSize.$1, height: requestSize.$2);
    if (cost <= 0) {
      return null;
    }

    return _FocusedInpaintCostEstimate(
      width: requestSize.$1,
      height: requestSize.$2,
      cost: cost,
    );
  }

  Widget _buildFocusedSelectionCard() {
    final theme = Theme.of(context);
    final hasFocusArea =
        _focusedInpaintEnabled && _focusedSelectionState.hasCommittedRect;
    final costEstimate = _resolveFocusedInpaintCostEstimate();

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggleFocusedInpaint,
                  icon: Icon(
                    _focusedInpaintEnabled
                        ? Icons.crop_free
                        : Icons.filter_center_focus,
                    size: 16,
                  ),
                  label: Text(
                    _focusedInpaintEnabled
                        ? 'Focused Area Selection'
                        : 'Focused Inpaint',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            !_focusedInpaintEnabled
                ? context.l10n.editor_focusInactiveHint
                : hasFocusArea
                ? context.l10n.editor_focusReadyHint
                : context.l10n.editor_focusNeedsSelectionHint,
            style: theme.textTheme.bodySmall,
          ),
          if (_focusedInpaintEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildFocusModeButton(
                  icon: Icons.crop_square,
                  label: context.l10n.editor_focusSelection,
                  toolId: 'rect_selection',
                ),
                const SizedBox(width: 8),
                _buildFocusModeButton(
                  icon: Icons.brush_outlined,
                  label: context.l10n.editor_focusBrush,
                  toolId: 'brush',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _focusedSelectionState.hasCommittedRect
                    ? () {
                        _updateLayoutState(() {
                          _focusedSelectionState.clear();
                          _state.clearSelection(saveHistory: false);
                          _state.clearPreview();
                          _state.setToolById('rect_selection');
                        });
                      }
                    : null,
                icon: const Icon(Icons.clear, size: 16),
                label: Text(context.l10n.editor_clearSelection),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.editor_focusMinimumContextArea(
                _minimumContextMegaPixels.round(),
              ),
              style: theme.textTheme.labelMedium,
            ),
            Slider(
              value: _minimumContextMegaPixels,
              min: 16,
              max: 192,
              divisions: 176,
              onChanged: (value) {
                _updateLayoutState(() {
                  _minimumContextMegaPixels = value;
                });
              },
            ),
            if (costEstimate != null) ...[
              const SizedBox(height: 8),
              _buildFocusedAnlasWarning(costEstimate),
              const SizedBox(height: 8),
            ],
            Text(
              context.l10n.editor_focusContextHint,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFocusedAnlasWarning(_FocusedInpaintCostEstimate estimate) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.editor_focusAnlasWarning(
                estimate.width,
                estimate.height,
                estimate.cost,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFocusedInpaint() {
    if (_hasOutpaintChanges && !_focusedInpaintEnabled) {
      AppToast.warning(
        context,
        'Outpaint cannot be used together with Focused Inpaint.',
      );
      return;
    }

    _updateLayoutState(() {
      _focusedInpaintEnabled = !_focusedInpaintEnabled;
      if (_focusedInpaintEnabled) {
        if (!_focusedSelectionState.hasCommittedRect) {
          _state.setToolById('rect_selection');
        }
      } else {
        _state.clearSelection(saveHistory: false);
        _state.clearPreview();
        _focusedSelectionState.clear();
        _state.setToolById('brush');
      }
    });
  }

  void _consumeFocusedSelection() {
    if (!_isInpaintMode || !_focusedInpaintEnabled) {
      return;
    }
    if (_state.currentTool?.id != 'rect_selection') {
      return;
    }
    final consumed = _focusedSelectionState.captureSelection(
      _state.selectionPath,
    );
    if (!consumed) {
      return;
    }

    _state.clearSelection(saveHistory: false);
    _state.clearPreview();
    _state.setToolById('brush');
    _state.requestUiUpdate();
    if (mounted) {
      _updateLayoutState(() {});
    }
  }

  Widget _buildFocusModeButton({
    required IconData icon,
    required String label,
    required String toolId,
  }) {
    final theme = Theme.of(context);
    final selected = _state.currentTool?.id == toolId;

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () {
          _state.setToolById(toolId);
        },
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          backgroundColor: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _FocusedContextOverlayPainter extends CustomPainter {
  _FocusedContextOverlayPainter({
    required this.canvasController,
    required this.focusAreaRect,
    required this.contextCrop,
    super.repaint,
  });

  final CanvasController canvasController;
  final Rect focusAreaRect;
  final FocusedInpaintCrop contextCrop;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = canvasController.transformMatrix.storage;
    final screenSelectionPath = (Path()..addRect(focusAreaRect)).transform(
      matrix,
    );
    final screenContextPath =
        (Path()..addRect(
              Rect.fromLTWH(
                contextCrop.x.toDouble(),
                contextCrop.y.toDouble(),
                contextCrop.width.toDouble(),
                contextCrop.height.toDouble(),
              ),
            ))
            .transform(matrix);

    FocusedOverlayPainter(
      contextPath: screenContextPath,
      focusPath: screenSelectionPath,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _FocusedContextOverlayPainter oldDelegate) {
    return contextCrop.x != oldDelegate.contextCrop.x ||
        contextCrop.y != oldDelegate.contextCrop.y ||
        contextCrop.width != oldDelegate.contextCrop.width ||
        contextCrop.height != oldDelegate.contextCrop.height ||
        focusAreaRect != oldDelegate.focusAreaRect ||
        canvasController != oldDelegate.canvasController;
  }
}
