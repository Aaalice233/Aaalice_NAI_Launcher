import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/autocomplete/autocomplete_providers.dart';
import '../../../../core/database/database_error_summary.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/autocomplete_cache_clear_provider.dart';
import '../../../widgets/common/app_toast.dart';
import 'settings_card.dart';

class AutocompleteCacheCard extends ConsumerWidget {
  const AutocompleteCacheCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheStatistics = ref.watch(autocompleteCacheStatisticsProvider);
    final clearing = ref.watch(autocompleteCacheClearProvider);

    return SettingsCard(
      title: context.l10n.autocomplete_cacheTitle,
      icon: Icons.cleaning_services_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cacheStatistics.when(
            data: (statistics) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                context.l10n.autocomplete_aiCacheEntries(
                  statistics['aiTranslations'] ?? 0,
                ),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _ClearCacheButton(
                icon: Icons.cloud_off_outlined,
                label: context.l10n.autocomplete_clearDanbooruCache,
                busy: clearing.contains(AutocompleteCacheKind.danbooru),
                onPressed: () =>
                    _clear(context, ref, AutocompleteCacheKind.danbooru),
              ),
              _ClearCacheButton(
                icon: Icons.translate_outlined,
                label: context.l10n.autocomplete_clearAiCache,
                busy: clearing.contains(AutocompleteCacheKind.aiTranslations),
                onPressed: () =>
                    _clear(context, ref, AutocompleteCacheKind.aiTranslations),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _clear(
    BuildContext context,
    WidgetRef ref,
    AutocompleteCacheKind kind,
  ) async {
    final clearer = ref.read(autocompleteCacheClearProvider.notifier);
    try {
      final count = await clearer.clear(kind);
      if (!context.mounted) return;
      AppToast.success(context, context.l10n.autocomplete_cacheCleared(count));
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to clear autocomplete cache: ${kind.name}',
        databaseErrorSummary(error),
        stackTrace,
      );
      if (!context.mounted) return;
      AppToast.error(context, context.l10n.autocomplete_cacheClearFailed);
    }
  }
}

class _ClearCacheButton extends StatelessWidget {
  const _ClearCacheButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                value: MediaQuery.disableAnimationsOf(context) ? 0.75 : null,
                strokeWidth: 2,
              ),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}
