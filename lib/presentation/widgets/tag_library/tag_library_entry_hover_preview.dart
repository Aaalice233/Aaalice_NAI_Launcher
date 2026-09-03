import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../common/gallery_hover_controller.dart';
import '../common/themed_divider.dart';
import '../common/thumbnail_display.dart';
import '../common/translated_tag_text.dart';

/// 使用词库条目卡片同款内容面板显示悬浮预览。
class TagLibraryEntryHoverPreview extends StatefulWidget {
  const TagLibraryEntryHoverPreview({
    super.key,
    required this.entry,
    required this.child,
    this.enabled = true,
    this.hoverDelay = const Duration(milliseconds: 500),
  });

  final TagLibraryEntry entry;
  final Widget child;
  final bool enabled;
  final Duration hoverDelay;

  @override
  State<TagLibraryEntryHoverPreview> createState() =>
      _TagLibraryEntryHoverPreviewState();
}

class _TagLibraryEntryHoverPreviewState
    extends State<TagLibraryEntryHoverPreview> {
  static const _previewSize = Size(320, 400);

  final _layerLink = LayerLink();
  late final GalleryHoverController _hoverController;
  ScrollPosition? _scrollPosition;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _hoverController = GalleryHoverController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextScrollPosition = Scrollable.maybeOf(context)?.position;
    if (nextScrollPosition == _scrollPosition) return;
    _scrollPosition?.removeListener(_dismissForScroll);
    _scrollPosition = nextScrollPosition;
    _scrollPosition?.addListener(_dismissForScroll);
  }

  @override
  void didUpdateWidget(TagLibraryEntryHoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) {
      _hoverController.dismissFor(oldWidget.entry.id);
      if (_isHovering && widget.enabled) _schedulePreviewOverlay();
    } else if (oldWidget.enabled != widget.enabled ||
        oldWidget.hoverDelay != widget.hoverDelay) {
      _hoverController.dismissFor(widget.entry.id);
      if (_isHovering && widget.enabled) _schedulePreviewOverlay();
    } else if (oldWidget.entry != widget.entry) {
      _hoverController.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_dismissForScroll);
    _hoverController.dispose();
    super.dispose();
  }

  void _dismissForScroll() {
    _hoverController.dismissFor(widget.entry.id);
  }

  void _schedulePreviewOverlay() {
    if (!widget.enabled) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    _hoverController.schedule(
      context: context,
      stableKey: widget.entry.id,
      layerLink: _layerLink,
      targetRect: renderObject.localToGlobal(Offset.zero) & renderObject.size,
      previewSize: _previewSize,
      delay: widget.hoverDelay,
      builder: (_) => TagLibraryEntryPreviewOverlay(entry: widget.entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _isHovering = true;
          _schedulePreviewOverlay();
        },
        onExit: (_) {
          _isHovering = false;
          _hoverController.dismissFor(widget.entry.id);
        },
        child: widget.child,
      ),
    );
  }
}

/// 词库卡片和其他词库来源条目共享的完整预览面板。
class TagLibraryEntryPreviewOverlay extends StatelessWidget {
  const TagLibraryEntryPreviewOverlay({super.key, required this.entry});

  final TagLibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        const preferredWidth = 320.0;
        const preferredMaxHeight = 400.0;
        final previewWidth = math.min(preferredWidth, constraints.maxWidth);
        final previewMaxHeight = math.min(
          preferredMaxHeight,
          constraints.maxHeight,
        );

        return Material(
          key: const ValueKey('tag-library-entry-preview-overlay'),
          elevation: 16,
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceContainerHigh,
          child: SizedBox(
            width: previewWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: previewMaxHeight),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.hasThumbnail && entry.thumbnail != null)
                        ThumbnailDisplay(
                          imagePath: entry.thumbnail!,
                          offsetX: entry.thumbnailOffsetX,
                          offsetY: entry.thumbnailOffsetY,
                          scale: entry.thumbnailScale,
                          width: previewWidth,
                          height: math.min(180, previewMaxHeight),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const ThemedDivider(height: 1),
                            const SizedBox(height: 8),
                            TranslatedPromptText(
                              entry.content,
                              selectable: false,
                              includeUntranslated: true,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            if (entry.tags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: entry.tags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: TranslatedTagText(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (entry.lastUsedAt != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatLastUsed(context, entry.lastUsedAt!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatLastUsed(BuildContext context, DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inDays == 0) {
      return context.l10n.common_today;
    } else if (diff.inDays == 1) {
      return context.l10n.common_yesterday;
    } else if (diff.inDays < 7) {
      return context.l10n.common_daysAgo(diff.inDays);
    }
    return DateFormat.MMMd().format(date);
  }
}
