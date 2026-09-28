import 'package:flutter/material.dart';

/// Keeps data-source metadata readable when its actions cannot fit beside it.
class SettingsDataStatusTile extends StatelessWidget {
  const SettingsDataStatusTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  static const double compactBreakpoint = 600;

  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionGroup = Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );

        if (constraints.maxWidth >= compactBreakpoint) {
          return ListTile(
            leading: leading,
            title: title,
            subtitle: subtitle,
            trailing: actionGroup,
          );
        }

        final theme = Theme.of(context);
        final tileTheme = ListTileTheme.of(context);
        final titleStyle =
            tileTheme.titleTextStyle ?? theme.textTheme.bodyLarge;
        final subtitleStyle =
            tileTheme.subtitleTextStyle ??
            theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            );
        final iconColor =
            tileTheme.iconColor ?? theme.colorScheme.onSurfaceVariant;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox.square(
                  dimension: 24,
                  child: IconTheme.merge(
                    data: IconThemeData(color: iconColor, size: 24),
                    child: leading,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(style: titleStyle, child: title),
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: subtitleStyle,
                      child: subtitle,
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actionGroup,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
