import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/localization_extension.dart';

import 'random_tree_view.dart';
import 'random_detail_view.dart';

class RandomLibraryManager extends ConsumerWidget {
  const RandomLibraryManager({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const RandomLibraryManager(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
          },
          child: Focus(
            autofocus: true,
            child: Container(
              width: 1200,
              height: 750,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Custom Title Bar
                  _TitleBar(
                    title: l10n.config_title,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  // Content
                  Expanded(
                    child: Row(
                      children: [
                        // Sidebar
                        Container(
                          width: 280,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            border: Border(
                              right: BorderSide(
                                color: colorScheme.outlineVariant.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: const RandomTreeView(),
                        ),
                        // Detail View
                        Expanded(
                          child: Container(
                            color: colorScheme.surface,
                            child: const RandomDetailView(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 38.0,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            iconSize: 18,
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
