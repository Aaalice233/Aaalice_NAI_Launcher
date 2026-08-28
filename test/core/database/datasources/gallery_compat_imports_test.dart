import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart'
    show GalleryDataSource;
import 'package:nai_launcher/core/database/datasources/gallery_data_source_records.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source_schema.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source_statistics.dart';

void _acceptRecords(
  GalleryImageRecord image,
  GalleryMetadataRecord metadata,
  GalleryTagRecord tag,
  ScanLogRecord scan,
  SlowQueryLog slowQuery,
) {}

void _acceptLegacySchema<T extends GalleryDataSourceSchema>() {}

Future<void> _acceptStatisticsFacade(GalleryDataSource dataSource) async {
  await dataSource.getDashboardStatistics();
}

Future<void> _acceptStatisticsExtension(GalleryDataSource dataSource) async {
  await GalleryDataSourceStatistics(dataSource).getDashboardStatistics();
}

void main() {
  test('legacy gallery import paths retain their public declarations', () {
    expect(_acceptRecords, isA<Function>());
    expect(_acceptLegacySchema, isA<Function>());
    expect(_acceptStatisticsFacade, isA<Function>());
    expect(_acceptStatisticsExtension, isA<Function>());
  });
}
