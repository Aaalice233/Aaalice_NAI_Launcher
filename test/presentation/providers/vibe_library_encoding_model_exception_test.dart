import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';

void main() {
  test('批量修改 encoding model 保持批次级异常传播', () async {
    final storage = _EncodingModelStorageService();
    final container = ProviderContainer(
      overrides: [vibeLibraryStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    Iterable<String> throwingIds() sync* {
      yield 'updated';
      throw StateError('failed to enumerate selection');
    }

    await expectLater(
      container
          .read(vibeLibraryNotifierProvider.notifier)
          .bulkUpdateEncodingModel(throwingIds(), 'nai-diffusion-4-5-full'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'failed to enumerate selection',
        ),
      ),
    );
    expect(storage.processedIds, ['updated']);
  });
}

class _EncodingModelStorageService extends VibeLibraryStorageService {
  final processedIds = <String>[];

  @override
  Future<VibeLibraryEntry?> updateEntryEncodingModel(
    String id,
    String model,
  ) async {
    processedIds.add(id);
    return null;
  }
}
