import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation/vibe_reference_service.dart';

class _Storage extends Mock implements VibeLibraryStorageService {}

class _Api extends Mock implements NAIImageEnhancementApiService {}

void main() {
  late VibeReferenceService service;
  setUp(() {
    service = VibeReferenceService(
      libraryStorage: _Storage(),
      enhancementApi: _Api(),
      requestEncodingAuthentication: () =>
          throw StateError('No encoding in a batch merge'),
      preparePostBillingRefresh: () {},
      schedulePostBillingRefresh: () {},
    );
  });
  VibeReference vibe(int id) =>
      VibeReference(displayName: 'Vibe $id', vibeEncoding: 'encoding-$id');

  test(
    'an over-capacity drop rejects the complete set without mutating current references',
    () {
      final current = List.generate(15, vibe);
      final before = List<VibeReference>.of(current);
      expect(
        () => service.mergeReferences(current, [
          vibe(15),
          vibe(16),
        ], requireAll: true),
        throwsStateError,
      );
      expect(current, before);
    },
  );
  test(
    'existing references can be reordered at capacity without being discarded',
    () {
      final current = List.generate(16, vibe);
      final result = service.mergeReferences(current, [
        current[2],
        current[1],
      ], requireAll: true);
      expect(result, hasLength(16));
      expect(result.toSet(), current.toSet());
      expect(result.sublist(14), [current[2], current[1]]);
    },
  );
  test(
    'a compatible complete set preserves order and reference parameters',
    () {
      final first = vibe(0).copyWith(strength: .4, infoExtracted: .6);
      final second = vibe(1).copyWith(enabled: false);
      expect(service.mergeReferences([], [first, second], requireAll: true), [
        first,
        second,
      ]);
    },
  );
}
