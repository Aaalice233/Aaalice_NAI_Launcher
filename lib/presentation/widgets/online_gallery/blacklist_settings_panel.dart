import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/online_gallery/gallery_blacklist.dart';
import '../../../data/models/online_gallery/gallery_source.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/window_size_class.dart';
import '../../providers/online_gallery_blacklist_provider.dart';
import '../common/app_toast.dart';
import '../danbooru_login_dialog.dart';
import 'gallery_tag_rules_editor.dart';

class OnlineGalleryBlacklistSettingsPanel extends ConsumerStatefulWidget {
  const OnlineGalleryBlacklistSettingsPanel({
    super.key,
    this.compact = false,
    this.embedded = false,
    this.showSyncStatus = true,
    this.sourceId,
  });

  final bool compact;
  final bool embedded;
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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme, state),
        const SizedBox(height: 16),
        _buildAddRow(state),
        if (state.tags.length > 20) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _filterController,
            textAlignVertical: TextAlignVertical.center,
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
        _buildTagList(tags),
        const SizedBox(height: 8),
        _buildListActions(state),
        if (_supportsCloud) ...[
          const SizedBox(height: 14),
          _buildCloudSection(theme, state),
        ],
      ],
    );

    if (widget.embedded) {
      return content;
    }
    return Card(
      margin: widget.compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }

  Widget _buildHeader(ThemeData theme, OnlineGalleryBlacklistState state) {
    return GalleryTagRulesHeader(
      icon: Icons.block,
      title: context.l10n.onlineGallery_blacklistTitle,
      subtitle: context.l10n.onlineGallery_blacklistSubtitle,
      count: state.tags.length,
      accent: theme.colorScheme.error,
      onUndo: state.canUndo ? _undo : null,
    );
  }

  Widget _buildAddRow(OnlineGalleryBlacklistState state) {
    return GalleryTagRulesInput(
      controller: _tagController,
      focusNode: _tagFocusNode,
      hintText: context.l10n.onlineGallery_addBlacklistTagHint,
      onAdd: _addTag,
    );
  }

  Widget _buildTagList(List<String> tags) {
    return GalleryTagRulesList(
      tags: tags,
      emptyLabel: context.l10n.onlineGallery_noLocalBlacklistTags,
      keyPrefix: 'online-gallery-blacklist',
      maxHeight: 250,
      onDelete: _removeTag,
    );
  }

  Widget _buildListActions(OnlineGalleryBlacklistState state) {
    return GalleryTagRulesActions(
      clearEnabled: state.tags.isNotEmpty,
      onClear: _confirmClear,
      leading: OutlinedButton.icon(
        onPressed: _showImportDialog,
        icon: const Icon(Icons.playlist_add, size: 17),
        label: Text(context.l10n.common_import),
      ),
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
    final text = await AdaptivePresenter.showForm<String>(
      context: context,
      title: context.l10n.onlineGallery_blacklistImportTitle,
      sideSheetWidth: 560,
      builder: (panelContext, scrollController) =>
          _BlacklistImportForm(scrollController: scrollController),
    );
    if (text == null || !mounted) return;
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
        constraints: _responsiveDialogConstraints(dialogContext, 560),
        insetPadding: _responsiveDialogInsetPadding,
        scrollable: true,
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

    final confirmation =
        await AdaptivePresenter.showForm<_BlacklistPushReviewResult>(
          context: context,
          title: context.l10n.onlineGallery_pushBlacklistConfirmTitle,
          sideSheetWidth: 620,
          builder: (panelContext, scrollController) => _BlacklistPushReviewForm(
            preview: preview,
            scrollController: scrollController,
          ),
        );
    if (confirmation == null || !mounted) return;

    final succeeded = await notifier.pushToCloud(
      preview,
      confirmEmptyReplacement: confirmation.emptyConfirmed,
      confirmLegacyMigration: confirmation.migrationConfirmed,
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

  Future<void> _openLogin() {
    return AdaptivePresenter.showPanel<bool>(
      context: context,
      title: context.l10n.danbooru_loginTitle,
      initialChildSize: 0.82,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      sideSheetWidth: 440,
      builder: (_, scrollController) => DanbooruLoginDialog(
        embedded: true,
        scrollController: scrollController,
      ),
    );
  }
}

class _BlacklistPushReviewResult {
  const _BlacklistPushReviewResult({
    required this.emptyConfirmed,
    required this.migrationConfirmed,
  });

  final bool emptyConfirmed;
  final bool migrationConfirmed;
}

class _BlacklistPushReviewForm extends StatefulWidget {
  const _BlacklistPushReviewForm({
    required this.preview,
    required this.scrollController,
  });

  final GalleryBlacklistPushPreview preview;
  final ScrollController scrollController;

  @override
  State<_BlacklistPushReviewForm> createState() =>
      _BlacklistPushReviewFormState();
}

class _BlacklistPushReviewFormState extends State<_BlacklistPushReviewForm> {
  bool _emptyConfirmed = false;
  bool _migrationConfirmed = false;

  bool get _canSubmit =>
      (!widget.preview.requiresEmptyConfirmation || _emptyConfirmed) &&
      (!widget.preview.containsLegacyUnscopedData || _migrationConfirmed);

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('online-gallery-blacklist-push-review-scroll'),
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.onlineGallery_blacklistPushDiff(
                    preview.addedTags.length,
                    preview.removedTags.length,
                    preview.opaqueRulesToRemove.length,
                  ),
                ),
                if (preview.opaqueRulesToRemove.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.onlineGallery_pushBlacklistConfirmBody,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (preview.containsLegacyUnscopedData) ...[
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _migrationConfirmed,
                    onChanged: (value) =>
                        setState(() => _migrationConfirmed = value ?? false),
                    title: Text(
                      context.l10n.onlineGallery_blacklistMigrationConfirm,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                if (preview.requiresEmptyConfirmation) ...[
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _emptyConfirmed,
                    onChanged: (value) =>
                        setState(() => _emptyConfirmed = value ?? false),
                    title: Text(
                      context.l10n.onlineGallery_blacklistCloudEmptyConfirm,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.common_cancel),
              ),
              FilledButton.icon(
                key: const ValueKey(
                  'online-gallery-blacklist-push-review-submit',
                ),
                onPressed: _canSubmit
                    ? () => Navigator.pop(
                        context,
                        _BlacklistPushReviewResult(
                          emptyConfirmed: _emptyConfirmed,
                          migrationConfirmed: _migrationConfirmed,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(context.l10n.onlineGallery_pushBlacklist),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlacklistImportForm extends StatefulWidget {
  const _BlacklistImportForm({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_BlacklistImportForm> createState() => _BlacklistImportFormState();
}

class _BlacklistImportFormState extends State<_BlacklistImportForm> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('online-gallery-blacklist-import-scroll'),
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 10,
              autofocus: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: context.l10n.onlineGallery_blacklistImportHint,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.common_cancel),
              ),
              FilledButton(
                key: const ValueKey('online-gallery-blacklist-import-submit'),
                onPressed: () => Navigator.pop(context, _controller.text),
                child: Text(context.l10n.common_import),
              ),
            ],
          ),
        ),
      ],
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

  await AdaptivePresenter.showForm<void>(
    context: context,
    title: context.l10n.onlineGallery_blacklistSettingsTitle,
    sideSheetWidth: 728,
    builder: (panelContext, scrollController) => SingleChildScrollView(
      key: const ValueKey('online-gallery-blacklist-form-scroll'),
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: OnlineGalleryBlacklistSettingsPanel(
        compact: true,
        embedded: true,
        showSyncStatus: true,
        sourceId: sourceId,
      ),
    ),
  );
}

const _responsiveDialogInsetPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 12,
);

BoxConstraints _responsiveDialogConstraints(
  BuildContext context,
  double maxWidth,
) {
  final unobscuredSize = context.adaptiveWindow.unobscuredSize;
  final safeWidth = unobscuredSize.width - 24;
  final safeHeight = unobscuredSize.height - 24;
  return BoxConstraints(
    minWidth: safeWidth.clamp(0, 280).toDouble(),
    maxWidth: safeWidth.clamp(0, maxWidth).toDouble(),
    maxHeight: safeHeight.clamp(0, double.infinity).toDouble(),
  );
}
