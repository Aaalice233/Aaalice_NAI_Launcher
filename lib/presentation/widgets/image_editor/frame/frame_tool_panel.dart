import 'package:flutter/material.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../common/app_toast.dart';
import '../core/editor_state.dart';
import 'editor_frame_commands.dart';

/// 裁切到取景框；失败时提示，文档保持原样
Future<void> cropToFrameWithFeedback(
  BuildContext context,
  EditorFrameCommands commands,
) async {
  try {
    await commands.cropToFrame();
  } catch (error, stack) {
    AppLogger.e('Crop to frame failed', error, stack, 'ImageEditor');
    if (context.mounted) {
      AppToast.error(context, context.l10n.editor_cropToFrameFailed(error));
    }
  }
}

/// 取景框工具设置面板：尺寸与位置读数、重置与裁切入口
class FrameToolPanel extends StatelessWidget {
  const FrameToolPanel({super.key, required this.state});

  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final commands = state.frameCommands;
    if (commands == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: Listenable.merge([
        commands,
        state.framePreviewNotifier,
        state.canvasController,
      ]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FrameToolHeader(pastesBack: commands.supportsPasteBack),
            const SizedBox(height: 12),
            _FrameReadout(frame: state.displayFrame, commands: commands),
            if (!_viewAllowsMove) ...[
              const SizedBox(height: 8),
              _FrameNotice(message: context.l10n.editor_frameMoveLockedByView),
            ],
            const SizedBox(height: 12),
            _FrameActions(commands: commands),
          ],
        ),
      ),
    );
  }

  bool get _viewAllowsMove {
    final controller = state.canvasController;
    return controller.rotation == 0 && !controller.isMirroredHorizontally;
  }
}

class _FrameToolHeader extends StatelessWidget {
  const _FrameToolHeader({required this.pastesBack});

  final bool pastesBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.editor_toolFrame,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          pastesBack
              ? context.l10n.editor_frameToolHintPasteBack
              : context.l10n.editor_frameToolHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 位置以原图左上角为原点
class _FrameReadout extends StatelessWidget {
  const _FrameReadout({required this.frame, required this.commands});

  final Rect frame;
  final EditorFrameCommands commands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final source = commands.sourceRect;
    final estimate = commands.requestEstimate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.editor_frameSizeReadout(
            frame.width.round(),
            frame.height.round(),
          ),
          style: style,
        ),
        if (source != null) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.editor_frameOffsetReadout(
              (frame.left - source.left).round(),
              (frame.top - source.top).round(),
            ),
            style: style,
          ),
        ],
        if (estimate != null) ...[
          const SizedBox(height: 4),
          _FrameRequestReadout(estimate: estimate, style: style),
        ],
      ],
    );
  }
}

/// 点「完成」后实际发送的尺寸，以及是否免费
class _FrameRequestReadout extends StatelessWidget {
  const _FrameRequestReadout({required this.estimate, required this.style});

  final EditorRequestEstimate estimate;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cost = estimate.cost;
    final size = context.l10n.editor_frameRequestReadout(
      estimate.requestWidth,
      estimate.requestHeight,
    );
    final isFree = cost == 0;
    return Text.rich(
      TextSpan(
        text: '$size · ',
        children: [
          TextSpan(
            text: isFree
                ? context.l10n.editor_frameRequestFree
                : context.l10n.editor_frameRequestCost(cost),
            style: TextStyle(
              color: isFree ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      style: style,
    );
  }
}

class _FrameNotice extends StatelessWidget {
  const _FrameNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _FrameActions extends StatelessWidget {
  const _FrameActions({required this.commands});

  final EditorFrameCommands commands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    final cropping = commands.isCroppingToFrame;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: commands.canResetFrame ? commands.resetFrame : null,
          icon: const Icon(Icons.fit_screen, size: 16),
          label: Text(context.l10n.editor_resetFrame),
          style: OutlinedButton.styleFrom(
            padding: buttonPadding,
            textStyle: theme.textTheme.bodySmall,
          ),
        ),
        Tooltip(
          message: context.l10n.editor_cropToFrameHint,
          child: FilledButton.tonalIcon(
            onPressed: commands.canCropToFrame
                ? () => cropToFrameWithFeedback(context, commands)
                : null,
            icon: cropping
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.crop, size: 16),
            label: Text(context.l10n.editor_cropToFrame),
            style: FilledButton.styleFrom(
              padding: buttonPadding,
              textStyle: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}
