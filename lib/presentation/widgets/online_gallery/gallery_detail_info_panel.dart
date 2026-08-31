import 'package:flutter/material.dart';

import '../../../core/utils/prompt_tag_utils.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../../data/models/online_gallery/gallery_source.dart';
import '../tag_chip.dart';
import 'gallery_detail_models.dart';
import 'gallery_detail_overview_card.dart';
import 'gallery_detail_tag_section.dart';
import 'gallery_detail_text_section.dart';

class GalleryDetailInfoPanel extends StatelessWidget {
  const GalleryDetailInfoPanel({
    super.key,
    required this.viewModel,
    required this.actions,
    required this.primaryActions,
  });

  final GalleryDetailViewModel viewModel;
  final GalleryDetailActions actions;
  final Widget primaryActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isQuickTagCloud =
        viewModel.item.sourceId == GallerySourceId.quickTagCloud;
    final codexTitle = _metadataString('codexTitle');
    final contributorNames = viewModel.detail.contributors
        .map((contributor) => contributor.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final attributions = <String>[];
    for (final value in [
      viewModel.currentMedia?.metadata['credit']?.toString(),
      viewModel.currentMedia?.metadata['author']?.toString(),
      viewModel.item.author,
    ]) {
      for (final part in (value ?? '').split(' · ')) {
        final normalized = part.trim();
        if (normalized.isNotEmpty &&
            !contributorNames.contains(normalized) &&
            !attributions.contains(normalized)) {
          attributions.add(normalized);
        }
      }
    }
    final author = attributions.join(' · ');
    final currentMedia = viewModel.currentMedia;
    final imageFile = currentMedia?.metadata['path']?.toString().trim() ?? '';
    final originalFile =
        currentMedia != null && galleryMediaHasOriginal(currentMedia)
        ? currentMedia.metadata['original']?.toString().trim() ?? ''
        : '';
    final preferredFile = originalFile.isNotEmpty ? originalFile : imageFile;
    final preferredFileLabel = originalFile.isNotEmpty
        ? viewModel.labels.originalFile
        : viewModel.labels.imageFile;
    final declaredSource = _metadataString('declaredSource');
    final normalizedDeclaredSource = declaredSource.toLowerCase();
    final repeatsContributor = contributorNames.any(
      (name) => normalizedDeclaredSource.contains(name.toLowerCase()),
    );
    final showDeclaredSource =
        declaredSource.isNotEmpty && (!isQuickTagCloud || !repeatsContributor);
    final categoryPath = viewModel.detail.categoryPath
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final promptIsRepresentedByTags =
        viewModel.detail.prompt?.trim().isNotEmpty == true &&
        viewModel.detail.item.tagString.trim() ==
            viewModel.detail.prompt!.trim();
    final showPromptCard = viewModel.hasPrompt && !promptIsRepresentedByTags;
    final note = viewModel.detail.note?.trim().isNotEmpty == true
        ? viewModel.detail.note!.trim()
        : viewModel.detail.description?.trim() ?? '';

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const ValueKey('gallery-detail-info-list'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            children: [
              if (isQuickTagCloud)
                _buildCodexOverview(
                  context,
                  codexTitle: codexTitle,
                  categoryPath: categoryPath,
                  fileLabel: preferredFileLabel,
                  fileName: preferredFile,
                  author: author,
                  declaredSource: showDeclaredSource ? declaredSource : '',
                  note: note,
                )
              else ...[
                _buildItemBadges(theme),
                if (codexTitle.isNotEmpty || categoryPath.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GalleryDetailOverviewCard(
                    icon: Icons.menu_book_rounded,
                    title: codexTitle.isNotEmpty
                        ? codexTitle
                        : categoryPath.last,
                    subtitle: codexTitle.isNotEmpty
                        ? categoryPath.join(' / ')
                        : '',
                  ),
                ],
                if (viewModel.detail.item.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildTagSections(
                    context,
                    sectionLabel: promptIsRepresentedByTags
                        ? viewModel.labels.positivePrompt
                        : '',
                  ),
                ],
              ],
              if (!isQuickTagCloud && showPromptCard) ...[
                const SizedBox(height: 16),
                _buildPromptTagSection(
                  context,
                  label: viewModel.labels.positivePrompt,
                  prompt: viewModel.detail.prompt!.trim(),
                  color: TagColors.general,
                ),
              ],
              if (!isQuickTagCloud && viewModel.hasNegativePrompt) ...[
                const SizedBox(height: 12),
                _buildPromptTagSection(
                  context,
                  label: viewModel.labels.negativePrompt,
                  prompt: viewModel.detail.negativePrompt!.trim(),
                  color: theme.colorScheme.error,
                ),
              ],
              if (!isQuickTagCloud &&
                  viewModel.displayCharacterPrompts.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  viewModel.labels.characterPrompts,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (
                  var index = 0;
                  index < viewModel.displayCharacterPrompts.length;
                  index++
                ) ...[
                  _buildCharacterTagSection(
                    context,
                    viewModel.displayCharacterPrompts[index],
                    index,
                  ),
                  if (index + 1 < viewModel.displayCharacterPrompts.length)
                    const SizedBox(height: 8),
                ],
              ],
              if (!isQuickTagCloud && note.isNotEmpty) ...[
                const SizedBox(height: 12),
                GalleryDetailTextSection(
                  title: viewModel.labels.note,
                  content: note,
                  accentColor: theme.colorScheme.tertiary,
                ),
              ],
              if (!isQuickTagCloud && viewModel.currentRawTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                GalleryDetailTextSection(
                  title: viewModel.labels.rawTags,
                  content: viewModel.currentRawTags.join('\n'),
                  accentColor: theme.colorScheme.secondary,
                  monospace: true,
                ),
              ],
              if (!isQuickTagCloud && preferredFile.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.image_outlined,
                  label: preferredFileLabel,
                  value: preferredFile,
                ),
              ],
              if (!isQuickTagCloud && author.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.person_outline,
                  label: viewModel.labels.author,
                  value: author,
                ),
              ],
              if (!isQuickTagCloud && showDeclaredSource) ...[
                const SizedBox(height: 12),
                _buildCompactMetadata(
                  theme,
                  icon: Icons.dataset_outlined,
                  label: viewModel.labels.declaredSource,
                  value: declaredSource,
                ),
              ],
              if (!isQuickTagCloud &&
                  viewModel.detail.contributors.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildContributors(theme),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        primaryActions,
      ],
    );
  }

  Widget _buildItemBadges(ThemeData theme) {
    final item = viewModel.detail.item;
    final stats = <({IconData icon, String label, String value, Color accent})>[
      if (item.viewCount != null)
        (
          icon: Icons.visibility_rounded,
          label: viewModel.labels.views,
          value: '${item.viewCount}',
          accent: theme.colorScheme.primary,
        ),
      if (item.favoriteCount != null)
        (
          icon: Icons.favorite_rounded,
          label: viewModel.labels.favoriteCount,
          value: '${item.favoriteCount}',
          accent: theme.colorScheme.error,
        ),
      if (item.score != null)
        (
          icon: Icons.star_rounded,
          label: viewModel.labels.score,
          value: '${item.score}',
          accent: theme.colorScheme.tertiary,
        ),
      if (item.rating?.trim().isNotEmpty == true)
        (
          icon: Icons.shield_rounded,
          label: viewModel.labels.rating,
          value: item.rating!.toUpperCase(),
          accent: theme.colorScheme.secondary,
        ),
    ];
    final badges = <Widget>[
      if (item.rank != null) Chip(label: Text('#${item.rank}')),
      if (item.aiType?.trim().isNotEmpty == true)
        Chip(label: Text(item.aiType!.trim())),
      if (item.mediaCount > 1)
        Chip(label: Text(viewModel.labels.multipleImages(item.mediaCount))),
    ];
    if (stats.isEmpty && badges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final itemWidth = stats.length == 1
                  ? constraints.maxWidth.clamp(0.0, 124.0).toDouble()
                  : (constraints.maxWidth - gap * (stats.length - 1)) /
                        stats.length;
              return Wrap(
                key: const ValueKey('gallery-detail-stats'),
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final stat in stats)
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatItem(theme, stat),
                    ),
                ],
              );
            },
          ),
        if (stats.isNotEmpty && badges.isNotEmpty) const SizedBox(height: 10),
        if (badges.isNotEmpty)
          Wrap(spacing: 7, runSpacing: 7, children: badges),
      ],
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    ({IconData icon, String label, String value, Color accent}) stat,
  ) {
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          stat.accent.withValues(alpha: dark ? 0.12 : 0.08),
          theme.colorScheme.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: stat.accent.withValues(alpha: dark ? 0.2 : 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(stat.icon, size: 16, color: stat.accent),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stat.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSections(
    BuildContext context, {
    String sectionLabel = '',
    VoidCallback? onCopySection,
    String sectionCopyTooltip = '',
  }) {
    final item = viewModel.detail.item;
    final artists = PromptTagUtils.uniqueForDisplay(item.artistTags);
    final characters = PromptTagUtils.uniqueForDisplay(item.characterTags);
    final copyrights = PromptTagUtils.uniqueForDisplay(item.copyrightTags);
    final general = PromptTagUtils.uniqueForDisplay(item.generalTags);
    final metadata = PromptTagUtils.uniqueForDisplay(item.metaTags);
    final categorized = {
      for (final tag in [
        ...artists,
        ...characters,
        ...copyrights,
        ...general,
        ...metadata,
      ])
        tag.toLowerCase(),
    };
    final uncategorized = PromptTagUtils.uniqueForDisplay(
      item.tags.where((tag) => !categorized.contains(tag.trim().toLowerCase())),
    );
    return _buildTagCollection(
      [
        if (artists.isNotEmpty)
          GalleryDetailTagGroup(
            label: viewModel.labels.artists,
            tags: artists,
            color: TagColors.artist,
          ),
        if (characters.isNotEmpty)
          GalleryDetailTagGroup(
            label: viewModel.labels.characters,
            tags: characters,
            color: TagColors.character,
          ),
        if (copyrights.isNotEmpty)
          GalleryDetailTagGroup(
            label: viewModel.labels.copyrights,
            tags: copyrights,
            color: TagColors.copyright,
          ),
        if (categorized.isNotEmpty &&
            (general.isNotEmpty || uncategorized.isNotEmpty))
          GalleryDetailTagGroup(
            label: viewModel.labels.general,
            tags: PromptTagUtils.uniqueForDisplay([
              ...general,
              ...uncategorized,
            ]),
            color: TagColors.general,
          ),
        if (metadata.isNotEmpty)
          GalleryDetailTagGroup(
            label: viewModel.labels.metadata,
            tags: metadata,
            color: TagColors.meta,
          ),
        if (categorized.isEmpty && uncategorized.isNotEmpty)
          GalleryDetailTagGroup(
            label: viewModel.labels.rawTags,
            tags: uncategorized,
            color: TagColors.general,
          ),
      ],
      sectionLabel: sectionLabel,
      onCopySection: onCopySection,
      sectionCopyTooltip: sectionCopyTooltip,
    );
  }

  Widget _buildPromptTagSection(
    BuildContext context, {
    required String label,
    required String prompt,
    required Color color,
    VoidCallback? onCopy,
    String copyTooltip = '',
  }) {
    return _buildTagCollection([
      GalleryDetailTagGroup(
        label: label,
        tags: PromptTagUtils.parseForDisplay(prompt),
        color: color,
        onCopy: onCopy,
        copyTooltip: copyTooltip,
      ),
    ]);
  }

  Widget _buildCharacterTagSection(
    BuildContext context,
    GalleryCharacterPrompt character,
    int index,
  ) {
    final groups = <GalleryDetailTagGroup>[];
    final positive = PromptTagUtils.parseForDisplay(character.prompt);
    final negative = PromptTagUtils.parseForDisplay(character.negativePrompt);
    if (positive.isNotEmpty) {
      groups.add(
        GalleryDetailTagGroup(
          label: viewModel.labels.positivePrompt,
          tags: positive,
          color: TagColors.general,
        ),
      );
    }
    if (negative.isNotEmpty) {
      groups.add(
        GalleryDetailTagGroup(
          label: viewModel.labels.negativePrompt,
          tags: negative,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
    return _buildTagCollection(
      groups,
      sectionLabel: character.label.trim().isEmpty
          ? '#${index + 1}'
          : character.label.trim(),
    );
  }

  Widget _buildTagCollection(
    List<GalleryDetailTagGroup> groups, {
    String sectionLabel = '',
    VoidCallback? onCopySection,
    String sectionCopyTooltip = '',
  }) {
    return GalleryDetailTagSection(
      groups: groups,
      sectionLabel: sectionLabel,
      onCopySection: onCopySection,
      sectionCopyTooltip: sectionCopyTooltip,
      isOutputFiltered: viewModel.isOutputFiltered,
      normalTooltip: viewModel.labels.tagContextMenuTooltip,
      filteredTooltip: viewModel.labels.outputFilteredTagTooltip,
      onTagTap: actions.searchTag,
      onTagSecondaryTapUp: actions.showTagMenu,
    );
  }

  Widget _buildCodexOverview(
    BuildContext context, {
    required String codexTitle,
    required List<String> categoryPath,
    required String fileLabel,
    required String fileName,
    required String author,
    required String declaredSource,
    required String note,
  }) {
    final theme = Theme.of(context);
    final item = viewModel.detail.item;
    final rating = item.rating?.trim().toUpperCase() ?? '';
    final content = <Widget>[];
    void addContent(Widget child) {
      if (content.isNotEmpty) content.add(const SizedBox(height: 12));
      content.add(child);
    }

    final positivePrompt = viewModel.detail.prompt?.trim().isNotEmpty == true
        ? viewModel.detail.prompt!.trim()
        : item.tagString.trim().isNotEmpty
        ? item.tagString.trim()
        : item.tags.join(', ');
    if (positivePrompt.isNotEmpty) {
      addContent(
        _buildPromptTagSection(
          context,
          label: viewModel.labels.positivePrompt,
          prompt: positivePrompt,
          color: TagColors.general,
        ),
      );
    }
    if (viewModel.hasNegativePrompt) {
      addContent(
        _buildPromptTagSection(
          context,
          label: viewModel.labels.negativePrompt,
          prompt: viewModel.detail.negativePrompt!.trim(),
          color: theme.colorScheme.error,
        ),
      );
    }
    if (viewModel.displayCharacterPrompts.isNotEmpty) {
      addContent(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              viewModel.labels.characterPrompts,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (
              var index = 0;
              index < viewModel.displayCharacterPrompts.length;
              index++
            ) ...[
              _buildCharacterTagSection(
                context,
                viewModel.displayCharacterPrompts[index],
                index,
              ),
              if (index + 1 < viewModel.displayCharacterPrompts.length)
                const SizedBox(height: 12),
            ],
          ],
        ),
      );
    }
    if (note.isNotEmpty) {
      addContent(
        GalleryDetailTextSection(
          title: viewModel.labels.note,
          content: note,
          accentColor: theme.colorScheme.tertiary,
        ),
      );
    }
    if (viewModel.currentRawTags.isNotEmpty) {
      addContent(
        GalleryDetailTextSection(
          title: viewModel.labels.rawTags,
          content: viewModel.currentRawTags.join('\n'),
          accentColor: theme.colorScheme.secondary,
          monospace: true,
        ),
      );
    }

    return GalleryDetailOverviewCard(
      icon: Icons.auto_stories_rounded,
      title: codexTitle.isEmpty ? viewModel.labels.codex : codexTitle,
      subtitle: categoryPath.join(' / '),
      badge: rating.isEmpty
          ? null
          : GalleryDetailOverviewBadgeData(
              icon: Icons.shield_rounded,
              label: rating,
              tooltip: viewModel.labels.rating,
            ),
      content: content.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
      metadata: [
        if (fileName.isNotEmpty)
          GalleryDetailOverviewMetadata(
            icon: Icons.image_rounded,
            label: fileLabel,
            value: fileName,
          ),
        if (author.isNotEmpty)
          GalleryDetailOverviewMetadata(
            icon: Icons.person_rounded,
            label: viewModel.labels.author,
            value: author,
          ),
        if (declaredSource.isNotEmpty)
          GalleryDetailOverviewMetadata(
            icon: Icons.dataset_rounded,
            label: viewModel.labels.declaredSource,
            value: declaredSource,
          ),
        for (final contributor in viewModel.detail.contributors)
          GalleryDetailOverviewMetadata(
            icon: Icons.person_rounded,
            value: contributor.role.trim().isEmpty
                ? contributor.name
                : '${contributor.name} · ${contributor.role.trim()}',
          ),
      ],
    );
  }

  Widget _buildCompactMetadata(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label  ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContributors(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups_rounded,
                  size: 17,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  viewModel.labels.contributors,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            for (
              var index = 0;
              index < viewModel.detail.contributors.length;
              index++
            ) ...[
              _buildContributor(theme, viewModel.detail.contributors[index]),
              if (index + 1 < viewModel.detail.contributors.length)
                const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContributor(ThemeData theme, GalleryContributor contributor) {
    final role = contributor.role.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.person_rounded,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            role.isEmpty ? contributor.name : '${contributor.name} · $role',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  String _metadataString(String key) =>
      viewModel.detail.rawSourceMetadata[key]?.toString().trim() ?? '';
}
