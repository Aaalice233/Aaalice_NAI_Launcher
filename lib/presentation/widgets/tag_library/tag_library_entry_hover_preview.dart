import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../common/themed_divider.dart';
import '../common/thumbnail_display.dart';

/// 使用词库条目卡片同款内容面板显示悬浮预览。
class TagLibraryEntryHoverPreview extends StatefulWidget {
  const TagLibraryEntryHoverPreview({
    super.key,
    required this.entry,
    required this.child,
    this.hoverDelay = const Duration(milliseconds: 500),
  });

  final TagLibraryEntry entry;
  final Widget child;
  final Duration hoverDelay;

  @override
  State<TagLibraryEntryHoverPreview> createState() =>
      _TagLibraryEntryHoverPreviewState();
}

class _TagLibraryEntryHoverPreviewState
    extends State<TagLibraryEntryHoverPreview> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _hoverTimer;
  bool _isHovering = false;

  @override
  void didUpdateWidget(TagLibraryEntryHoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry != widget.entry) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _hidePreviewOverlay();
    super.dispose();
  }

  void _schedulePreviewOverlay() {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(widget.hoverDelay, () {
      if (mounted && _isHovering) {
        _showPreviewOverlay();
      }
    });
  }

  void _showPreviewOverlay() {
    if (_overlayEntry != null) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final cardSize = renderObject.size;
    final cardPosition = renderObject.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => TagLibraryEntryPreviewOverlay(
        entry: widget.entry,
        layerLink: _layerLink,
        cardSize: cardSize,
        cardPosition: cardPosition,
        onDismiss: _hidePreviewOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hidePreviewOverlay() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
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
          _hidePreviewOverlay();
        },
        child: widget.child,
      ),
    );
  }
}

/// 词库卡片和其他词库来源条目共享的完整预览面板。
class TagLibraryEntryPreviewOverlay extends StatelessWidget {
  const TagLibraryEntryPreviewOverlay({
    super.key,
    required this.entry,
    required this.layerLink,
    required this.cardSize,
    required this.cardPosition,
    required this.onDismiss,
  });

  final TagLibraryEntry entry;
  final LayerLink layerLink;
  final Size cardSize;
  final Offset cardPosition;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);

    const previewWidth = 320.0;
    const previewMaxHeight = 400.0;

    final rightSpace = screenSize.width - (cardPosition.dx + cardSize.width);
    final showOnRight = rightSpace >= previewWidth + 16;

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        offset: Offset(showOnRight ? cardSize.width + 8 : -previewWidth - 8, 0),
        child: MouseRegion(
          onExit: (_) => onDismiss(),
          child: Material(
            key: const ValueKey('tag-library-entry-preview-overlay'),
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surfaceContainerHigh,
            child: Container(
              width: previewWidth,
              constraints: const BoxConstraints(maxHeight: previewMaxHeight),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
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
                          height: 180,
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
                            Text(
                              entry.content,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                              maxLines: 8,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            if (entry.tags.isNotEmpty) ...[
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
                                    child: Text(
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
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Icon(
                                  Icons.repeat,
                                  size: 14,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  context.l10n.tagLibrary_useCount(
                                    entry.useCount,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                if (entry.lastUsedAt != null) ...[
                                  const SizedBox(width: 16),
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
