import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../providers/online_gallery_blacklist_provider.dart';
import '../autocomplete/autocomplete_config.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../common/app_toast.dart';
import '../danbooru_login_dialog.dart';
import '../tag_chip.dart';

class OnlineGalleryBlacklistSettingsPanel extends ConsumerStatefulWidget {
  final bool compact;
  final bool showSyncStatus;

  const OnlineGalleryBlacklistSettingsPanel({
    super.key,
    this.compact = false,
    this.showSyncStatus = true,
  });

  @override
  ConsumerState<OnlineGalleryBlacklistSettingsPanel> createState() =>
      _OnlineGalleryBlacklistSettingsPanelState();
}

class _OnlineGalleryBlacklistSettingsPanelState
    extends ConsumerState<OnlineGalleryBlacklistSettingsPanel> {
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();

  @override
  void dispose() {
    _tagController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onlineGalleryBlacklistNotifierProvider);
    final notifier = ref.read(onlineGalleryBlacklistNotifierProvider.notifier);
    final source = state.effectiveSource;
    final tags =
        (source == OnlineGalleryBlacklistSource.cloud
                ? state.remoteTags
                : state.localTags)
            .toList()
          ..sort();

    return Card(
      margin: widget.compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, tags.length),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<OnlineGalleryBlacklistSource>(
                segments: [
                  ButtonSegment(
                    value: OnlineGalleryBlacklistSource.local,
                    icon: const Icon(Icons.devices_outlined, size: 17),
                    label: Text(
                      '${context.l10n.onlineGallery_blacklistSourceLocal} · '
                      '${state.localTags.length}',
                    ),
                  ),
                  ButtonSegment(
                    value: OnlineGalleryBlacklistSource.cloud,
                    icon: const Icon(Icons.cloud_outlined, size: 17),
                    label: Text(
                      '${context.l10n.onlineGallery_blacklistSourceCloud} · '
                      '${state.remoteTags.length}',
                    ),
                    enabled: state.isCloudAvailable,
                  ),
                ],
                selected: {source},
                onSelectionChanged: state.isSyncing
                    ? null
                    : (selection) =>
                          notifier.setSelectedSource(selection.single),
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  source == OnlineGalleryBlacklistSource.cloud
                      ? Icons.cloud_done_outlined
                      : Icons.lock_outline,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    !state.isCloudAvailable
                        ? context.l10n.onlineGallery_blacklistCloudLoginRequired
                        : source == OnlineGalleryBlacklistSource.cloud
                        ? context.l10n.onlineGallery_blacklistCloudDescription
                        : context.l10n.onlineGallery_blacklistLocalDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (state.isCloudAvailable) ...[
              const SizedBox(height: 12),
              _buildTransferActions(theme, state),
              if (state.isSyncing) ...[
                const SizedBox(height: 6),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AutocompleteWrapper(
                    controller: _tagController,
                    focusNode: _tagFocusNode,
                    config: const AutocompleteConfig(
                      minQueryLength: 1,
                      autoInsertComma: false,
                      showTranslation: true,
                      enableChineseSearch: true,
                    ),
                    onSuggestionSelected: (_) => _addTag(),
                    child: TextField(
                      controller: _tagController,
                      focusNode: _tagFocusNode,
                      enabled: !state.isSyncing,
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText:
                            context.l10n.onlineGallery_addBlacklistTagHint,
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: context.l10n.common_add,
                      onPressed: state.isSyncing ? null : _addTag,
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 280),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: tags.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          source == OnlineGalleryBlacklistSource.cloud
                              ? context.l10n.onlineGallery_noCloudBlacklistTags
                              : context.l10n.onlineGallery_noLocalBlacklistTags,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in tags)
                            SimpleTagChip(
                              tag: tag,
                              color: theme.colorScheme.error,
                              onDeleted: state.isSyncing
                                  ? null
                                  : () => notifier.removeTag(tag),
                              deleteTooltip: context.l10n.common_delete,
                            ),
                        ],
                      ),
                    ),
            ),
            if (state.isCloudAvailable) ...[
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(context.l10n.onlineGallery_autoSyncOnStartup),
                subtitle: Text(
                  context.l10n.onlineGallery_autoSyncOnStartupSubtitle,
                ),
                value: state.autoSyncOnStartup,
                onChanged: state.isSyncing
                    ? null
                    : notifier.setAutoSyncOnStartup,
              ),
            ],
            if (widget.showSyncStatus) ...[
              const SizedBox(height: 4),
              _buildSyncStatus(theme, state),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.block,
            size: 19,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.onlineGallery_blacklistTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.onlineGallery_blacklistSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferActions(
    ThemeData theme,
    OnlineGalleryBlacklistState state,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: context.l10n.onlineGallery_pullBlacklistTooltip,
                child: OutlinedButton.icon(
                  onPressed: state.isSyncing ? null : _pullFromCloud,
                  icon: const Icon(Icons.cloud_download_outlined, size: 17),
                  label: Text(context.l10n.onlineGallery_pullBlacklist),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                message: context.l10n.onlineGallery_pushBlacklistTooltip,
                child: FilledButton.tonalIcon(
                  onPressed: state.isSyncing ? null : _pushToCloud,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 17),
                  label: Text(context.l10n.onlineGallery_pushBlacklist),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatus(ThemeData theme, OnlineGalleryBlacklistState state) {
    if (state.lastSyncError != null && state.lastSyncError!.isNotEmpty) {
      return Text(
        context.l10n.onlineGallery_lastSyncFailed(state.lastSyncError!),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    if (state.lastSyncAt == null) {
      return Text(
        context.l10n.onlineGallery_neverSyncedBlacklist,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final ts = state.lastSyncAt!;
    final text =
        '${ts.year}-${ts.month.toString().padLeft(2, '0')}-'
        '${ts.day.toString().padLeft(2, '0')} '
        '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}';

    return Text(
      context.l10n.onlineGallery_lastSync(text),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _addTag() async {
    final value = _tagController.text.trim();
    if (value.isEmpty) return;

    final added = await ref
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .addTag(value);
    if (!mounted || !added) return;
    _tagController.clear();
    _tagFocusNode.requestFocus();
  }

  Future<void> _pullFromCloud() async {
    final succeeded = await ref
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .pullFromCloud();
    if (!mounted) return;
    if (succeeded) {
      AppToast.success(
        context,
        context.l10n.onlineGallery_blacklistPullSucceeded,
      );
    } else {
      AppToast.error(
        context,
        context.l10n.onlineGallery_blacklistSyncFailedMessage,
      );
    }
  }

  Future<void> _pushToCloud() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.onlineGallery_pushBlacklistConfirmTitle),
        content: Text(
          dialogContext.l10n.onlineGallery_pushBlacklistConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.common_cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(dialogContext.l10n.onlineGallery_pushBlacklist),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final succeeded = await ref
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .pushLocalToCloud();
    if (!mounted) return;
    if (succeeded) {
      AppToast.success(
        context,
        context.l10n.onlineGallery_blacklistPushSucceeded,
      );
    } else {
      AppToast.error(
        context,
        context.l10n.onlineGallery_blacklistSyncFailedMessage,
      );
    }
  }
}

Future<void> showOnlineGalleryBlacklistDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final notifier = ref.read(onlineGalleryBlacklistNotifierProvider.notifier);
  notifier.ensureInitialized();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, dialogRef, _) {
        final isLoggedIn = dialogRef.watch(danbooruAuthProvider).isLoggedIn;
        return AlertDialog(
          title: Text(context.l10n.onlineGallery_blacklistSettingsTitle),
          content: SizedBox(
            width: 740,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isLoggedIn) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.onlineGallery_blacklistLoginHint,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              showDialog<void>(
                                context: context,
                                builder: (_) => const DanbooruLoginDialog(),
                              );
                            },
                            child: Text(context.l10n.onlineGallery_login),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const OnlineGalleryBlacklistSettingsPanel(
                    compact: true,
                    showSyncStatus: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.common_close),
            ),
          ],
        );
      },
    ),
  );
}
