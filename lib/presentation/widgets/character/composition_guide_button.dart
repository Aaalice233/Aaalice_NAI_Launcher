import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/composition_guide_provider.dart';
import '../common/composition_guide.dart';
import '../common/draggable_number_input.dart';

/// 构图参考线入口：方形按钮 + 向下弹出的档位浮层
class CompositionGuideButton extends ConsumerStatefulWidget {
  const CompositionGuideButton({super.key});

  @override
  ConsumerState<CompositionGuideButton> createState() =>
      _CompositionGuideButtonState();
}

class _CompositionGuideButtonState
    extends ConsumerState<CompositionGuideButton> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();

  void _close() {
    // 走 setState：按钮高亮跟着 isShowing 算，点空白关闭时也要刷新
    if (_controller.isShowing) setState(_controller.hide);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mode = ref.watch(
      compositionGuideNotifierProvider.select((settings) => settings.mode),
    );
    // 参考线开着时按钮常亮，收起浮层后也能一眼看出画布上为什么有线
    final active = _controller.isShowing || mode != CompositionGuideMode.none;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (context) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                ),
              ),
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 4),
                child: const _CompositionGuidePanel(),
              ),
            ],
          );
        },
        child: IconButton(
          onPressed: () => setState(_controller.toggle),
          icon: const Icon(Icons.grid_on_rounded, size: 20),
          tooltip: context.l10n.characterCanvas_guide,
          style: IconButton.styleFrom(
            foregroundColor: active
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 参考线档位浮层
class _CompositionGuidePanel extends ConsumerWidget {
  const _CompositionGuidePanel();

  static const double _panelWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final settings = ref.watch(compositionGuideNotifierProvider);
    final notifier = ref.read(compositionGuideNotifierProvider.notifier);

    final labels = <CompositionGuideMode, String>{
      CompositionGuideMode.none: l10n.characterCanvas_guideNone,
      CompositionGuideMode.thirds: l10n.characterCanvas_guideThirds,
      CompositionGuideMode.phi: l10n.characterCanvas_guidePhi,
      CompositionGuideMode.grid: l10n.characterCanvas_guideGrid,
    };

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      child: Container(
        width: _panelWidth,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.characterCanvas_guide,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<CompositionGuideMode>(
              segments: [
                for (final entry in labels.entries)
                  ButtonSegment(value: entry.key, label: Text(entry.value)),
              ],
              selected: {settings.mode},
              onSelectionChanged: (values) => notifier.setMode(values.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            if (settings.mode == CompositionGuideMode.grid) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  DraggableNumberInput(
                    value: settings.columns,
                    min: CompositionGuide.minDivisions,
                    max: CompositionGuide.maxDivisions,
                    prefix: l10n.characterCanvas_guideColumns,
                    onChanged: notifier.setColumns,
                  ),
                  const SizedBox(width: 8),
                  DraggableNumberInput(
                    value: settings.rows,
                    min: CompositionGuide.minDivisions,
                    max: CompositionGuide.maxDivisions,
                    prefix: l10n.characterCanvas_guideRows,
                    onChanged: notifier.setRows,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
