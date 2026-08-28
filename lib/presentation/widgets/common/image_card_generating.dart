import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../data/models/image/image_stream_chunk.dart';

import 'decoded_memory_image.dart';
import 'image_card_controller.dart';
import 'image_card_focused_preview.dart';
import 'image_card_models.dart';

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
    return AnimatedBuilder(
      animation: controller.glowAnimation ?? const AlwaysStoppedAnimation(0.06),
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          color: hasPreview ? null : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(
                alpha: controller.glowAnimation?.value ?? 0.06,
              ),
              blurRadius: 18,
            ),
          ],
        ),
        child: child,
      ),
      child: hasPreview ? _preview(theme) : _loading(theme),
    );
  }

  Widget _preview(ThemeData theme) {
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
                  Colors.black.withValues(alpha: 0.4),
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
                  child: CircularProgressIndicator(
                    value: progress > 0 ? progress : null,
                    strokeWidth: 2,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${data.currentImage ?? 0}/${data.totalImages ?? 0}',
                  style: _progressStyle,
                ),
                const Spacer(),
                if (progress > 0)
                  Text('${(progress * 100).toInt()}%', style: _progressStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _streamPreview() {
    final placement = data.focusedPreviewPlacement;
    if (placement == null || !placement.isValid) {
      return DecodedMemoryImage(
        bytes: data.streamPreview!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    if (placement.hasMask) {
      return _FocusedStreamPreviewImage(
        previewImage: data.streamPreview!,
        placement: placement,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return DecodedMemoryImage(
            bytes: data.streamPreview!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        final x = placement.xPercent.clamp(0.0, 1.0).toDouble();
        final y = placement.yPercent.clamp(0.0, 1.0).toDouble();
        final width = placement.widthPercent.clamp(0.0, 1.0 - x).toDouble();
        final height = placement.heightPercent.clamp(0.0, 1.0 - y).toDouble();
        return Stack(
          fit: StackFit.expand,
          children: [
            DecodedMemoryImage(
              bytes: placement.sourceImage,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            Positioned(
              left: constraints.maxWidth * x,
              top: constraints.maxHeight * y,
              width: math.max(1, constraints.maxWidth * width),
              height: math.max(1, constraints.maxHeight * height),
              child: ClipRect(
                child: DecodedMemoryImage(
                  bytes: data.streamPreview!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _loading(ThemeData theme) {
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
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2.5,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  color: theme.colorScheme.primary,
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
              duration: const Duration(milliseconds: 200),
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

  static const _progressStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
  );
}

class _FocusedStreamPreviewImage extends StatelessWidget {
  const _FocusedStreamPreviewImage({
    required this.previewImage,
    required this.placement,
  });

  final Uint8List previewImage;
  final FocusedStreamPreviewPlacement placement;

  @override
  Widget build(BuildContext context) =>
      ImageCardFocusedPreview(previewImage: previewImage, placement: placement);
}
