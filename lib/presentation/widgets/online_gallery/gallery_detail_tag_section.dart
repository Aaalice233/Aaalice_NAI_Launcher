import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
import '../tag_chip.dart';

@immutable
class GalleryDetailTagGroup {
  const GalleryDetailTagGroup({
    required this.label,
    required this.tags,
    required this.color,
    this.onCopy,
    this.copyTooltip = '',
  });

  final String label;
  final List<String> tags;
  final Color color;
  final VoidCallback? onCopy;
  final String copyTooltip;
}

class GalleryDetailTagSection extends StatelessWidget {
  const GalleryDetailTagSection({
    super.key,
    required this.groups,
    required this.isOutputFiltered,
    required this.normalTooltip,
    required this.filteredTooltip,
    required this.onTagTap,
    required this.onTagSecondaryTapUp,
    this.sectionLabel = '',
    this.onCopySection,
    this.sectionCopyTooltip = '',
  });

  final List<GalleryDetailTagGroup> groups;
  final String sectionLabel;
  final VoidCallback? onCopySection;
  final String sectionCopyTooltip;
  final bool Function(String tag) isOutputFiltered;
  final String normalTooltip;
  final String filteredTooltip;
  final ValueChanged<String> onTagTap;
  final void Function(String tag, TapUpDetails details) onTagSecondaryTapUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionLabel.isNotEmpty) ...[
          _SectionHeader(
            label: sectionLabel,
            onCopy: onCopySection,
            copyTooltip: sectionCopyTooltip,
          ),
          const SizedBox(height: 9),
        ],
        for (var index = 0; index < groups.length; index++) ...[
          _TagGroupHeader(group: groups[index]),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in groups[index].tags)
                SimpleTagChip(
                  tag: tag,
                  color: groups[index].color,
                  isOutputFiltered: isOutputFiltered(tag),
                  tooltip: isOutputFiltered(tag)
                      ? filteredTooltip
                      : normalTooltip,
                  onTap: () => onTagTap(tag),
                  onSecondaryTapUp: (details) =>
                      onTagSecondaryTapUp(tag, details),
                ),
            ],
          ),
          if (index + 1 < groups.length) const SizedBox(height: 13),
        ],
      ],
    );
  }
}

class _TagGroupHeader extends StatelessWidget {
  const _TagGroupHeader({required this.group});

  final GalleryDetailTagGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '${group.label} (${group.tags.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              color: group.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (group.onCopy case final onCopy?)
          _CopyButton(onPressed: onCopy, tooltip: group.copyTooltip),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.onCopy,
    required this.copyTooltip,
  });

  final String label;
  final VoidCallback? onCopy;
  final String copyTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onCopy case final onCopy?)
          _CopyButton(onPressed: onCopy, tooltip: copyTooltip),
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.onPressed, required this.tooltip});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactionPolicy = context.interactionPolicy;
    final controlExtent = interactionPolicy.minimumControlExtent;
    return SizedBox.square(
      dimension: controlExtent,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: controlExtent,
          height: controlExtent,
        ),
        visualDensity: interactionPolicy.touchAvailable
            ? VisualDensity.standard
            : VisualDensity.compact,
        tooltip: tooltip,
        icon: Icon(
          Icons.content_copy_rounded,
          size: 15,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
