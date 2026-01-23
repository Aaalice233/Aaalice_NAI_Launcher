import 'package:flutter/material.dart';

class ProEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final List<Widget>? actions;

  const ProEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration-style Icon Container
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            // Description
            if (description != null) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Text(
                  description!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // Actions
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
