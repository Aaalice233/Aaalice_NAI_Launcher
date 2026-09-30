import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Aspect ratio item data
class AspectRatioItem {
  final String ratio;
  final String label; // e.g., "Portrait", "Landscape", "Square"
  final int count;
  final double percentage;
  final Color? color;

  const AspectRatioItem({
    required this.ratio,
    required this.label,
    required this.count,
    required this.percentage,
    this.color,
  });
}

/// Aspect ratio distribution chart
class AspectRatioChart extends StatefulWidget {
  final List<AspectRatioItem> items;
  final double height;
  final bool showLegend;

  const AspectRatioChart({
    super.key,
    required this.items,
    this.height = 200,
    this.showLegend = true,
  });

  @override
  State<AspectRatioChart> createState() => _AspectRatioChartState();
}

class _AspectRatioChartState extends State<AspectRatioChart> {
  int? _touchedIndex;

  static const _defaultColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFF3B82F6), // Blue
    Color(0xFFEC4899), // Pink
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text(context.l10n.statistics_noData)),
      );
    }

    final chart = PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  response?.touchedSection == null) {
                _touchedIndex = null;
                return;
              }
              _touchedIndex = response!.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        sections: widget.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isTouched = _touchedIndex == index;
          final color =
              item.color ?? _defaultColors[index % _defaultColors.length];

          return PieChartSectionData(
            color: isTouched ? color : color.withValues(alpha: 0.88),
            value: item.count.toDouble(),
            title: isTouched ? '${item.percentage.toStringAsFixed(1)}%' : '',
            radius: 44,
            titleStyle: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
      ),
      swapAnimationDuration: reducedMotion
          ? Duration.zero
          : theme.appTheme.fastDuration,
    );

    if (!widget.showLegend) {
      return SizedBox(height: widget.height, child: chart);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale =
            (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 3.0);
        if (constraints.maxWidth / textScale < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: widget.height, child: chart),
              const SizedBox(height: 12),
              _buildLegend(),
            ],
          );
        }
        // The legend grows with text size; a fixed width pushes counts out.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(height: widget.height, child: chart),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _legendBaseWidth * textScale,
              child: _buildLegend(),
            ),
          ],
        );
      },
    );
  }

  static const double _legendBaseWidth = 140;

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in widget.items.indexed) ...[
          if (index > 0) const SizedBox(height: 4),
          _AspectRatioLegendItem(
            item: item,
            color: item.color ?? _defaultColors[index % _defaultColors.length],
            isHighlighted: _touchedIndex == index,
            onTap: () {
              setState(() {
                _touchedIndex = _touchedIndex == index ? null : index;
              });
            },
          ),
        ],
      ],
    );
  }
}

class _AspectRatioLegendItem extends StatelessWidget {
  final AspectRatioItem item;
  final Color color;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _AspectRatioLegendItem({
    required this.item,
    required this.color,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        constraints: const BoxConstraints(minHeight: 48),
        duration: reducedMotion ? Duration.zero : theme.appTheme.fastDuration,
        curve: theme.appTheme.standardCurve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isHighlighted
              ? color.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isHighlighted ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Aspect ratio preview box
            _AspectRatioPreview(ratio: item.ratio, color: color, size: 20),
            const SizedBox(width: 6),
            // Info and count; the count drops below the info when narrow
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.ratio,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${item.count}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AspectRatioPreview extends StatelessWidget {
  final String ratio;
  final Color color;
  final double size;

  const _AspectRatioPreview({
    required this.ratio,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // Parse ratio like "16:9", "4:3", "1:1"
    final parts = ratio.split(':');
    double w = 1, h = 1;
    if (parts.length == 2) {
      w = double.tryParse(parts[0]) ?? 1;
      h = double.tryParse(parts[1]) ?? 1;
    }

    // Normalize to fit within size
    final scale = size / (w > h ? w : h);
    final boxW = w * scale;
    final boxH = h * scale;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Container(
        width: boxW,
        height: boxH,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
