import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/autocomplete/cooccurrence_data_pack_service.dart';
import 'package:nai_launcher/core/database/datasources/cooccurrence_data_source.dart';
import 'package:nai_launcher/core/database/services/cooccurrence_service.dart';

import '../../../helpers/log_capture.dart';

class _MockDataPackService extends Mock
    implements CooccurrenceDataPackService {}

void main() {
  test('related-tag failures never quote the prompt tag into the log', () async {
    final dataPack = _MockDataPackService();
    when(dataPack.initialize).thenThrow(StateError('pack unavailable'));
    final service = CooccurrenceService(
      CooccurrenceDataSource(dataPackService: dataPack),
    );

    late List<Recommendation> related;
    final logs = await captureLogs(() async {
      related = await service.getRelatedTags('lighthouse');
    });

    expect(related, isEmpty);
    expect(
      logs.where((line) => line.contains('Failed to get related tags')),
      hasLength(1),
    );
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
