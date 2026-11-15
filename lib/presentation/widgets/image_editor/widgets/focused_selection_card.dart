import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../common/themed_slider.dart';
import '../core/editor_state.dart';
import '../image_editor_types.dart';

/// 重绘模式画布左上角的聚焦重绘（Focused Inpaint）悬浮控制卡片。
class FocusedSelectionCard extends StatelessWidget {
  const FocusedSelectionCard({
    super.key,
    required this.state,
    required this.focusedInpaintEnabled,
    required this.hasCommittedRect,
    required this.minimumContextMegaPixels,
    required this.costEstimate,
    required this.onToggleFocusedInpaint,
    required this.onClearSelection,
    required this.onMinimumContextChanged,
  });

  final EditorState state;
  final bool focusedInpaintEnabled;
  final bool hasCommittedRect;
  final double minimumContextMegaPixels;
  final FocusedInpaintCostEstimate? costEstimate;
  final VoidCallback onToggleFocusedInpaint;
  final VoidCallback onClearSelection;
  final ValueChanged<double> onMinimumContextChanged;

  static String _contextAreaText(double megaPixels) => '${megaPixels.round()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFocusArea = focusedInpaintEnabled && hasCommittedRect;
    final estimate = costEstimate;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  onPressed: onToggleFocusedInpaint,
                  icon: Icon(
                    focusedInpaintEnabled
                        ? Icons.crop_free
                        : Icons.filter_center_focus,
                    size: 16,
                  ),
                  label: Text(
                    focusedInpaintEnabled
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
            !focusedInpaintEnabled
                ? context.l10n.editor_focusInactiveHint
                : hasFocusArea
                ? context.l10n.editor_focusReadyHint
                : context.l10n.editor_focusNeedsSelectionHint,
            style: theme.textTheme.bodySmall,
          ),
          if (focusedInpaintEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _FocusModeButton(
                  state: state,
                  icon: Icons.crop_square,
                  label: context.l10n.editor_focusSelection,
                  toolId: 'rect_selection',
                ),
                const SizedBox(width: 8),
                _FocusModeButton(
                  state: state,
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
                onPressed: hasCommittedRect ? onClearSelection : null,
                icon: const Icon(Icons.clear, size: 16),
                label: Text(context.l10n.editor_clearSelection),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.editor_focusMinimumContextArea(
                _contextAreaText(minimumContextMegaPixels),
              ),
              style: theme.textTheme.labelMedium,
            ),
            NamedSlider(
              label: context.l10n.editor_focusMinimumContextAreaLabel,
              valueText: _contextAreaText,
              value: minimumContextMegaPixels,
              min: 16,
              max: 192,
              divisions: 176,
              onChanged: onMinimumContextChanged,
            ),
            if (estimate != null) ...[
              const SizedBox(height: 8),
              _FocusedAnlasWarning(estimate: estimate),
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
}

class _FocusedAnlasWarning extends StatelessWidget {
  const _FocusedAnlasWarning({required this.estimate});

  final FocusedInpaintCostEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
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
}

class _FocusModeButton extends StatelessWidget {
  const _FocusModeButton({
    required this.state,
    required this.icon,
    required this.label,
    required this.toolId,
  });

  final EditorState state;
  final IconData icon;
  final String label;
  final String toolId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = state.currentTool?.id == toolId;

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () {
          state.setToolById(toolId);
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
