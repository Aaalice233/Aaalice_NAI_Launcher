import 'package:flutter/material.dart';

import '../../../core/autocomplete/completion_models.dart';
import '../../../core/utils/localization_extension.dart';

class CompletionEmptyBody extends StatelessWidget {
  const CompletionEmptyBody({super.key, required this.state});

  final CompletionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = state.isLocalLoading || state.isRemoteLoading;
    final related = state.query?.relatedTag != null;
    final error = state.localError ?? state.remoteError;
    return SizedBox(
      key: const ValueKey('autocomplete-popup-empty'),
      height: 78,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    value: MediaQuery.disableAnimationsOf(context)
                        ? 0.75
                        : null,
                    strokeWidth: 1.8,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Icon(
                  error == null
                      ? Icons.manage_search_rounded
                      : Icons.error_outline_rounded,
                  size: 18,
                  color: error == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              const SizedBox(width: 9),
              Flexible(
                child: Tooltip(
                  message: error ?? '',
                  child: Text(
                    loading
                        ? related
                              ? context.l10n.autocomplete_relatedLoading
                              : context.l10n.autocomplete_loading
                        : error == null
                        ? related
                              ? context.l10n.autocomplete_relatedEmpty
                              : context.l10n.autocomplete_empty
                        : context.l10n.autocomplete_statusError,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: error == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
