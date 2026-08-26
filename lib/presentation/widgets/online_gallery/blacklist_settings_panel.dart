import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/online_gallery/gallery_source.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../providers/online_gallery_blacklist_provider.dart';
import '../autocomplete/autocomplete_config.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../common/app_toast.dart';
import '../danbooru_login_dialog.dart';

class OnlineGalleryBlacklistSettingsPanel extends ConsumerStatefulWidget {
  const OnlineGalleryBlacklistSettingsPanel({
    super.key,
    this.compact = false,
    this.showSyncStatus = true,
    this.sourceId,
  });

  final bool compact;
  final bool showSyncStatus;
  final GallerySourceId? sourceId;

  @override
  ConsumerState<OnlineGalleryBlacklistSettingsPanel> createState() =>
      _OnlineGalleryBlacklistSettingsPanelState();
}

class _OnlineGalleryBlacklistSettingsPanelState
    extends ConsumerState<OnlineGalleryBlacklistSettingsPanel> {
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();
  String _filter = '';
  int _sortedRevision = -1;
  List<String> _sortedTags = const [];

  bool get _supportsCloud =>
      widget.sourceId == null ||
      gallerySourceCapabilities[widget.sourceId]!.remoteBlacklist ==
          GalleryRemoteBlacklistCapability.readWrite;

  @override
  void dispose() {
    _tagController.dispose();
    _filterController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onlineGalleryBlacklistNotifierProvider);
    if (_sortedRevision != state.revision) {
      _sortedRevision = state.revision;
      _sortedTags = state.tags.toList()..sort();
    }
    final tags = _filter.isEmpty
        ? _sortedTags
        : _sortedTags.where((tag) => tag.contains(_filter)).toList();

    return Card(
      margin: widget.compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, state),
            const SizedBox(height: 16),
            _buildAddRow(state),
            if (state.tags.length > 20) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _filterController,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _filter.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _filterController.clear();
                            setState(() => _filter = '');
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                  border: const OutlineInputBorder(),
                  hintText: context.l10n.common_search,
                ),
                onChanged: (value) =>
                    setState(() => _filter = value.trim().toLowerCase()),
              ),
            ],
            const SizedBox(height: 12),
            _buildTagList(theme, tags),
            const SizedBox(height: 8),
            _buildListActions(state),
            if (_supportsCloud) ...[
              const SizedBox(height: 14),
              _buildCloudSection(theme, state),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, OnlineGalleryBlacklistState state) {
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
        if (state.canUndo)
          IconButton(
            tooltip: context.l10n.common_undo,
            onPressed: _undo,
            icon: const Icon(Icons.undo, size: 19),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${state.tags.length}',
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

  Widget _buildAddRow(OnlineGalleryBlacklistState state) {
    return Row(
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
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: context.l10n.onlineGallery_addBlacklistTagHint,
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
              onPressed: _addTag,
              icon: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagList(ThemeData theme, List<String> tags) {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: tags.isEmpty
          ? Center(
              child: Text(
                context.l10n.onlineGallery_noLocalBlacklistTags,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              key: const ValueKey('online-gallery-blacklist-virtual-list'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemExtent: 40,
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return ListTile(
                  dense: true,
                  minTileHeight: 40,
                  title: Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: context.l10n.common_delete,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeTag(tag),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildListActions(OnlineGalleryBlacklistState state) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _showImportDialog,
          icon: const Icon(Icons.playlist_add, size: 17),
          label: Text(context.l10n.common_import),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: state.tags.isEmpty ? null : _confirmClear,
          icon: const Icon(Icons.delete_sweep_outlined, size: 17),
          label: Text(context.l10n.common_clear),
        ),
      ],
    );
  }

  Widget _buildCloudSection(
    ThemeData theme,
    OnlineGalleryBlacklistState state,
  ) {
    final auth = ref.watch(danbooruAuthProvider);
    final isCloudAvailable = state.isCloudAvailable && auth.isLoggedIn;
    if (!isCloudAvailable) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.hasCloudCredentials || auth.isLoading
                    ? context.l10n.onlineGallery_blacklistCloudUnavailable
                    : context.l10n.onlineGallery_blacklistCloudLoginRequired,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (!auth.isLoading && !state.hasCloudCredentials)
              TextButton(
                onPressed: _openLogin,
                child: Text(context.l10n.onlineGallery_login),
              ),
          ],
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 17,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    context.l10n.onlineGallery_blacklistCloudDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final pull = OutlinedButton.icon(
                  onPressed: state.isSyncing ? null : _pullFromCloud,
                  icon: const Icon(Icons.cloud_download_outlined, size: 17),
                  label: Text(context.l10n.onlineGallery_pullBlacklist),
                );
                final push = FilledButton.tonalIcon(
                  onPressed: state.isSyncing ? null : _pushToCloud,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 17),
                  label: Text(context.l10n.onlineGallery_pushBlacklist),
                );
                if (constraints.maxWidth < 430) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [pull, const SizedBox(height: 6), push],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: pull),
                    const SizedBox(width: 8),
                    Expanded(child: push),
                  ],
                );
              },
            ),
            if (state.isSyncing) ...[
              const SizedBox(height: 7),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (widget.showSyncStatus) ...[
              const SizedBox(height: 8),
              _buildSyncStatus(theme, state),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(context.l10n.onlineGallery_autoSyncOnStartup),
              subtitle: Text(
                context.l10n.onlineGallery_autoSyncOnStartupSubtitle,
              ),
              value: state.autoSyncOnStartup,
              onChanged: state.isSyncing ? null : _setAutoSyncOnStartup,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatus(ThemeData theme, OnlineGalleryBlacklistState state) {
    if (state.lastSyncError case final error? when error.isNotEmpty) {
      return Text(
        context.l10n.onlineGallery_lastSyncFailed(error),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    final lastSyncAt = state.lastSyncAt;
    if (lastSyncAt == null) {
      return Text(
        context.l10n.onlineGallery_neverSyncedBlacklist,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final text =
        '${lastSyncAt.year}-${lastSyncAt.month.toString().padLeft(2, '0')}-'
        '${lastSyncAt.day.toString().padLeft(2, '0')} '
        '${lastSyncAt.hour.toString().padLeft(2, '0')}:'
        '${lastSyncAt.minute.toString().padLeft(2, '0')}';
    return Text(
      context.l10n.onlineGallery_lastSync(text),
      style: theme.textTheme.bodySmall?.copyWith(
        color: state.isCloudCacheStale
            ? theme.colorScheme.tertiary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _addTag() async {
    final value = _tagController.text.trim();
    if (value.isEmpty) return;
    try {
      final added = await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .addTag(value);
      if (!mounted || !added) return;
      _tagController.clear();
      _tagFocusNode.requestFocus();
    } catch (error) {
      _showLocalSaveError(error);
    }
  }

  Future<void> _removeTag(String tag) async {
    try {
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .removeTag(tag);
    } catch (error) {
      _showLocalSaveError(error);
    }
  }

  Future<void> _undo() async {
    try {
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .undoLastMutation();
    } catch (error) {
      _showLocalSaveError(error);
    }
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.onlineGallery_blacklistImportTitle),
        content: TextField(
          controller: controller,
          minLines: 5,
          maxLines: 10,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: dialogContext.l10n.onlineGallery_blacklistImportHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.common_import),
          ),
        ],
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (confirmed != true || !mounted) return;
    try {
      final count = await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .importTags(text.split(RegExp(r'[,，、\r\n]+')));
      if (mounted) {
        AppToast.success(
          context,
          context.l10n.onlineGallery_blacklistImported(count),
        );
      }
    } catch (error) {
      _showLocalSaveError(error);
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.onlineGallery_blacklistClearTitle),
        content: Text(dialogContext.l10n.onlineGallery_blacklistClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.common_clear),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref
            .read(onlineGalleryBlacklistNotifierProvider.notifier)
            .clearTags();
      } catch (error) {
        _showLocalSaveError(error);
      }
    }
  }

  Future<void> _setAutoSyncOnStartup(bool value) async {
    try {
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .setAutoSyncOnStartup(value);
    } catch (error) {
      _showLocalSaveError(error);
    }
  }

  void _showLocalSaveError(Object error) {
    if (!mounted) return;
    AppToast.error(
      context,
      context.l10n.onlineGallery_blacklistSaveFailed('$error'),
    );
  }

  Future<void> _pullFromCloud() async {
    final result = await ref
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .pullFromCloud();
    if (!mounted) return;
    if (result == null) {
      AppToast.error(
        context,
        context.l10n.onlineGallery_blacklistSyncFailedMessage,
      );
      return;
    }
    AppToast.success(
      context,
      context.l10n.onlineGallery_blacklistPullSummary(
        result.addedCount,
        result.existingCount,
        result.skippedDeletedCount,
        result.opaqueRuleCount,
      ),
    );
  }

  Future<void> _pushToCloud() async {
    final notifier = ref.read(onlineGalleryBlacklistNotifierProvider.notifier);
    final preview = await notifier.preparePushToCloud();
    if (!mounted) return;
    if (preview == null) {
      AppToast.error(
        context,
        context.l10n.onlineGallery_blacklistSyncFailedMessage,
      );
      return;
    }
    if (preview.isEmpty) {
      AppToast.success(
        context,
        context.l10n.onlineGallery_blacklistPushSucceeded,
      );
      return;
    }

    final requiresEmptyConfirmation = preview.requiresEmptyConfirmation;
    final requiresMigrationConfirmation = preview.containsLegacyUnscopedData;
    var emptyConfirmed = false;
    var migrationConfirmed = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            dialogContext.l10n.onlineGallery_pushBlacklistConfirmTitle,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dialogContext.l10n.onlineGallery_blacklistPushDiff(
                    preview.addedTags.length,
                    preview.removedTags.length,
                    preview.opaqueRulesToRemove.length,
                  ),
                ),
                if (preview.opaqueRulesToRemove.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogContext.l10n.onlineGallery_pushBlacklistConfirmBody,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ],
                if (requiresMigrationConfirmation) ...[
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: migrationConfirmed,
                    onChanged: (value) => setDialogState(
                      () => migrationConfirmed = value ?? false,
                    ),
                    title: Text(
                      dialogContext
                          .l10n
                          .onlineGallery_blacklistMigrationConfirm,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                if (requiresEmptyConfirmation) ...[
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: emptyConfirmed,
                    onChanged: (value) =>
                        setDialogState(() => emptyConfirmed = value ?? false),
                    title: Text(
                      dialogContext
                          .l10n
                          .onlineGallery_blacklistCloudEmptyConfirm,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.l10n.common_cancel),
            ),
            FilledButton.icon(
              onPressed:
                  (requiresEmptyConfirmation && !emptyConfirmed) ||
                      (requiresMigrationConfirmation && !migrationConfirmed)
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(dialogContext.l10n.onlineGallery_pushBlacklist),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final succeeded = await notifier.pushToCloud(
      preview,
      confirmEmptyReplacement: emptyConfirmed,
      confirmLegacyMigration: migrationConfirmed,
    );
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

  void _openLogin() {
    showDialog<void>(
      context: context,
      builder: (_) => const DanbooruLoginDialog(),
    );
  }
}

Future<void> showOnlineGalleryBlacklistDialog(
  BuildContext context,
  WidgetRef ref, {
  required GallerySourceId sourceId,
}) async {
  unawaited(
    ref
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .ensureInitialized(),
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.onlineGallery_blacklistSettingsTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: OnlineGalleryBlacklistSettingsPanel(
            compact: true,
            showSyncStatus: true,
            sourceId: sourceId,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.l10n.common_close),
        ),
      ],
    ),
  );
}
