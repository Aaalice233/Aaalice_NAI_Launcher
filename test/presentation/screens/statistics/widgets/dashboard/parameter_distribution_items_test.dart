import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_parameter.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/dashboard/parameter_distribution_items.dart';

void main() {
  const otherColor = Color(0xFF777777);

  List<(String, int, double)> rows(
    List<ParameterStatistics> distribution,
    GalleryParameter parameter,
  ) => [
    for (final item in parameterDistributionItems(
      distribution,
      parameter,
      otherLabel: 'Other',
      otherColor: otherColor,
    ))
      (item.label, item.count, item.percentage),
  ];

  test('only the selected parameter is listed, in the given order', () {
    final distribution = [
      _entry('sampler', 'k_euler_ancestral', 3),
      _entry('steps', '28', 5),
      _entry('sampler', 'k_dpmpp_2m', 1),
      _entry('steps', '23', 2),
    ];

    expect(rows(distribution, GalleryParameter.steps), [
      ('28', 5, 50.0),
      ('23', 2, 20.0),
    ]);
    expect(rows(distribution, GalleryParameter.noiseSchedule), isEmpty);
  });

  test('sampler values read like the former sampler card, others stay raw', () {
    final distribution = [
      _entry('sampler', 'k_euler_ancestral', 3),
      _entry('noise_schedule', 'karras', 3),
    ];

    expect(
      rows(distribution, GalleryParameter.sampler).single.$1,
      'Euler Ancestral',
    );
    expect(
      rows(distribution, GalleryParameter.noiseSchedule).single.$1,
      'karras',
    );
  });

  test('values beyond the visible limit are folded into one Other row', () {
    final distribution = [
      for (
        var index = 0;
        index < parameterDistributionVisibleValues + 3;
        index++
      )
        _entry('steps', '${50 - index}', 20 - index),
    ];

    final items = parameterDistributionItems(
      distribution,
      GalleryParameter.steps,
      otherLabel: 'Other',
      otherColor: otherColor,
    );

    expect(items, hasLength(parameterDistributionVisibleValues + 1));
    expect(items.take(parameterDistributionVisibleValues).map((e) => e.label), [
      for (var index = 0; index < parameterDistributionVisibleValues; index++)
        '${50 - index}',
    ]);
    final folded = distribution.skip(parameterDistributionVisibleValues);
    final other = items.last;
    expect(other.label, 'Other');
    expect(other.count, folded.fold<int>(0, (sum, e) => sum + e.count));
    expect(
      other.percentage,
      closeTo(folded.fold<double>(0, (sum, e) => sum + e.percentage), 1e-9),
    );
    expect(other.color, otherColor);
    expect(items.take(parameterDistributionVisibleValues).map((e) => e.color), [
      for (var index = 0; index < parameterDistributionVisibleValues; index++)
        null,
    ]);
  });

  test('a single value over the limit is listed instead of folded', () {
    final distribution = [
      for (
        var index = 0;
        index < parameterDistributionVisibleValues + 1;
        index++
      )
        _entry('scale', '${index + 1}.0', 10 - index),
    ];

    final labels = rows(
      distribution,
      GalleryParameter.scale,
    ).map((row) => row.$1);

    expect(labels, [for (final entry in distribution) entry.value]);
    expect(labels, isNot(contains('Other')));
  });
}

ParameterStatistics _entry(String parameter, String value, int count) =>
    ParameterStatistics(
      parameterName: parameter,
      value: value,
      count: count,
      percentage: count * 10.0,
    );
