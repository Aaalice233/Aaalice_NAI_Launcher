import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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

    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('No aspect ratio data')),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: Row(
            children: [
              // Pie chart
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response?.touchedSection == null) {
                            _touchedIndex = null;
                            return;
                          }
                          _touchedIndex =
                              response!.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: widget.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isTouched = _touchedIndex == index;
                      final color = item.color ??
                          _defaultColors[index % _defaultColors.length];

                      return PieChartSectionData(
                        color: color,
                        value: item.count.toDouble(),
                        title: isTouched
                            ? '${item.percentage.toStringAsFixed(1)}%'
                            : '',
                        radius: isTouched ? 60 : 50,
                        titleStyle: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Aspect ratio preview cards
              if (widget.showLegend) ...[
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildLegend(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final color =
            item.color ?? _defaultColors[index % _defaultColors.length];
        final isTouched = _touchedIndex == index;

        return _AspectRatioLegendItem(
          item: item,
          color: color,
          isHighlighted: isTouched,
          onTap: () {
            setState(() {
              _touchedIndex = _touchedIndex == index ? null : index;
            });
          },
        );
      },
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? color.withOpacity(0.15)
              : colorScheme.surfaceContainerLow.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Aspect ratio preview box
            _AspectRatioPreview(
              ratio: item.ratio,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 8),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.ratio,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Count
            Text(
              '${item.count}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
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
          color: color.withOpacity(0.3),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
