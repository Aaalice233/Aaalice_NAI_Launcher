import 'package:flutter/material.dart';

@immutable
class GalleryDetailOverviewBadgeData {
  const GalleryDetailOverviewBadgeData({
    required this.icon,
    required this.label,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final String tooltip;
}

@immutable
class GalleryDetailOverviewMetadata {
  const GalleryDetailOverviewMetadata({
    required this.icon,
    required this.value,
    this.label = '',
  });

  final IconData icon;
  final String label;
  final String value;
}

class GalleryDetailOverviewCard extends StatelessWidget {
  const GalleryDetailOverviewCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.badge,
    this.content,
    this.metadata = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final GalleryDetailOverviewBadgeData? badge;
  final Widget? content;
  final List<GalleryDetailOverviewMetadata> metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.onSurface.withValues(alpha: 0.045),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OverviewHeader(
              icon: icon,
              title: title,
              subtitle: subtitle,
              badge: badge,
            ),
            if (content case final content?) ...[
              const SizedBox(height: 14),
              content,
            ],
            if (metadata.isNotEmpty) ...[
              const SizedBox(height: 14),
              _OverviewMetadata(entries: metadata),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final GalleryDetailOverviewBadgeData? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 19,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (badge case final badge?) ...[
          const SizedBox(width: 10),
          _OverviewBadge(data: badge),
        ],
      ],
    );
  }
}

class _OverviewBadge extends StatelessWidget {
  const _OverviewBadge({required this.data});

  final GalleryDetailOverviewBadgeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: data.tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              data.icon,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              data.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewMetadata extends StatelessWidget {
  const _OverviewMetadata({required this.entries});

  final List<GalleryDetailOverviewMetadata> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < entries.length; index++) ...[
              _OverviewMetadataRow(entry: entries[index]),
              if (index + 1 < entries.length) const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewMetadataRow extends StatelessWidget {
  const _OverviewMetadataRow({required this.entry});

  final GalleryDetailOverviewMetadata entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            entry.icon,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 7),
        if (entry.label.isNotEmpty) ...[
          Flexible(
            flex: 2,
            child: Text(
              entry.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: 3,
          child: Text(
            entry.value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
