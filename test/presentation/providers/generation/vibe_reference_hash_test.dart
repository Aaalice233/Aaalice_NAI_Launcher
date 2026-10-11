import 'dart:typed_data';

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
      requestEncodingAuthentication: () => false,
      preparePostBillingRefresh: () {},
      schedulePostBillingRefresh: () {},
    );
  });

  Uint8List image([int seed = 0]) => Uint8List.fromList(
    List.generate(256 * 1024, (index) => (index * 31 + seed) & 0xff),
  );

  VibeReference rawVibe(Uint8List bytes) => VibeReference(
    displayName: 'raw',
    vibeEncoding: '',
    rawImageData: bytes,
    sourceType: VibeSourceType.rawImage,
  );

  test('content-equal copies share a hash; any byte or length change does '
      'not', () {
    final raw = image();
    final sameLengthChanged = Uint8List.fromList(raw)..[1234] ^= 0x01;

    expect(service.imageHash(Uint8List.fromList(raw)), service.imageHash(raw));
    expect(service.imageHash(sameLengthChanged), isNot(service.imageHash(raw)));
    expect(
      service.imageHash(Uint8List.sublistView(raw, 0, raw.length - 1)),
      isNot(service.imageHash(raw)),
    );
  });

  test('a cached encoding is reused for a content-equal copy only', () {
    final raw = image();
    service.storeCached(
      raw,
      'encoded',
      model: 'nai-diffusion-4-5-full',
      informationExtracted: 0.7,
    );

    expect(
      service.getCached(
        Uint8List.fromList(raw),
        model: 'nai-diffusion-4-5-full',
        informationExtracted: 0.7,
      ),
      'encoded',
    );
    expect(
      service.getCached(
        image(1),
        model: 'nai-diffusion-4-5-full',
        informationExtracted: 0.7,
      ),
      isNull,
    );
  });

  test('merging treats content-equal raw images as the same source', () {
    final current = [rawVibe(image())];

    final merged = service.mergeReferences(current, [
      rawVibe(Uint8List.fromList(image())),
    ]);
    final appended = service.mergeReferences(current, [rawVibe(image(1))]);

    expect(merged, hasLength(1));
    expect(appended, hasLength(2));
  });
}
