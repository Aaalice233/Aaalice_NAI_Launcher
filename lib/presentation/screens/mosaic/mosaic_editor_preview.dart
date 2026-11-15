import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/mosaic/mosaic_settings.dart';
import 'mosaic_editor_canvas.dart';

/// 马赛克编辑器顶部标题栏
class MosaicEditorHeader extends StatelessWidget {
  const MosaicEditorHeader({
    super.key,
    required this.defaultsOnly,
    required this.onClose,
  });

  final bool defaultsOnly;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(
            Icons.grid_on_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              defaultsOnly
                  ? context.l10n.mosaic_defaultsTitle
                  : context.l10n.mosaic_editorTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: context.l10n.common_close,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// 马赛克编辑器主工作区（宽屏左右分栏、窄屏上下分栏）
class MosaicEditorWorkspace extends StatelessWidget {
  const MosaicEditorWorkspace({
    super.key,
    required this.preview,
    required this.controls,
  });

  final Widget preview;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 880) {
          return Row(
            children: [
              Expanded(child: preview),
              const VerticalDivider(width: 1),
              SizedBox(width: 410, child: controls),
            ],
          );
        }
        final controlsHeight = math.min(390.0, constraints.maxHeight * 0.48);
        return Column(
          children: [
            Expanded(child: preview),
            const Divider(height: 1),
            SizedBox(height: controlsHeight, child: controls),
          ],
        );
      },
    );
  }
}

/// 源图加载失败视图
class MosaicEditorErrorView extends StatelessWidget {
  const MosaicEditorErrorView({
    super.key,
    required this.hasChooseSource,
    required this.onClose,
    required this.onChooseSource,
    required this.onRetry,
  });

  final bool hasChooseSource;
  final VoidCallback onClose;
  final VoidCallback onChooseSource;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.mosaic_sourceLoadFailed,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: onClose,
                    child: Text(context.l10n.common_close),
                  ),
                  if (hasChooseSource)
                    FilledButton.icon(
                      onPressed: onChooseSource,
                      icon: const Icon(Icons.image_search_outlined),
                      label: Text(context.l10n.mosaic_chooseOriginal),
                    )
                  else
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.common_retry),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 马赛克画布预览区（包含焦点快捷键监听、处理中指示与错误遮罩）
class MosaicEditorPreviewPane extends StatelessWidget {
  const MosaicEditorPreviewPane({
    super.key,
    required this.previewFocusNode,
    required this.sourceImage,
    required this.processedImage,
    required this.settings,
    required this.regions,
    required this.selectedId,
    required this.drawShape,
    required this.processingPreview,
    required this.previewError,
    required this.onKeyEvent,
    required this.onSelected,
    required this.onBeginRegionTransform,
    required this.onRegionChanged,
    required this.onRegionCreated,
    required this.onRetryPreview,
  });

  final FocusNode previewFocusNode;
  final ui.Image sourceImage;
  final ui.Image? processedImage;
  final MosaicSettings settings;
  final List<MosaicRegion> regions;
  final String? selectedId;
  final MosaicShape drawShape;
  final bool processingPreview;
  final Object? previewError;
  final FocusOnKeyEventCallback onKeyEvent;
  final ValueChanged<String?> onSelected;
  final VoidCallback onBeginRegionTransform;
  final ValueChanged<MosaicRegion> onRegionChanged;
  final void Function(
    MosaicShape shape,
    Rect normalizedRect,
    List<MosaicPoint> points,
  )
  onRegionCreated;
  final VoidCallback onRetryPreview;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Focus(
                focusNode: previewFocusNode,
                autofocus: true,
                onKeyEvent: onKeyEvent,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MosaicEditorCanvas(
                        source: sourceImage,
                        processed: processedImage,
                        settings: settings,
                        regions: regions,
                        selectedId: selectedId,
                        drawShape: drawShape,
                        selectionColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        onSelected: onSelected,
                        onBeginRegionTransform: onBeginRegionTransform,
                        onRegionChanged: onRegionChanged,
                        onRegionCreated: onRegionCreated,
                        onFocusRequested: previewFocusNode.requestFocus,
                      ),
                    ),
                    if (processingPreview)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHigh
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                    if (previewError != null)
                      Positioned.fill(
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  '${context.l10n.mosaic_failedGeneric}\n$previewError',
                                ),
                                TextButton.icon(
                                  onPressed: onRetryPreview,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(context.l10n.common_retry),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
