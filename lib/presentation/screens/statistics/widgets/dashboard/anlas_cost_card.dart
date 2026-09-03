import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/utils/app_logger.dart';
import '../../../../../data/services/anlas_statistics_service.dart';
import '../../../../adaptive/adaptive_presenter.dart';
import '../cards/chart_card.dart';

enum AnlasStatisticsPeriod { week, month, threeMonths, year, all, custom }

/// 点数花费统计卡片 - 按日期统计Anlas消耗趋势
/// Anlas cost card - displays Anlas consumption trend by date
class AnlasCostCard extends ConsumerStatefulWidget {
  const AnlasCostCard({super.key});

  @override
  ConsumerState<AnlasCostCard> createState() => _AnlasCostCardState();
}

class _AnlasCostCardState extends ConsumerState<AnlasCostCard> {
  static const _periodPreferenceKey = 'anlas_statistics_period';
  static const _customDaysPreferenceKey = 'anlas_statistics_custom_days';
  static const _defaultCustomDays = 30;
  static const _maxCustomDays = 36500;

  AnlasStatisticsPeriod _selectedPeriod = AnlasStatisticsPeriod.month;
  int _customDays = _defaultCustomDays;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPeriodPreference());
  }

  Future<void> _loadPeriodPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPeriod = prefs.getString(_periodPreferenceKey);
      final period = AnlasStatisticsPeriod.values
          .where((value) => value.name == storedPeriod)
          .firstOrNull;
      final storedCustomDays = prefs.getInt(_customDaysPreferenceKey);
      if (!mounted) return;
      setState(() {
        if (period != null) _selectedPeriod = period;
        if (storedCustomDays != null &&
            storedCustomDays > 0 &&
            storedCustomDays <= _maxCustomDays) {
          _customDays = storedCustomDays;
        }
      });
    } catch (error) {
      AppLogger.w(
        'Failed to load Anlas statistics period: $error',
        'AnlasStats',
      );
    }
  }

  Future<void> _selectPeriod(AnlasStatisticsPeriod period) async {
    var nextCustomDays = _customDays;
    if (period == AnlasStatisticsPeriod.custom) {
      final selectedDays = await AdaptivePresenter.showForm<int>(
        context: context,
        title: AppLocalizations.of(context)!.statistics_customPeriodTitle,
        sideSheetWidth: 420,
        builder: (context, scrollController) => _CustomDaysForm(
          initialDays: _customDays,
          maxDays: _maxCustomDays,
          scrollController: scrollController,
        ),
      );
      if (selectedDays == null || !mounted) return;
      nextCustomDays = selectedDays;
    }

    setState(() {
      _selectedPeriod = period;
      _customDays = nextCustomDays;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_periodPreferenceKey, period.name),
        prefs.setInt(_customDaysPreferenceKey, nextCustomDays),
      ]);
    } catch (error) {
      AppLogger.w(
        'Failed to save Anlas statistics period: $error',
        'AnlasStats',
      );
    }
  }

  int? get _selectedDays => switch (_selectedPeriod) {
    AnlasStatisticsPeriod.week => 7,
    AnlasStatisticsPeriod.month => 30,
    AnlasStatisticsPeriod.threeMonths => 90,
    AnlasStatisticsPeriod.year => 365,
    AnlasStatisticsPeriod.all => null,
    AnlasStatisticsPeriod.custom => _customDays,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    final anlasStats = ref.watch(anlasStatisticsServiceProvider);

    return anlasStats.when(
      data: (service) {
        final periodStats = service.getPeriodStats(days: _selectedDays);
        final periodSelector = _buildPeriodSelector(context, l10n);

        if (!service.hasData) {
          return ChartCard(
            title: l10n.statistics_anlasCost,
            titleIcon: Icons.paid_outlined,
            accentColor: Colors.amber,
            trailing: periodSelector,
            child: _buildEmptyState(context, l10n),
          );
        }

        return ChartCard(
          title: l10n.statistics_anlasCost,
          titleIcon: Icons.paid_outlined,
          accentColor: Colors.amber,
          trailing: periodSelector,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: l10n.statistics_totalAnlasCost,
                      value: _formatAnlas(periodStats.totalCost),
                      valueKey: const ValueKey('anlas-period-total'),
                      isDark: isDark,
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      label: l10n.statistics_avgDailyCost,
                      value: _formatAnlas(periodStats.averageDailyCost),
                      valueKey: const ValueKey('anlas-period-average'),
                      isDark: isDark,
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildPeriodSummary(context, l10n, periodStats),
              if (periodStats.hasPartialCoverage) ...[
                const SizedBox(height: 8),
                _buildPartialCoverageNotice(context, l10n, periodStats),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: periodStats.totalCost == 0
                    ? Center(
                        child: Text(
                          l10n.statistics_noAnlasInPeriod,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _buildTrendChart(
                        context,
                        periodStats.dailyStats,
                        colorScheme,
                        isDark,
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => ChartCard(
        title: l10n.statistics_anlasCost,
        titleIcon: Icons.paid_outlined,
        accentColor: Colors.amber,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => ChartCard(
        title: l10n.statistics_anlasCost,
        titleIcon: Icons.paid_outlined,
        accentColor: Colors.amber,
        child: _buildEmptyState(context, l10n),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, AppLocalizations l10n) {
    return PopupMenuButton<AnlasStatisticsPeriod>(
      key: const ValueKey('anlas-period-selector'),
      tooltip: l10n.statistics_periodSelectorTooltip,
      onSelected: (period) => unawaited(_selectPeriod(period)),
      itemBuilder: (context) => AnlasStatisticsPeriod.values.map((period) {
        return CheckedPopupMenuItem<AnlasStatisticsPeriod>(
          key: ValueKey('anlas-period-${period.name}'),
          value: period,
          checked: period == _selectedPeriod,
          child: Text(_menuPeriodLabel(l10n, period)),
        );
      }).toList(),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _selectedPeriodLabel(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  String _selectedPeriodLabel(AppLocalizations l10n) {
    if (_selectedPeriod == AnlasStatisticsPeriod.custom) {
      return l10n.statistics_periodDays(_customDays);
    }
    return _menuPeriodLabel(l10n, _selectedPeriod);
  }

  String _menuPeriodLabel(AppLocalizations l10n, AnlasStatisticsPeriod period) {
    return switch (period) {
      AnlasStatisticsPeriod.week => l10n.statistics_periodWeek,
      AnlasStatisticsPeriod.month => l10n.statistics_periodMonth,
      AnlasStatisticsPeriod.threeMonths => l10n.statistics_periodThreeMonths,
      AnlasStatisticsPeriod.year => l10n.statistics_periodYear,
      AnlasStatisticsPeriod.all => l10n.statistics_periodAll,
      AnlasStatisticsPeriod.custom => l10n.statistics_periodCustom,
    };
  }

  Widget _buildPeriodSummary(
    BuildContext context,
    AppLocalizations l10n,
    AnlasPeriodStats periodStats,
  ) {
    final materialL10n = MaterialLocalizations.of(context);
    final start = materialL10n.formatShortDate(periodStats.startDate);
    final end = materialL10n.formatShortDate(periodStats.endDate);
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.date_range_outlined,
          size: 15,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l10n.statistics_periodSummary(start, end, periodStats.coveredDays),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartialCoverageNotice(
    BuildContext context,
    AppLocalizations l10n,
    AnlasPeriodStats periodStats,
  ) {
    final theme = Theme.of(context);
    final coverageStart = MaterialLocalizations.of(
      context,
    ).formatShortDate(periodStats.startDate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.statistics_partialCoverage(
                coverageStart,
                periodStats.coveredDays,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.savings_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.statistics_noAnlasData,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(
    BuildContext context,
    List<DailyAnlasStat> dailyStats,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    if (dailyStats.isEmpty) return const SizedBox.shrink();

    final materialL10n = MaterialLocalizations.of(context);

    final spots = dailyStats.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.cost.toDouble());
    }).toList();

    final maxValue = dailyStats
        .map((e) => e.cost)
        .reduce((a, b) => a > b ? a : b);
    final minValue = dailyStats
        .map((e) => e.cost)
        .reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    final padding = range > 0 ? range * 0.15 : maxValue * 0.15;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxValue / 3).clamp(1, double.infinity),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final stat = dailyStats[spot.spotIndex];
                return LineTooltipItem(
                  '${materialL10n.formatShortDate(stat.date)}\n${_formatAnlas(stat.cost)}',
                  TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minY: (minValue - padding).clamp(0, double.infinity),
        maxY: maxValue + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: dailyStats.length <= 90,
            curveSmoothness: 0.3,
            color: Colors.amber,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: dailyStats.length <= 31,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: Colors.amber,
                    strokeWidth: 2,
                    strokeColor: isDark ? colorScheme.surface : Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.amber.withValues(alpha: 0.3),
                  Colors.amber.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAnlas(int value) {
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Key? valueKey;

  const _StatBox({
    required this.label,
    required this.value,
    required this.isDark,
    required this.colorScheme,
    required this.textTheme,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            key: valueKey,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomDaysForm extends StatefulWidget {
  final int initialDays;
  final int maxDays;
  final ScrollController scrollController;

  const _CustomDaysForm({
    required this.initialDays,
    required this.maxDays,
    required this.scrollController,
  });

  @override
  State<_CustomDaysForm> createState() => _CustomDaysFormState();
}

class _CustomDaysFormState extends State<_CustomDaysForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDays.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(int.parse(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    return ListView(
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      children: [
        Form(
          key: _formKey,
          child: TextFormField(
            key: const ValueKey('anlas-custom-days-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.statistics_customDaysHint,
              suffixText: l10n.statistics_daysUnit,
            ),
            validator: (value) {
              final days = int.tryParse(value ?? '');
              if (days == null || days <= 0 || days > widget.maxDays) {
                return l10n.statistics_customDaysError(widget.maxDays);
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(materialL10n.cancelButtonLabel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('anlas-custom-days-apply'),
              onPressed: _submit,
              child: Text(materialL10n.okButtonLabel),
            ),
          ],
        ),
      ],
    );
  }
}
