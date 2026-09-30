import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../../data/models/gallery/gallery_parameter.dart';
import '../../../../../data/models/gallery/gallery_statistics.dart';
import '../../../../widgets/common/horizontal_segmented_control.dart';
import '../cards/chart_card.dart';
import '../charts/parameter_distribution_bar.dart';
import 'parameter_distribution_items.dart';

/// 参数分布卡片 - 按所选生成参数显示各取值的使用次数，默认显示采样器
/// Parameter distribution card - usage of each value of the selected parameter
class ParameterDistributionCard extends StatefulWidget {
  final GalleryStatistics stats;

  const ParameterDistributionCard({super.key, required this.stats});

  @override
  State<ParameterDistributionCard> createState() =>
      _ParameterDistributionCardState();
}

class _ParameterDistributionCardState extends State<ParameterDistributionCard> {
  GalleryParameter _parameter = GalleryParameter.sampler;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = parameterDistributionItems(
      widget.stats.parameterDistribution,
      _parameter,
      otherLabel: l10n.statistics_parameterOther,
      otherColor: Theme.of(context).colorScheme.outline,
    );

    return ChartCard(
      title: l10n.statistics_parameterDistribution,
      titleIcon: Icons.settings_outlined,
      accentColor: Colors.orange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ParameterSelector(
            selected: _parameter,
            onChanged: (parameter) => setState(() => _parameter = parameter),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            ChartEmptyState(title: l10n.statistics_noData)
          else
            ParameterDistributionBar(items: items, horizontal: true),
        ],
      ),
    );
  }
}

class _ParameterSelector extends StatelessWidget {
  final GalleryParameter selected;
  final ValueChanged<GalleryParameter> onChanged;

  const _ParameterSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HorizontalSegmentedControl(
      child: SegmentedButton<GalleryParameter>(
        key: const ValueKey('statistics-parameter-selector'),
        showSelectedIcon: false,
        segments: [
          for (final parameter in GalleryParameter.values)
            ButtonSegment(
              value: parameter,
              label: Text(_parameterLabel(l10n, parameter)),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}

String _parameterLabel(AppLocalizations l10n, GalleryParameter parameter) {
  return switch (parameter) {
    GalleryParameter.sampler => l10n.generation_sampler,
    GalleryParameter.steps => l10n.generation_stepsLabel,
    GalleryParameter.scale => l10n.generation_cfgScaleLabel,
    GalleryParameter.noiseSchedule => l10n.generation_noiseSchedule,
    GalleryParameter.cfgRescale => l10n.generation_cfgRescaleLabel,
  };
}
