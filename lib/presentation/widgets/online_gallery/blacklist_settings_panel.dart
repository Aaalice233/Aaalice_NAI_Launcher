import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/danbooru_auth_service.dart';
import '../../providers/online_gallery_blacklist_provider.dart';
import '../autocomplete/autocomplete_config.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../danbooru_login_dialog.dart';

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

    final localTags = state.localTags.toList()..sort();

    return Card(
      margin: widget.compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.block, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.onlineGallery_blacklistTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: state.isSyncing ? null : () => notifier.syncNow(),
                  icon: state.isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: Text(context.l10n.dataSource_syncNow),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.onlineGallery_blacklistSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AutocompleteWrapper(
                    controller: _tagController,
                    focusNode: _tagFocusNode,
                    config: const AutocompleteConfig(
                      minQueryLength: 1,
                      autoInsertComma: false,
                    ),
                    onSuggestionSelected: (_) => _addTag(),
                    child: TextField(
                      controller: _tagController,
                      focusNode: _tagFocusNode,
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
                IconButton(
                  tooltip: context.l10n.common_add,
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (localTags.isEmpty)
              Text(
                context.l10n.onlineGallery_noLocalBlacklistTags,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: localTags
                    .map(
                      (tag) => InputChip(
                        label: Text(tag),
                        onDeleted: () {
                          ref
                              .read(
                                onlineGalleryBlacklistNotifierProvider.notifier,
                              )
                              .removeLocalTag(tag);
                        },
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(context.l10n.onlineGallery_autoSyncOnStartup),
              subtitle: Text(
                context.l10n.onlineGallery_autoSyncOnStartupSubtitle,
              ),
              value: state.autoSyncOnStartup,
              onChanged: notifier.setAutoSyncOnStartup,
            ),
            if (widget.showSyncStatus) ...[
              const SizedBox(height: 4),
              _buildSyncStatus(theme, state),
            ],
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
        '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} '
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    return Text(
      context.l10n.onlineGallery_lastSync(text),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _addTag() {
    final value = _tagController.text.trim();
    if (value.isEmpty) return;

    ref
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .addLocalTag(value);
    _tagController.clear();
    _tagFocusNode.requestFocus();
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
    builder: (context) {
      final isLoggedIn = ref.read(danbooruAuthProvider).isLoggedIn;
      return AlertDialog(
        title: Text(context.l10n.onlineGallery_blacklistSettingsTitle),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isLoggedIn) ...[
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 6),
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
                  const SizedBox(height: 8),
                ],
                const OnlineGalleryBlacklistSettingsPanel(
                  compact: true,
                  showSyncStatus: false,
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
  );
}
