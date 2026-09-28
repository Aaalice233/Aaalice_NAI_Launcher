import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
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
    // 偏离上游：上游的两条 tooltip 文案写死成「右键可…」，而 SimpleTagChip
    // 的菜单入口在触屏上是长按（见 tag_chip.dart）。文案与真实手势对不上时，
    // 等于这个功能在手机上不存在，所以按 interactionPolicy 切一套触屏说法。
    // 调用方传进来的文案保持不变，指针设备仍然看到上游原文。
    final exposeTouchAlternatives =
        context.interactionPolicy.shouldExposeTouchAlternatives;
    final l10n = context.l10n;
    String tooltipFor({required bool filtered}) {
      if (exposeTouchAlternatives) {
        return filtered
            ? l10n.onlineGallery_outputFilteredTagTooltipTouch
            : l10n.onlineGallery_tagContextMenuTooltipTouch;
      }
      return filtered ? filteredTooltip : normalTooltip;
    }

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
                  tooltip: tooltipFor(filtered: isOutputFiltered(tag)),
                  onTap: () => onTagTap(tag),
                  // 长按不用显式接线：SimpleTagChip 在未传 onLongPressStart 时
                  // 会把长按位置合成成 TapUpDetails 走同一个 onSecondaryTapUp。
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
