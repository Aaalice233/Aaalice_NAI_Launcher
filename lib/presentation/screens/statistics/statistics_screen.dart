import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../themes/theme_extension.dart';
import 'statistics_state.dart';
import 'pages/pages.dart';
import 'widgets/navigation/dashboard_sidebar.dart';

/// Statistics Screen - Sidebar navigation design
/// 统计屏幕 - 左侧边栏导航设计
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final data = ref.watch(statisticsNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // 导航项列表
    final navItems = [
      DashboardNavItem(
        icon: Icons.dashboard_outlined,
        label: l10n.statistics_navOverview,
      ),
      DashboardNavItem(
        icon: Icons.category_outlined,
        label: l10n.statistics_navModels,
      ),
      DashboardNavItem(
        icon: Icons.local_offer_outlined,
        label: l10n.statistics_navTags,
      ),
      DashboardNavItem(
        icon: Icons.tune_outlined,
        label: l10n.statistics_navParameters,
      ),
      DashboardNavItem(
        icon: Icons.show_chart_outlined,
        label: l10n.statistics_navTrends,
      ),
      DashboardNavItem(
        icon: Icons.access_time_outlined,
        label: l10n.statistics_navActivity,
      ),
    ];

    // 页面列表
    const pages = [
      OverviewPage(),
      ModelPage(),
      TagPage(),
      ParameterPage(),
      TrendsPage(),
      ActivityPage(),
    ];

    // 移动端使用底部导航 + PageView
    if (isMobile) {
      return _buildMobileLayout(
        context,
        theme,
        l10n,
        colorScheme,
        data,
        navItems,
        pages,
      );
    }

    // 桌面端使用左侧边栏布局
    return _buildDesktopLayout(
      context,
      theme,
      l10n,
      colorScheme,
      extension,
      data,
      navItems,
      pages,
    );
  }

  /// 桌面端布局：左侧边栏 + 内容区
  Widget _buildDesktopLayout(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    AppThemeExtension? extension,
    StatisticsData data,
    List<DashboardNavItem> navItems,
    List<Widget> pages,
  ) {
    return Scaffold(
      body: Row(
        children: [
          // 左侧边栏
          DashboardSidebar(
            selectedIndex: _selectedIndex,
            onIndexChanged: (index) {
              setState(() => _selectedIndex = index);
            },
            items: navItems,
            isCollapsed: _sidebarCollapsed,
            onCollapsedChanged: () {
              setState(() => _sidebarCollapsed = !_sidebarCollapsed);
            },
          ),
          // 内容区
          Expanded(
            child: _buildContentArea(
              context,
              theme,
              l10n,
              colorScheme,
              extension,
              data,
              pages,
            ),
          ),
        ],
      ),
    );
  }

  /// 内容区域构建
  Widget _buildContentArea(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    AppThemeExtension? extension,
    StatisticsData data,
    List<Widget> pages,
  ) {
    final shadowIntensity = extension?.shadowIntensity ?? 0.15;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        // 左侧内阴影效果，增加层次感
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowIntensity * 0.3),
            blurRadius: 8,
            offset: const Offset(-2, 0),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(theme, l10n, colorScheme, extension, data),
          // 页面内容
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_selectedIndex),
                child: pages[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildHeader(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    AppThemeExtension? extension,
    StatisticsData data,
  ) {
    final borderColor = extension?.borderColor ?? colorScheme.outlineVariant;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: borderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 标题
          Icon(
            Icons.bar_chart_rounded,
            size: 24,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            l10n.statistics_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // 刷新按钮
          if (data.isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            _buildRefreshButton(theme, l10n, colorScheme),
        ],
      ),
    );
  }

  /// 刷新按钮
  Widget _buildRefreshButton(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => ref.read(statisticsNotifierProvider.notifier).refresh(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.statistics_refresh,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 移动端布局：底部导航
  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    StatisticsData data,
    List<DashboardNavItem> navItems,
    List<Widget> pages,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statistics_title),
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
              onPressed: () =>
                  ref.read(statisticsNotifierProvider.notifier).refresh(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: navItems.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}
