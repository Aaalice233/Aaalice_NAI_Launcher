import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/chart_colors.dart';

/// Tag cloud data item
class TagCloudItem {
  final String tag;
  final int count;
  final double? weight; // 0.0 to 1.0, calculated from count if not provided

  const TagCloudItem({
    required this.tag,
    required this.count,
    this.weight,
  });
}

/// Tag cloud widget for visualizing tag frequency
/// 标签云组件，用于可视化标签频率
class TagCloudWidget extends StatefulWidget {
  final List<TagCloudItem> tags;
  final double minFontSize;
  final double maxFontSize;
  final bool useRandomColors;
  final Duration animationDuration;
  final void Function(TagCloudItem tag)? onTagTap;

  const TagCloudWidget({
    super.key,
    required this.tags,
    this.minFontSize = 12,
    this.maxFontSize = 32,
    this.useRandomColors = true,
    this.animationDuration = const Duration(milliseconds: 800),
    this.onTagTap,
  });

  @override
  State<TagCloudWidget> createState() => _TagCloudWidgetState();
}

class _TagCloudWidgetState extends State<TagCloudWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.tags.isEmpty) {
      return Center(
        child: Text(
          'No tags available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Calculate weights
    final maxCount =
        widget.tags.map((t) => t.count).reduce((a, b) => a > b ? a : b);
    final minCount =
        widget.tags.map((t) => t.count).reduce((a, b) => a < b ? a : b);
    final countRange = maxCount - minCount;

    // Shuffle tags for random placement
    final shuffledTags = List<TagCloudItem>.from(widget.tags)..shuffle(_random);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: shuffledTags.map((tag) {
            final weight = tag.weight ??
                (countRange > 0 ? (tag.count - minCount) / countRange : 0.5);
            final fontSize = widget.minFontSize +
                (widget.maxFontSize - widget.minFontSize) * weight;
            final color = widget.useRandomColors
                ? ChartColors.getColorForIndex(shuffledTags.indexOf(tag))
                : theme.colorScheme.primary;

            return AnimatedOpacity(
              duration: Duration(
                milliseconds: (widget.animationDuration.inMilliseconds *
                        (0.5 + 0.5 * _random.nextDouble()))
                    .toInt(),
              ),
              opacity: _animation.value,
              child: Transform.scale(
                scale: 0.5 + 0.5 * _animation.value,
                child: _TagChip(
                  tag: tag,
                  fontSize: fontSize,
                  color: color,
                  onTap: widget.onTagTap,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TagChip extends StatefulWidget {
  final TagCloudItem tag;
  final double fontSize;
  final Color color;
  final void Function(TagCloudItem tag)? onTap;

  const _TagChip({
    required this.tag,
    required this.fontSize,
    required this.color,
    this.onTap,
  });

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap != null ? () => widget.onTap!(widget.tag) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: widget.fontSize * 0.5,
            vertical: widget.fontSize * 0.2,
          ),
          decoration: BoxDecoration(
            color:
                _isHovered ? widget.color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(widget.fontSize * 0.3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.tag.tag,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
                  color:
                      _isHovered ? widget.color : widget.color.withOpacity(0.8),
                ),
              ),
              if (_isHovered)
                Text(
                  '${widget.tag.count}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top tags ranking list widget
/// Top标签排行列表组件
class TopTagsRanking extends StatelessWidget {
  final List<TagCloudItem> tags;
  final int maxItems;
  final void Function(TagCloudItem tag)? onTagTap;

  const TopTagsRanking({
    super.key,
    required this.tags,
    this.maxItems = 10,
    this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTags = tags.take(maxItems).toList();

    if (displayTags.isEmpty) {
      return Center(
        child: Text(
          'No tags available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxCount = displayTags.first.count;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayTags.length,
      itemBuilder: (context, index) {
        final tag = displayTags[index];
        final barWidth = maxCount > 0 ? tag.count / maxCount : 0.0;
        final color = ChartColors.getColorForIndex(index);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: onTagTap != null ? () => onTagTap!(tag) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // Rank number
                  SizedBox(
                    width: 28,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: index < 3
                            ? [
                                const Color(0xFFFFD700), // Gold
                                const Color(0xFFC0C0C0), // Silver
                                const Color(0xFFCD7F32), // Bronze
                              ][index]
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: index < 3
                              ? Colors.black
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tag name and bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag.tag,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: barWidth,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Count
                  Text(
                    '${tag.count}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
