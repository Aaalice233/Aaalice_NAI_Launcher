import 'package:flutter/material.dart';

import '../../themes/theme_extension.dart';
import 'image_card_controller.dart';
import 'image_card_models.dart';
import 'image_card_stream_preview.dart';

const _streamProgressForeground = Colors.white;

class ImageCardGenerating extends StatelessWidget {
  const ImageCardGenerating({
    super.key,
    required this.data,
    required this.controller,
  });

  final ImageCardViewData data;
  final ImageCardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPreview = data.streamPreview?.isNotEmpty == true;
    return Container(
      decoration: BoxDecoration(
        color: hasPreview ? null : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 18,
          ),
        ],
      ),
      child: hasPreview ? _preview(context) : _loading(context, theme),
    );
  }

  Widget _preview(BuildContext context) {
    final progress = data.progress ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _streamPreview(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: RepaintBoundary(
                    child: CircularProgressIndicator(
                      key: const ValueKey('stream-generation-progress-ring'),
                      value: progress > 0
                          ? progress
                          : MediaQuery.disableAnimationsOf(context)
                          ? 0.72
                          : null,
                      strokeWidth: 2,
                      backgroundColor: _streamProgressForeground.withValues(
                        alpha: 0.24,
                      ),
                      color: _streamProgressForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${data.currentImage ?? 0}/${data.totalImages ?? 0}',
                  key: const ValueKey('stream-generation-progress-count'),
                  style: _progressStyle(),
                ),
                const Spacer(),
                if (progress > 0)
                  Text(
                    '${(progress * 100).toInt()}%',
                    key: const ValueKey('stream-generation-progress-percent'),
                    style: _progressStyle(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _streamPreview() => RepaintBoundary(
    child: ImageCardStreamPreview(
      previewBytes: data.streamPreview!,
      placement: data.focusedPreviewPlacement,
    ),
  );

  Widget _loading(BuildContext context, ThemeData theme) {
    final progress = data.progress ?? 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: RepaintBoundary(
                  child: CircularProgressIndicator(
                    value: progress > 0
                        ? progress
                        : MediaQuery.disableAnimationsOf(context)
                        ? 0.72
                        : null,
                    strokeWidth: 2.5,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : theme.appTheme.fastDuration,
              child: Text(
                '${data.currentImage ?? 0}',
                key: ValueKey(data.currentImage ?? 0),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  height: 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '/',
                style: TextStyle(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  height: 1,
                ),
              ),
            ),
            Text(
              '${data.totalImages ?? 0}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle _progressStyle() => const TextStyle(
    color: _streamProgressForeground,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    shadows: [
      Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
    ],
  );
}
