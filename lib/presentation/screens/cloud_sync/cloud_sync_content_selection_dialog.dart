import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/agent/skill_catalog.dart';
import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../themes/core/layered_surface_style.dart';
import 'cloud_sync_agent_content_section.dart';

Future<CloudSyncContentSelection?> showCloudSyncContentSelectionDialog({
  required BuildContext context,
  required CloudSyncContentSelection initialSelection,
  required SkillCatalogSnapshot skills,
}) => AdaptivePresenter.showPanel<CloudSyncContentSelection>(
  context: context,
  title: context.l10n.cloudSync_chooseBackupContents,
  dialogWidth: 720,
  initialChildSize: 0.92,
  minChildSize: 0.62,
  maxChildSize: 0.96,
  builder: (context, scrollController) => _CloudSyncContentSelectionBody(
    initialSelection: initialSelection,
    skills: skills,
    scrollController: scrollController,
  ),
);

class _CloudSyncContentSelectionBody extends StatefulWidget {
  const _CloudSyncContentSelectionBody({
    required this.initialSelection,
    required this.skills,
    required this.scrollController,
  });

  final CloudSyncContentSelection initialSelection;
  final SkillCatalogSnapshot skills;
  final ScrollController scrollController;

  @override
  State<_CloudSyncContentSelectionBody> createState() =>
      _CloudSyncContentSelectionBodyState();
}

class _CloudSyncContentSelectionBodyState
    extends State<_CloudSyncContentSelectionBody> {
  late CloudSyncContentSelection _selection = widget.initialSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = math.min(720.0, MediaQuery.sizeOf(context).height * 0.76);
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('cloud-sync-content-selection-list'),
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              children: [
                Text(
                  context.l10n.cloudSync_backupContentDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _selectionGroup(
                  key: 'lightweight',
                  title: context.l10n.cloudSync_lightweightData,
                  children: [
                    _toggle(
                      key: 'settings',
                      title: context.l10n.cloudSync_kindSettings,
                      subtitle: context.l10n.cloudSync_settingsDescription,
                      value: _selection.includeSettings,
                      onChanged: (value) =>
                          _update(_selection.copyWith(includeSettings: value)),
                    ),
                    _toggle(
                      key: 'prompts-tags',
                      title: context.l10n.cloudSync_promptsAndTags,
                      subtitle:
                          context.l10n.cloudSync_promptsAndTagsDescription,
                      value: _selection.includePromptsAndTags,
                      onChanged: (value) => _update(
                        _selection.copyWith(includePromptsAndTags: value),
                      ),
                    ),
                    _toggle(
                      key: 'tag-thumbnails',
                      title: context.l10n.cloudSync_tagThumbnails,
                      subtitle: context.l10n.cloudSync_tagThumbnailsDescription,
                      value: _selection.includeTagThumbnails,
                      onChanged: _selection.includePromptsAndTags
                          ? (value) => _update(
                              _selection.copyWith(includeTagThumbnails: value),
                            )
                          : null,
                    ),
                    _toggle(
                      key: 'online-gallery-settings',
                      title: context.l10n.cloudSync_onlineGallerySettings,
                      subtitle: context
                          .l10n
                          .cloudSync_onlineGallerySettingsDescription,
                      value: _selection.includeOnlineGallerySettings,
                      onChanged: (value) => _update(
                        _selection.copyWith(
                          includeOnlineGallerySettings: value,
                        ),
                      ),
                    ),
                    _toggle(
                      key: 'online-gallery-favorites',
                      title: context.l10n.cloudSync_onlineGalleryFavorites,
                      subtitle: context
                          .l10n
                          .cloudSync_onlineGalleryFavoritesDescription,
                      value: _selection.includeOnlineGalleryFavorites,
                      onChanged: (value) => _update(
                        _selection.copyWith(
                          includeOnlineGalleryFavorites: value,
                        ),
                      ),
                    ),
                    _toggle(
                      key: 'gallery-albums',
                      title: context.l10n.cloudSync_galleryAlbums,
                      subtitle: context.l10n.cloudSync_galleryAlbumsDescription,
                      value: _selection.includeGalleryAlbums,
                      onChanged: (value) => _update(
                        _selection.copyWith(includeGalleryAlbums: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _selectionGroup(
                  key: 'agent',
                  title: context.l10n.cloudSync_agentContentTitle,
                  children: [
                    CloudSyncAgentContentSection(
                      selection: _selection,
                      skills: widget.skills,
                      onChanged: _update,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _selectionGroup(
                  key: 'optional-resources',
                  title: context.l10n.cloudSync_optionalResources,
                  children: [
                    _toggle(
                      key: 'vibes',
                      title: context.l10n.cloudSync_vibes,
                      subtitle: context.l10n.cloudSync_largeResourceDescription,
                      value: _selection.includeVibes,
                      onChanged: (value) =>
                          _update(_selection.copyWith(includeVibes: value)),
                    ),
                    _toggle(
                      key: 'precise-references',
                      title: context.l10n.cloudSync_preciseReferences,
                      subtitle: context.l10n.cloudSync_largeResourceDescription,
                      value: _selection.includePreciseReferences,
                      onChanged: (value) => _update(
                        _selection.copyWith(includePreciseReferences: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.cloudSync_neverBackedUp,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _footer(context),
        ],
      ),
    );
  }

  Widget _selectionGroup({
    required String key,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      key: ValueKey('cloud-sync-content-group-$key'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          key: ValueKey('cloud-sync-content-group-$key-surface'),
          color: sectionSurfaceColor(theme.colorScheme),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) const SizedBox(height: 4),
                  children[index],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final defaults = TextButton(
      key: const ValueKey('cloud-sync-content-defaults'),
      onPressed: () => _update(const CloudSyncContentSelection()),
      child: Text(context.l10n.cloudSync_restoreDefaults),
    );
    final actions = Wrap(
      key: const ValueKey('cloud-sync-content-actions'),
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cloudSync_cancel),
        ),
        FilledButton(
          key: const ValueKey('cloud-sync-content-save'),
          onPressed: () => Navigator.of(context).pop(_selection),
          child: Text(context.l10n.cloudSync_saveSelection),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5) {
            return SingleChildScrollView(
              key: const ValueKey('cloud-sync-content-footer-scroll'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [defaults, const SizedBox(width: 24), actions],
              ),
            );
          }
          return Row(
            children: [
              defaults,
              const SizedBox(width: 24),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: actions),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toggle({
    required String key,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => SwitchListTile(
    key: ValueKey('cloud-sync-content-$key'),
    contentPadding: EdgeInsets.zero,
    minTileHeight: 56,
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );

  void _update(CloudSyncContentSelection value) {
    setState(() => _selection = value);
  }
}
