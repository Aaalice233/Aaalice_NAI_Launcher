import 'package:flutter/material.dart';

import 'gallery_detail_models.dart';

class GalleryDetailActionRail extends StatefulWidget {
  const GalleryDetailActionRail({
    super.key,
    required this.viewModel,
    required this.actions,
  });

  final GalleryDetailViewModel viewModel;
  final GalleryDetailActions actions;

  @override
  State<GalleryDetailActionRail> createState() =>
      _GalleryDetailActionRailState();
}

class _GalleryDetailActionRailState extends State<GalleryDetailActionRail> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    if (entries.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final requiredHeight = entries.length * 48 + (entries.length - 1) * 6;
        if (constraints.maxHeight < requiredHeight + 8) {
          return Align(
            alignment: Alignment.centerRight,
            child: _OverflowActionButton(entries: entries),
          );
        }
        return Align(
          alignment: Alignment.centerRight,
          child: Column(
            key: const ValueKey('gallery-detail-action-rail'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                _RailActionButton(
                  entry: entries[index],
                  expanded: _expandedId == entries[index].id,
                  onActiveChanged: (active) {
                    if (!mounted) return;
                    setState(() {
                      if (active) {
                        _expandedId = entries[index].id;
                      } else if (_expandedId == entries[index].id) {
                        _expandedId = null;
                      }
                    });
                  },
                ),
                if (index + 1 < entries.length) const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
    );
  }

  List<_RailActionEntry> _entries() {
    final viewModel = widget.viewModel;
    final actions = widget.actions;
    final media = viewModel.currentMedia;
    final canDownload =
        media != null &&
        galleryMediaHasOriginal(media) &&
        galleryMediaDownloadUrl(media).isNotEmpty;
    final canReverse =
        media != null &&
        media.capability.isFlutterImage &&
        media.capability.imageDisplayUrl.isNotEmpty &&
        actions.sendToReverse != null;
    final entries = <_RailActionEntry>[
      _RailActionEntry(
        id: 'copy',
        icon: Icons.copy_all_outlined,
        label: viewModel.labels.copyPrompt,
        onPressed:
            viewModel.hasCopyableContent || viewModel.item.tags.isNotEmpty
            ? () => actions.copyPrompt(media)
            : null,
      ),
      _RailActionEntry(
        id: 'download',
        icon: Icons.download_outlined,
        label: viewModel.labels.downloadOriginal,
        loading: viewModel.downloadActionPending,
        onPressed: canDownload && !viewModel.downloadActionPending
            ? () => actions.downloadCurrentOriginal(media)
            : null,
      ),
      if (canReverse)
        _RailActionEntry(
          id: 'reverse',
          icon: Icons.manage_search,
          label: viewModel.labels.sendToReverse,
          loading: viewModel.reverseActionPending,
          onPressed: viewModel.reverseActionPending
              ? null
              : () => actions.sendToReverse!(media),
        ),
      if (actions.downloadAll != null && viewModel.media.length > 1)
        _RailActionEntry(
          id: 'download-all',
          icon: Icons.download_for_offline_outlined,
          label: viewModel.labels.downloadAll,
          loading: viewModel.downloadActionPending,
          onPressed: viewModel.downloadActionPending
              ? null
              : () => actions.downloadAll!(viewModel.media),
        ),
    ];
    return entries;
  }
}

class _RailActionEntry {
  const _RailActionEntry({
    required this.id,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
}

class _RailActionButton extends StatefulWidget {
  const _RailActionButton({
    required this.entry,
    required this.expanded,
    required this.onActiveChanged,
  });

  final _RailActionEntry entry;
  final bool expanded;
  final ValueChanged<bool> onActiveChanged;

  @override
  State<_RailActionButton> createState() => _RailActionButtonState();
}

class _RailActionButtonState extends State<_RailActionButton> {
  bool _hovered = false;
  bool _focused = false;

  void _updateActive() => widget.onActiveChanged(_hovered || _focused);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.entry.onPressed != null;
    final foreground = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.entry.label,
      child: Tooltip(
        message: widget.entry.label,
        child: MouseRegion(
          onEnter: (_) {
            _hovered = true;
            _updateActive();
          },
          onExit: (_) {
            _hovered = false;
            _updateActive();
          },
          child: Focus(
            onFocusChange: (focused) {
              _focused = focused;
              _updateActive();
            },
            child: Material(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.94,
              ),
              elevation: widget.expanded ? 8 : 3,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('gallery-detail-action-${widget.entry.id}'),
                onTap: widget.entry.onPressed,
                child: AnimatedContainer(
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: widget.expanded ? 188 : 48,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showLabel =
                          widget.expanded && constraints.maxWidth >= 96;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (showLabel) ...[
                            Expanded(
                              child: Text(
                                widget.entry.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          SizedBox.square(
                            dimension: 24,
                            child: Center(
                              child: widget.entry.loading
                                  ? SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: foreground,
                                      ),
                                    )
                                  : Icon(
                                      widget.entry.icon,
                                      size: 21,
                                      color: foreground,
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverflowActionButton extends StatelessWidget {
  const _OverflowActionButton({required this.entries});

  final List<_RailActionEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).moreButtonTooltip,
      child: PopupMenuButton<String>(
        key: const ValueKey('gallery-detail-action-overflow'),
        tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
        position: PopupMenuPosition.under,
        onSelected: (id) {
          for (final entry in entries) {
            if (entry.id == id) {
              entry.onPressed?.call();
              return;
            }
          }
        },
        itemBuilder: (context) => [
          for (final entry in entries)
            PopupMenuItem<String>(
              value: entry.id,
              enabled: entry.onPressed != null,
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 22,
                    child: entry.loading
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : Icon(entry.icon, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.label)),
                ],
              ),
            ),
        ],
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          elevation: 3,
          shape: const CircleBorder(),
          child: const SizedBox.square(
            dimension: 48,
            child: Icon(Icons.more_vert),
          ),
        ),
      ),
    );
  }
}
