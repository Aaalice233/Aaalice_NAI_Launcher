import 'package:flutter/material.dart';

import '../../../../../core/utils/editor_compression_utils.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../../../common/themed_slider.dart';
import '../../controllers/editor_compression_controller.dart';

/// 桌面端顶栏的输出分辨率压缩控件（宽屏展开滑块，窄桌面退化为图标按钮）。
class DesktopCompressionControl extends StatelessWidget {
  const DesktopCompressionControl({
    super.key,
    required this.plan,
    required this.activeTarget,
    required this.clampedRequestSize,
    required this.expanded,
    required this.onSelectTarget,
    required this.onOpenSheet,
  });

  final EditorCompressionPlan? plan;
  final EditorCompressionTarget activeTarget;
  final ({int width, int height})? clampedRequestSize;
  final bool expanded;
  final ValueChanged<int> onSelectTarget;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final currentPlan = plan;
    if (currentPlan == null) return const SizedBox.shrink();
    if (!expanded) {
      return IconButton(
        icon: const Icon(Icons.compress, size: 20),
        onPressed: onOpenSheet,
        tooltip: context.l10n.editor_compressionTooltip,
      );
    }

    final clamped = clampedRequestSize;
    final index = currentPlan
        .indexOf(activeTarget)
        .clamp(0, currentPlan.targets.length - 1);
    return Tooltip(
      message: clamped == null
          ? context.l10n.editor_compressionTooltip
          : context.l10n.editor_compressionClampedToLimit(
              activeTarget.width,
              activeTarget.height,
              clamped.width,
              clamped.height,
            ),
      child: SizedBox(
        width: 300,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compress, size: 18),
            const SizedBox(width: 6),
            SizedBox(
              width: 92,
              child: Text(
                EditorCompressionController.sizeText(activeTarget),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(
              child: NamedSlider(
                label: context.l10n.editor_compressionTitle,
                valueText: (position) => EditorCompressionController.sliderText(
                  currentPlan,
                  position,
                ),
                value: index.toDouble(),
                min: 0,
                max: currentPlan.targets.length > 1
                    ? (currentPlan.targets.length - 1).toDouble()
                    : 1,
                divisions: currentPlan.targets.length > 1
                    ? currentPlan.targets.length - 1
                    : null,
                onChanged: currentPlan.canCompress
                    ? (value) => onSelectTarget(value.round())
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 移动端顶栏的输出分辨率压缩入口按钮。
class MobileCompressionAction extends StatelessWidget {
  const MobileCompressionAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.compress),
      onPressed: onPressed,
      tooltip: context.l10n.editor_compressionTooltip,
    );
  }
}

/// 打开输出分辨率选择面板。
Future<void> showEditorCompressionSheet(
  BuildContext context, {
  required EditorCompressionController controller,
  required ValueChanged<int> onSelectTarget,
}) async {
  await AdaptivePresenter.showPanel<void>(
    context: context,
    title: context.l10n.editor_compressionTitle,
    initialChildSize: 0.62,
    minChildSize: 0.42,
    dialogWidth: 440,
    builder: (panelContext, scrollController) => StatefulBuilder(
      builder: (panelContext, setPanelState) {
        final plan = controller.plan;
        if (plan == null) return const SizedBox.shrink();
        final target = controller.activeTarget;
        final clamped = controller.clampedRequestSize;
        final limitNotice = controller.limitNotice(context.l10n);
        final index = plan.indexOf(target).clamp(0, plan.targets.length - 1);
        final theme = Theme.of(panelContext);
        return ListView(
          controller: scrollController,
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            Text(
              context.l10n.editor_compressionSizeSummary(
                plan.workWidth,
                plan.workHeight,
                clamped?.width ?? target.width,
                clamped?.height ?? target.height,
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              switch ((clamped, target.isOriginal)) {
                ((final size?, _)) =>
                  context.l10n.editor_compressionClampedToLimit(
                    target.width,
                    target.height,
                    size.width,
                    size.height,
                  ),
                ((_, true)) => context.l10n.editor_compressionUncompressed,
                ((_, false)) => context.l10n.editor_compressionApplyOnDone,
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            NamedSlider(
              label: context.l10n.editor_compressionTitle,
              valueText: (position) =>
                  EditorCompressionController.sliderText(plan, position),
              value: index.toDouble(),
              min: 0,
              max: plan.targets.length > 1
                  ? (plan.targets.length - 1).toDouble()
                  : 1,
              divisions: plan.targets.length > 1
                  ? plan.targets.length - 1
                  : null,
              onChanged: plan.canCompress
                  ? (value) {
                      onSelectTarget(value.round());
                      setPanelState(() {});
                    }
                  : null,
            ),
            Text(
              context.l10n.editor_compressionNormalSummary(
                plan.normalTarget.width,
                plan.normalTarget.height,
                plan.minimumTarget.width,
                plan.minimumTarget.height,
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (!plan.canCompress) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.editor_compressionUnavailable,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (limitNotice != null) ...[
              const SizedBox(height: 8),
              Text(
                limitNotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}
