import '../../data/models/gallery/local_image_record.dart';

enum ImageDateGroup { today, yesterday, thisWeek, earlier }

class ImageGroup {
  const ImageGroup({required this.category, required this.images});

  final ImageDateGroup category;
  final List<LocalImageRecord> images;
}

// 用 UTC 构造：本地时区构造每次查时区规则，大图库分组时慢两个数量级
int _calendarDayOrdinal(DateTime time) =>
    DateTime.utc(time.year, time.month, time.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// 以 [now] 所在日为基准按日期分组，保持输入顺序，省略空分组。
List<ImageGroup> groupImagesByDate(
  List<LocalImageRecord> images,
  DateTime now,
) {
  final boundaries = _DateGroupBoundaries(now);
  final groups = <ImageDateGroup, List<LocalImageRecord>>{
    for (final category in ImageDateGroup.values) category: [],
  };
  for (final image in images) {
    final day = _calendarDayOrdinal(image.modifiedAt);
    groups[boundaries.groupOf(day)]!.add(image);
  }
  return [
    for (final category in ImageDateGroup.values)
      if (groups[category]!.isNotEmpty)
        ImageGroup(category: category, images: groups[category]!),
  ];
}

class _DateGroupBoundaries {
  _DateGroupBoundaries(DateTime now)
    : today = _calendarDayOrdinal(now),
      weekStart = _calendarDayOrdinal(now) - (now.weekday - 1);

  final int today;
  final int weekStart;

  ImageDateGroup groupOf(int day) {
    if (day == today) return ImageDateGroup.today;
    if (day == today - 1) return ImageDateGroup.yesterday;
    if (day > weekStart && day < today) return ImageDateGroup.thisWeek;
    return ImageDateGroup.earlier;
  }
}
