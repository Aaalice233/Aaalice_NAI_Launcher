import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/autocomplete/autocomplete_providers.dart';
import '../../../../core/autocomplete/autocomplete_settings.dart';
import '../../../../core/autocomplete/cooccurrence_data_pack_provider.dart';
import '../../../../core/autocomplete/cooccurrence_data_pack_service.dart';
import '../../../../core/autocomplete/completion_models.dart';
import '../../../../core/autocomplete/zh_dictionary_models.dart';
import '../../../../core/utils/byte_format.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../prompt_assistant/services/prompt_assistant_service.dart';
import '../../../providers/generation/generation_settings_notifiers.dart'
    as generation_settings;
import '../../../widgets/common/app_toast.dart';
import 'settings_card.dart';
import 'settings_data_status_tile.dart';

class DataSourceCacheSettings extends ConsumerWidget {
  const DataSourceCacheSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(autocompleteSettingsProvider);
    final autocompleteEnabled = ref.watch(
      generation_settings.autocompleteSettingsProvider,
    );
    final zh = ref.watch(zhDictionaryServiceProvider).state;
    final cacheStatistics = ref.watch(autocompleteCacheStatisticsProvider);
    final notifier = ref.read(autocompleteSettingsProvider.notifier);
    final route = ref
        .watch(promptAssistantServiceProvider)
        .translateRouteLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: context.l10n.autocomplete_settingsTitle,
          icon: Icons.auto_awesome,
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_enable),
                value: autocompleteEnabled,
                onChanged: (value) {
                  ref
                      .read(
                        generation_settings
                            .autocompleteSettingsProvider
                            .notifier,
                      )
                      .set(value);
                },
              ),
              ListTile(
                title: Text(context.l10n.autocomplete_resultLimit),
                trailing: DropdownButton<int>(
                  value: settings.resultLimit,
                  items: [
                    ...const [10, 15, 20, 30, 50, 75, 100].map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text('$value')),
                    ),
                    DropdownMenuItem(
                      value: CompletionResultLimits.all,
                      child: Text(context.l10n.autocomplete_allResults),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) notifier.setResultLimit(value);
                  },
                ),
              ),
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_showAliases),
                value: settings.showAliases,
                onChanged: notifier.setShowAliases,
              ),
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_showTranslations),
                value: settings.showTranslations,
                onChanged: notifier.setShowTranslations,
              ),
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_autoComma),
                value: settings.autoInsertComma,
                onChanged: notifier.setAutoInsertComma,
              ),
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_openOnTagClick),
                subtitle: Text(
                  context.l10n.autocomplete_openOnTagClickSubtitle,
                ),
                value: settings.openOnTagClick,
                onChanged: notifier.setOpenOnTagClick,
              ),
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_replaceUnderscores),
                value: settings.replaceUnderscores,
                onChanged: notifier.setReplaceUnderscores,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsCard(
          title: context.l10n.autocomplete_dataSourcesTitle,
          icon: Icons.storage_outlined,
          child: Column(
            children: [
              _CatalogStatus(ref: ref),
              _ZhDictionaryStatus(state: zh),
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_relatedTagsTitle),
                subtitle: Text(context.l10n.autocomplete_relatedTagsSubtitle),
                value: settings.relatedTagsEnabled,
                onChanged: (value) async {
                  await notifier.setRelatedTagsEnabled(value);
                  if (value && settings.autoDownloadRelatedData) {
                    await ref
                        .read(cooccurrenceDataPackServiceProvider.notifier)
                        .install();
                  }
                },
              ),
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_cooccurrenceAutoDownload),
                subtitle: Text(
                  context.l10n.autocomplete_cooccurrenceAutoDownloadSubtitle,
                ),
                value: settings.autoDownloadRelatedData,
                onChanged: (value) async {
                  await notifier.setAutoDownloadRelatedData(value);
                  if (value && settings.relatedTagsEnabled) {
                    await ref
                        .read(cooccurrenceDataPackServiceProvider.notifier)
                        .install();
                  }
                },
              ),
              const _CooccurrenceDataPackStatus(),
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_danbooruApi),
                subtitle: Text(context.l10n.autocomplete_danbooruPrivacy),
                value: settings.danbooruEnabled,
                onChanged: notifier.setDanbooruEnabled,
              ),
              SwitchListTile.adaptive(
                title: Text(context.l10n.autocomplete_llmTranslation),
                subtitle: Text(
                  route.isEmpty
                      ? context.l10n.autocomplete_llmRouteMissing
                      : context.l10n.autocomplete_llmRoute(route),
                ),
                value: settings.llmTranslationEnabled,
                onChanged: (value) {
                  if (value && route.isEmpty) {
                    AppToast.warning(
                      context,
                      context.l10n.autocomplete_llmRouteMissing,
                    );
                    return;
                  }
                  notifier.setLlmTranslationEnabled(value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SettingsCard(
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
                  OutlinedButton.icon(
                    onPressed: () async {
                      final count = await ref
                          .read(autocompleteCacheDatabaseProvider)
                          .clearDanbooruCache();
                      ref.invalidate(autocompleteCacheStatisticsProvider);
                      if (context.mounted) {
                        AppToast.success(
                          context,
                          context.l10n.autocomplete_cacheCleared(count),
                        );
                      }
                    },
                    icon: const Icon(Icons.cloud_off_outlined),
                    label: Text(context.l10n.autocomplete_clearDanbooruCache),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final count = await ref
                          .read(autocompleteCacheDatabaseProvider)
                          .clearAiTranslationCache();
                      ref.invalidate(autocompleteCacheStatisticsProvider);
                      if (context.mounted) {
                        AppToast.success(
                          context,
                          context.l10n.autocomplete_cacheCleared(count),
                        );
                      }
                    },
                    icon: const Icon(Icons.translate_outlined),
                    label: Text(context.l10n.autocomplete_clearAiCache),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CooccurrenceDataPackStatus extends ConsumerWidget {
  const _CooccurrenceDataPackStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cooccurrenceDataPackServiceProvider);
    final service = ref.read(cooccurrenceDataPackServiceProvider.notifier);
    final busy = switch (state.status) {
      CooccurrenceDataPackStatus.downloading ||
      CooccurrenceDataPackStatus.verifying ||
      CooccurrenceDataPackStatus.installing ||
      CooccurrenceDataPackStatus.checking => true,
      _ => false,
    };
    final subtitle = _subtitle(context, state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsDataStatusTile(
          leading: busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  state.hasInstalledData
                      ? Icons.hub_outlined
                      : Icons.download_for_offline_outlined,
                ),
          title: Text(context.l10n.autocomplete_cooccurrence),
          subtitle: Text(subtitle),
          actions: [
            if (state.status == CooccurrenceDataPackStatus.downloading)
              IconButton(
                tooltip: context.l10n.common_cancel,
                onPressed: service.cancelDownload,
                icon: const Icon(Icons.pause),
              )
            else if (!busy && !state.hasInstalledData)
              FilledButton.tonal(
                onPressed: service.install,
                child: Text(
                  state.status == CooccurrenceDataPackStatus.error
                      ? context.l10n.common_retry
                      : context.l10n.autocomplete_downloadNow,
                ),
              )
            else if (!busy && state.hasInstalledData) ...[
              IconButton(
                tooltip: context.l10n.autocomplete_checkUpdate,
                onPressed: service.checkForUpdate,
                icon: const Icon(Icons.refresh),
              ),
              FilledButton.tonal(
                onPressed:
                    state.status == CooccurrenceDataPackStatus.updateAvailable
                    ? service.install
                    : service.repair,
                child: Text(
                  state.status == CooccurrenceDataPackStatus.updateAvailable
                      ? context.l10n.autocomplete_update
                      : context.l10n.autocomplete_repair,
                ),
              ),
              IconButton(
                tooltip: context.l10n.autocomplete_remove,
                onPressed: () => _confirmDelete(context, ref, service),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        if (state.status == CooccurrenceDataPackStatus.downloading)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 24, 8),
            child: LinearProgressIndicator(value: state.progress),
          ),
      ],
    );
  }

  String _subtitle(BuildContext context, CooccurrenceDataPackState state) {
    return switch (state.status) {
      CooccurrenceDataPackStatus.unavailable =>
        context.l10n.autocomplete_cooccurrenceUnavailable(
          formatBytes(state.totalBytes),
        ),
      CooccurrenceDataPackStatus.checking =>
        context.l10n.autocomplete_cooccurrenceChecking,
      CooccurrenceDataPackStatus.downloading =>
        context.l10n.autocomplete_cooccurrenceDownloading(
          formatBytes(state.downloadedBytes),
          formatBytes(state.totalBytes),
          formatBytesPerSecond(state.bytesPerSecond),
        ),
      CooccurrenceDataPackStatus.verifying =>
        context.l10n.autocomplete_cooccurrenceVerifying,
      CooccurrenceDataPackStatus.installing =>
        context.l10n.autocomplete_cooccurrenceInstalling,
      CooccurrenceDataPackStatus.updateAvailable =>
        context.l10n.autocomplete_cooccurrenceUpdateAvailable(
          state.availableVersion ?? '-',
        ),
      CooccurrenceDataPackStatus.ready =>
        context.l10n.autocomplete_cooccurrenceReady(
          state.installedVersion ?? '-',
          state.relationCount,
          formatBytes(state.diskBytes),
        ),
      CooccurrenceDataPackStatus.error =>
        context.l10n.autocomplete_cooccurrenceFailed(
          _errorLabel(context, state.error),
        ),
    };
  }

  String _errorLabel(BuildContext context, CooccurrenceDataPackError? error) {
    return switch (error) {
      CooccurrenceDataPackError.diskFull =>
        context.l10n.autocomplete_cooccurrenceErrorDiskFull,
      CooccurrenceDataPackError.archiveIntegrity =>
        context.l10n.autocomplete_cooccurrenceErrorArchive,
      CooccurrenceDataPackError.databaseIntegrity =>
        context.l10n.autocomplete_cooccurrenceErrorDatabase,
      CooccurrenceDataPackError.manifest =>
        context.l10n.autocomplete_cooccurrenceErrorManifest,
      CooccurrenceDataPackError.install =>
        context.l10n.autocomplete_cooccurrenceErrorInstall,
      _ => context.l10n.autocomplete_cooccurrenceErrorNetwork,
    };
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CooccurrenceDataPackService service,
  ) async {
    var stopAutomaticDownloads = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.autocomplete_cooccurrenceRemoveTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.autocomplete_cooccurrenceRemoveConfirm),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: stopAutomaticDownloads,
                onChanged: (value) =>
                    setState(() => stopAutomaticDownloads = value ?? false),
                title: Text(
                  context.l10n.autocomplete_cooccurrenceStopAutoDownload,
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.autocomplete_remove),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (stopAutomaticDownloads) {
      await ref
          .read(autocompleteSettingsProvider.notifier)
          .setAutoDownloadRelatedData(false);
    }
    await service.deleteData();
  }
}

class _CatalogStatus extends StatelessWidget {
  const _CatalogStatus({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: ref.read(tagCatalogRepositoryProvider).metadata(),
      builder: (context, snapshot) {
        final metadata = snapshot.data;
        return ListTile(
          leading: Icon(
            metadata == null ? Icons.hourglass_top : Icons.check_circle_outline,
          ),
          title: Text(context.l10n.autocomplete_baseCatalog),
          subtitle: Text(
            metadata == null
                ? context.l10n.common_loading
                : context.l10n.autocomplete_catalogStatus(
                    metadata['tag_count'] ?? '0',
                    metadata['data_version'] ?? '-',
                  ),
          ),
        );
      },
    );
  }
}

class _ZhDictionaryStatus extends ConsumerWidget {
  const _ZhDictionaryStatus({required this.state});

  final ZhDictionaryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(zhDictionaryServiceProvider);
    return SettingsDataStatusTile(
      leading: state.isBusy
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: state.progress > 0 ? state.progress : null,
              ),
            )
          : Icon(
              state.isInstalled
                  ? Icons.translate_outlined
                  : Icons.download_outlined,
            ),
      title: Text(context.l10n.autocomplete_zhDictionary),
      subtitle: Text(
        (state.error == null
                ? null
                : _zhDictionaryErrorMessage(context, state)) ??
            (state.isInstalled
                ? context.l10n.autocomplete_zhInstalled(
                    state.tagCount,
                    state.version?.substring(0, 8) ?? '-',
                  )
                : context.l10n.autocomplete_zhNotInstalled),
      ),
      actions: [
        if (state.isBusy)
          IconButton(
            tooltip: context.l10n.common_cancel,
            onPressed: service.cancelInstall,
            icon: const Icon(Icons.close),
          )
        else ...[
          if (state.isInstalled)
            IconButton(
              tooltip: context.l10n.autocomplete_checkUpdate,
              onPressed: () => service.checkForUpdate(force: true),
              icon: const Icon(Icons.refresh),
            ),
          FilledButton.tonal(
            onPressed: () async {
              if (!state.isInstalled) {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.l10n.autocomplete_zhDictionary),
                    content: Text(context.l10n.autocomplete_zhInstallPrompt),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.common_cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.autocomplete_install),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
              }
              try {
                await service.installOrUpdate();
              } catch (error) {
                if (context.mounted) {
                  AppToast.error(
                    context,
                    _zhDictionaryErrorMessage(context, service.state),
                  );
                }
              }
            },
            child: Text(
              state.isInstalled
                  ? state.updateAvailable
                        ? context.l10n.autocomplete_update
                        : context.l10n.autocomplete_repair
                  : context.l10n.autocomplete_install,
            ),
          ),
          if (state.isInstalled)
            IconButton(
              tooltip: context.l10n.autocomplete_remove,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.l10n.autocomplete_remove),
                    content: Text(context.l10n.autocomplete_removeConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.common_cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.common_confirm),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await service.remove();
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ],
    );
  }
}

String _zhDictionaryErrorMessage(
  BuildContext context,
  ZhDictionaryState state,
) {
  final l10n = context.l10n;
  if (state.failureKind == ZhDictionaryFailureKind.rateLimited &&
      state.failureStage == ZhDictionaryFailureStage.metadata) {
    return l10n.autocomplete_zhErrorMetadataRateLimited;
  }
  if (state.failureKind == ZhDictionaryFailureKind.accessDenied) {
    return state.failureStage == ZhDictionaryFailureStage.download
        ? l10n.autocomplete_zhErrorDownloadAccessDenied
        : l10n.autocomplete_zhErrorMetadataAccessDenied;
  }
  if (state.failureKind == ZhDictionaryFailureKind.network) {
    return l10n.autocomplete_zhErrorNetwork;
  }
  if (state.failureKind == ZhDictionaryFailureKind.integrity ||
      state.failureStage == ZhDictionaryFailureStage.integrity) {
    return l10n.autocomplete_zhErrorIntegrity;
  }
  return l10n.autocomplete_zhErrorUnknown;
}
