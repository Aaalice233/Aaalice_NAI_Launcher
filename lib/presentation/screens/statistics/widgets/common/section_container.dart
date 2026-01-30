import 'package:flutter/material.dart';
import '../../../../widgets/common/themed_divider.dart';

/// Container for statistics sections with consistent styling
class SectionContainer extends StatelessWidget {
  final GlobalKey sectionKey;
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool showDivider;

  const SectionContainer({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.padding,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Container(
      key: sectionKey,
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 16,
            vertical: isDesktop ? 24 : 20,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 20),
          // Section content
          child,
          // Bottom divider
          if (showDivider) ...[
            const SizedBox(height: 24),
            const ThemedDivider(height: 1),
          ],
        ],
      ),
    );
  }
}

/// Grid layout helper for statistics cards
class StatsGrid extends StatelessWidget {
  final List<Widget> children;
  final int desktopColumns;
  final int tabletColumns;
  final int mobileColumns;
  final double spacing;
  final double runSpacing;

  const StatsGrid({
    super.key,
    required this.children,
    this.desktopColumns = 4,
    this.tabletColumns = 2,
    this.mobileColumns = 1,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = screenWidth >= 900
        ? desktopColumns
        : screenWidth >= 600
            ? tabletColumns
            : mobileColumns;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

/// Two-column layout for desktop with responsive stacking
class ResponsiveTwoColumn extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double spacing;
  final double leftFlex;
  final double rightFlex;

  const ResponsiveTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 16,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex.toInt(), child: left),
          SizedBox(width: spacing),
          Expanded(flex: rightFlex.toInt(), child: right),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        left,
        SizedBox(height: spacing),
        right,
      ],
    );
  }
}
