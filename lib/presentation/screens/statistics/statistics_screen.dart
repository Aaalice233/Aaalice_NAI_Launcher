import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'statistics_state.dart';
import 'pages/pages.dart';

/// Statistics Screen - Multi-tab navigation design
/// 统计屏幕 - 多标签导航设计
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final data = ref.watch(statisticsNotifierProvider);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(l10n.statistics_title),
              floating: true,
              snap: true,
              actions: [
                if (data.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: l10n.statistics_refresh,
                    onPressed: () => ref.read(statisticsNotifierProvider.notifier).refresh(),
                  ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _buildTabBar(theme, l10n, colorScheme),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: const [
            OverviewPage(),
            ModelPage(),
            TagPage(),
            ParameterPage(),
            TrendsPage(),
            ActivityPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, AppLocalizations l10n, ColorScheme colorScheme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.9),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.3),
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: [
              _buildTab(Icons.dashboard_outlined, l10n.statistics_navOverview, isCompact),
              _buildTab(Icons.category_outlined, l10n.statistics_navModels, isCompact),
              _buildTab(Icons.local_offer_outlined, l10n.statistics_navTags, isCompact),
              _buildTab(Icons.tune_outlined, l10n.statistics_navParameters, isCompact),
              _buildTab(Icons.show_chart_outlined, l10n.statistics_navTrends, isCompact),
              _buildTab(Icons.access_time_outlined, l10n.statistics_navActivity, isCompact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(IconData icon, String label, bool compact) {
    if (compact) {
      return Tab(
        child: Tooltip(
          message: label,
          child: Icon(icon),
        ),
      );
    }
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
