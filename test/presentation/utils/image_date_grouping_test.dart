import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/presentation/utils/image_date_grouping.dart';

void main() {
  Map<ImageDateGroup, List<String>> grouped(
    DateTime now,
    List<DateTime> days,
  ) => {
    for (final group in groupImagesByDate([
      for (final (index, day) in days.indexed)
        LocalImageRecord(
          path: '$index:${day.toIso8601String()}',
          size: 1,
          modifiedAt: day,
        ),
    ], now))
      group.category: [
        for (final image in group.images) image.path.split(':').first,
      ],
  };

  test('today and yesterday follow calendar days, not 24 hour spans', () {
    final now = DateTime(2026, 10, 24, 0, 30);

    expect(
      grouped(now, [
        DateTime(2026, 10, 24, 23, 59),
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 23, 23, 59),
        DateTime(2026, 10, 23),
      ]),
      {
        ImageDateGroup.today: ['0', '1'],
        ImageDateGroup.yesterday: ['2', '3'],
      },
    );
  });

  test('this week covers the days before yesterday since the week began', () {
    final saturday = DateTime(2026, 10, 24, 15);

    expect(
      grouped(saturday, [
        DateTime(2026, 10, 22, 8),
        DateTime(2026, 10, 20, 8),
        DateTime(2026, 10, 18, 8),
        DateTime(2026, 9, 1),
      ]),
      {
        ImageDateGroup.thisWeek: ['0', '1'],
        ImageDateGroup.earlier: ['2', '3'],
      },
    );
  });

  test('Monday stays outside this week unless it is today or yesterday', () {
    expect(
      grouped(DateTime(2026, 10, 19), [
        DateTime(2026, 10, 19, 23, 59),
        DateTime(2026, 10, 18, 12),
        DateTime(2026, 10, 17, 12),
      ]),
      {
        ImageDateGroup.today: ['0'],
        ImageDateGroup.yesterday: ['1'],
        ImageDateGroup.earlier: ['2'],
      },
    );
    expect(grouped(DateTime(2026, 10, 20, 9), [DateTime(2026, 10, 19, 9)]), {
      ImageDateGroup.yesterday: ['0'],
    });
    expect(
      grouped(DateTime(2026, 10, 21, 9), [
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 19, 9),
      ]),
      {
        ImageDateGroup.yesterday: ['0'],
        ImageDateGroup.earlier: ['1'],
      },
    );
    expect(
      grouped(DateTime(2026, 10, 25, 23, 59), [
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 19, 23, 59),
      ]),
      {
        ImageDateGroup.thisWeek: ['0'],
        ImageDateGroup.earlier: ['1'],
      },
    );
  });

  test('week boundaries cross months and years', () {
    expect(
      grouped(DateTime(2026, 10, 3, 9), [
        DateTime(2026, 10, 2),
        DateTime(2026, 9, 30),
        DateTime(2026, 9, 29),
        DateTime(2026, 9, 27),
      ]),
      {
        ImageDateGroup.yesterday: ['0'],
        ImageDateGroup.thisWeek: ['1', '2'],
        ImageDateGroup.earlier: ['3'],
      },
    );
    expect(
      grouped(DateTime(2027, 1, 2, 9), [
        DateTime(2027, 1, 1),
        DateTime(2026, 12, 31),
        DateTime(2026, 12, 29),
        DateTime(2026, 12, 27),
      ]),
      {
        ImageDateGroup.yesterday: ['0'],
        ImageDateGroup.thisWeek: ['1', '2'],
        ImageDateGroup.earlier: ['3'],
      },
    );
  });

  test('future timestamps and empty input', () {
    final now = DateTime(2026, 10, 24, 12);

    expect(grouped(now, [DateTime(2026, 10, 25)]), {
      ImageDateGroup.earlier: ['0'],
    });
    expect(groupImagesByDate(const [], now), isEmpty);
  });
}
