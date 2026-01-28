import 'package:flutter/material.dart';
import '../../../../themes/theme_extension.dart';

/// Section header widget
/// 章节标题组件
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.15),
                colorScheme.primary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Chart card wrapper with consistent styling and enhanced visual effects
/// 图表卡片包装器，提供一致的样式和增强的视觉效果
class ChartCard extends StatefulWidget {
  final Widget child;
  final String? title;
  final IconData? titleIcon;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool elevated;
  final Color? accentColor;

  const ChartCard({
    super.key,
    required this.child,
    this.title,
    this.titleIcon,
    this.trailing,
    this.padding,
    this.elevated = true,
    this.accentColor,
  });

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final shadowIntensity = extension?.shadowIntensity ?? 0.1;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = widget.accentColor ?? colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerLow,
              colorScheme.surfaceContainer.withOpacity(isDark ? 0.7 : 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered
                ? accentColor.withOpacity(0.25)
                : colorScheme.outlineVariant.withOpacity(0.12),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: widget.elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      _isHovered ? shadowIntensity * 1.5 : shadowIntensity,
                    ),
                    blurRadius: _isHovered ? 18 : 12,
                    offset: Offset(0, _isHovered ? 6 : 4),
                    spreadRadius: _isHovered ? -2 : -4,
                  ),
                  // Subtle colored glow
                  if (_isHovered)
                    BoxShadow(
                      color: accentColor.withOpacity(isDark ? 0.1 : 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -6,
                    ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Subtle decorative gradient accent line at top
              if (widget.title != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(_isHovered ? 0.6 : 0.3),
                          accentColor.withOpacity(_isHovered ? 0.3 : 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              // Main content
              Padding(
                padding: widget.padding ?? EdgeInsets.all(isDesktop ? 22 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title != null) ...[
                      Row(
                        children: [
                          if (widget.titleIcon != null) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    accentColor.withOpacity(0.15),
                                    accentColor.withOpacity(0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.titleIcon,
                                size: 18,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              widget.title!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (widget.trailing != null) widget.trailing!,
                        ],
                      ),
                      SizedBox(height: isDesktop ? 18 : 14),
                    ],
                    widget.child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stat row widget for key-value display
/// Enhanced with improved spacing and hover effects
class StatRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final Color? valueColor;

  const StatRow({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: labelStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (valueColor ?? colorScheme.primary).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: valueStyle ??
                  theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget for charts
/// Enhanced with better visual hierarchy and animation
class ChartEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const ChartEmptyState({
    super.key,
    this.icon = Icons.bar_chart_outlined,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.surfaceContainerHighest,
                          colorScheme.surfaceContainerHigh,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
