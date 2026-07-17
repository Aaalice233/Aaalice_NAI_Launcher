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

    final geometry = _resolveFocusedGeometryForWorkRect(focusAreaRect);
    if (geometry == null) {
      return null;
    }

    final cost = config.estimate(
      width: geometry.requestWidth,
      height: geometry.requestHeight,
    );

    return _FocusedInpaintCostEstimate(geometry: geometry, cost: cost);
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
                          _refreshCompressionPlan();
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
                  _constrainCommittedFocusedSelection();
                  _refreshCompressionPlan();
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 17,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.editor_focusRequestSummary(
                estimate.geometry.contextCrop.width,
                estimate.geometry.contextCrop.height,
                estimate.geometry.requestWidth,
                estimate.geometry.requestHeight,
                estimate.cost,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
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

    final desiredScale = _compressionLinearScale;
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
      _refreshCompressionPlan(desiredScale: desiredScale);
    });
  }

  void _syncFocusedSelectionConstraint() {
    if (!_isInpaintMode || !_focusedInpaintEnabled) {
      _state.setRectSelectionConstraint(null);
      return;
    }
    _state.setRectSelectionConstraint((candidate, fixedAnchor) {
      return _constrainFocusedWorkRect(candidate, fixedAnchor: fixedAnchor) ??
          candidate;
    });
  }

  void _constrainCommittedFocusedSelection() {
    final selection = _focusedSelectionState.committedRect;
    if (selection == null) return;
    final constrained = _constrainFocusedWorkRect(selection);
    _focusedSelectionState.load(constrained);
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
    _refreshCompressionPlan();
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
  final Rect contextCrop;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = canvasController.transformMatrix.storage;
    final screenSelectionPath = (Path()..addRect(focusAreaRect)).transform(
      matrix,
    );
    final screenContextPath = (Path()..addRect(contextCrop)).transform(matrix);

    FocusedOverlayPainter(
      contextPath: screenContextPath,
      focusPath: screenSelectionPath,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _FocusedContextOverlayPainter oldDelegate) {
    return contextCrop != oldDelegate.contextCrop ||
        focusAreaRect != oldDelegate.focusAreaRect ||
        canvasController != oldDelegate.canvasController;
  }
}
