import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/pixel_snap/pixel_snap_engine.dart';
import '../../../../core/services/pixel_snap/pixel_snap_options.dart';
import '../../../../core/services/pixel_snap/pixel_snap_progress.dart';
import '../../../../core/services/pixel_snap/pixel_snap_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../providers/director_tools_notifier.dart';

/// Pixel Snap 专属的参数、进度与结果控件。
/// 其余导演工具走服务端，没有本机进度和调色板设置，不共用这里的任何一块。

/// 调色板模式、色数与两个开关。
class PixelSnapOptionsSection extends ConsumerWidget {
  const PixelSnapOptionsSection({
    super.key,
    required this.options,
    required this.enabled,
  });

  final PixelSnapOptions options;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(directorToolsNotifierProvider.notifier);
    void update(PixelSnapOptions next) => notifier.updatePixelSnapOptions(next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.img2img_directorPixelSnapHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l10n.img2img_directorPixelSnapPalette,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) =>
              SegmentedButton<PixelSnapPaletteMode>(
                // 三个分段在窄面板或放大文本下排不开，此时改成竖排。
                direction:
                    constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3
                    ? Axis.vertical
                    : Axis.horizontal,
                segments: [
                  ButtonSegment(
                    value: PixelSnapPaletteMode.off,
                    label: Text(l10n.img2img_directorPixelSnapPaletteOff),
                  ),
                  ButtonSegment(
                    value: PixelSnapPaletteMode.auto,
                    label: Text(l10n.img2img_directorPixelSnapPaletteAuto),
                  ),
                  ButtonSegment(
                    value: PixelSnapPaletteMode.custom,
                    label: Text(l10n.img2img_directorPixelSnapPaletteCustom),
                  ),
                ],
                selected: {options.paletteMode},
                showSelectedIcon: false,
                onSelectionChanged: enabled
                    ? (selection) =>
                          update(options.copyWith(paletteMode: selection.first))
                    : null,
              ),
        ),
        if (options.paletteMode == PixelSnapPaletteMode.custom) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: Text(
                  l10n.img2img_directorPixelSnapColors,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const Spacer(),
              Text(
                '${options.colors}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: options.colors
                .clamp(PixelSnapOptions.minColors, PixelSnapOptions.maxColors)
                .toDouble(),
            min: PixelSnapOptions.minColors.toDouble(),
            max: PixelSnapOptions.maxColors.toDouble(),
            divisions:
                (PixelSnapOptions.maxColors - PixelSnapOptions.minColors) ~/
                PixelSnapOptions.colorsStep,
            label: '${options.colors}',
            onChanged: enabled
                ? (value) => update(options.copyWith(colors: value.round()))
                : null,
          ),
        ],
        const SizedBox(height: 4),
        _PixelSnapSwitch(
          title: l10n.img2img_directorPixelSnapAvoidOverRefining,
          subtitle: options.avoidOverRefining
              ? l10n.img2img_directorPixelSnapAvoidOverRefiningOn
              : l10n.img2img_directorPixelSnapAvoidOverRefiningOff,
          value: options.avoidOverRefining,
          onChanged: enabled
              ? (value) => update(options.copyWith(avoidOverRefining: value))
              : null,
        ),
        _PixelSnapSwitch(
          title: l10n.img2img_directorPixelSnapUpscale,
          subtitle: options.upscale
              ? l10n.img2img_directorPixelSnapUpscaleOn
              : l10n.img2img_directorPixelSnapUpscaleOff,
          value: options.upscale,
          onChanged: enabled
              ? (value) => update(options.copyWith(upscale: value))
              : null,
        ),
      ],
    );
  }
}

class _PixelSnapSwitch extends StatelessWidget {
  const _PixelSnapSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 本机计算的进度条、阶段文案与取消入口。
class PixelSnapProgressPanel extends ConsumerWidget {
  const PixelSnapProgressPanel({super.key, required this.progress});

  final PixelSnapProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final status = Row(
      children: [
        Expanded(
          child: Text(
            progress == null
                ? context.l10n.img2img_directorRunning
                : _stageLabel(context.l10n, progress!.stage),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: statusStyle,
          ),
        ),
        if (progress != null) ...[
          const SizedBox(width: 8),
          Text(
            '${(progress!.fraction * 100).round()}%',
            style: statusStyle?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
    final minimumExtent = context.interactionPolicy.minimumControlExtent;
    final cancel = TextButton(
      onPressed: () =>
          ref.read(directorToolsNotifierProvider.notifier).cancelRun(),
      style: TextButton.styleFrom(
        minimumSize: Size(minimumExtent, minimumExtent),
      ),
      child: Text(context.l10n.img2img_directorCancel),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: progress?.fraction,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // 放大文本下百分比加取消按钮挤不进同一行，改成状态在上、取消在下。
            final stacked =
                constraints.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.5;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  status,
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: cancel,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: status),
                const SizedBox(width: 8),
                cancel,
              ],
            );
          },
        ),
      ],
    );
  }

  String _stageLabel(AppLocalizations l10n, PixelSnapStage stage) {
    switch (stage) {
      case PixelSnapStage.analyzing:
        return l10n.img2img_directorStageAnalyzing;
      case PixelSnapStage.searchingPitch:
        return l10n.img2img_directorStageSearchingPitch;
      case PixelSnapStage.refiningGrid:
        return l10n.img2img_directorStageRefiningGrid;
      case PixelSnapStage.finishing:
        return l10n.img2img_directorStageFinishing;
    }
  }
}

/// 结果的像素块数与色数。
class PixelSnapSummary extends StatelessWidget {
  const PixelSnapSummary({super.key, required this.output});

  final PixelSnapOutput output;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final summary = output.paletteSize > 0
        ? l10n.img2img_directorPixelSnapSummary(
            output.snappedWidth,
            output.snappedHeight,
            output.paletteSize,
          )
        : l10n.img2img_directorPixelSnapSummaryNoPalette(
            output.snappedWidth,
            output.snappedHeight,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (output.downscaledForAnalysis) ...[
          const SizedBox(height: 4),
          Text(
            l10n.img2img_directorPixelSnapDownscaled,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ],
      ],
    );
  }
}

/// 已知失败翻成本地化文案；不认识的原因返回 null，由调用方退回原始文本。
String? pixelSnapErrorText(AppLocalizations l10n, Object? cause) {
  if (cause is PixelSnapNoGridException) {
    return l10n.img2img_directorPixelSnapNoGrid;
  }
  if (cause is PixelSnapBlankImageException) {
    return l10n.img2img_directorPixelSnapBlank;
  }
  return null;
}
