import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../data/models/gallery/gallery_statistics.dart';
import '../statistics_state.dart';
import '../widgets/widgets.dart';

/// Tag analysis page - tag distribution and cloud
class TagPage extends ConsumerStatefulWidget {
  const TagPage({super.key});

  @override
  ConsumerState<TagPage> createState() => _TagPageState();
}

class _TagPageState extends ConsumerState<TagPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final data = ref.watch(statisticsNotifierProvider);

    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = data.statistics;
    if (stats == null || stats.tagDistribution.isEmpty) {
      return Center(
        child: ChartEmptyState(
          icon: Icons.local_offer_outlined,
          title: l10n.statistics_noData,
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRanking(theme, stats, l10n)),
              const SizedBox(width: 20),
              Expanded(child: _buildCloud(theme, stats, l10n)),
            ],
          )
        else ...[
          _buildRanking(theme, stats, l10n),
          const SizedBox(height: 20),
          _buildCloud(theme, stats, l10n),
        ],
      ],
    );
  }

  Widget _buildRanking(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    final tagItems = stats.tagDistribution.map((t) {
      return TagCloudItem(tag: t.tagName, count: t.count);
    }).toList();

    return ChartCard(
      title: l10n.statistics_chartTopTags,
      titleIcon: Icons.leaderboard_outlined,
      child: TopTagsRanking(tags: tagItems, maxItems: 20),
    );
  }

  Widget _buildCloud(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    final tagItems = stats.tagDistribution
        .take(80)
        .map((t) => TagCloudItem(tag: t.tagName, count: t.count))
        .toList();

    return ChartCard(
      title: l10n.statistics_chartTagCloud,
      titleIcon: Icons.cloud_outlined,
      child: SizedBox(
        height: 400,
        child: TagCloudWidget(tags: tagItems, onTagTap: (tag) {}),
      ),
    );
  }
}
