import 'dart:ui';
import 'package:flutter/material.dart';

enum DialogType { info, warning, danger }

class ProDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final DialogType type;

  const ProDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.type = DialogType.info,
  });

  Color _getTypeColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case DialogType.danger:
        return colorScheme.error;
      case DialogType.warning:
        return Colors.orange;
      case DialogType.info:
      default:
        return colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 32,
              spreadRadius: -4,
              offset: Offset.zero,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: colorScheme.surface.withOpacity(0.95),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: _getTypeColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),

                  // Content
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ) ??
                            const TextStyle(),
                        child: content,
                      ),
                    ),
                  ),

                  // Actions
                  if (actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions.map((action) {
                          final index = actions.indexOf(action);
                          return Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 0 : 8.0,
                            ),
                            child: action,
                          );
                        }).toList(),
                      ),
                    )
                  else
                    const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
