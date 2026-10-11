import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/presentation/providers/generation/vibe_reference_service.dart';

import '../../../helpers/shared_compute_gate.dart';

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

  VibeReference rawVibe(Uint8List bytes) => VibeReference(
    displayName: 'raw',
    vibeEncoding: '',
    rawImageData: bytes,
    sourceType: VibeSourceType.rawImage,
  );

  test('large raw images are hashed behind the shared compute gate', () async {
    final raw = Uint8List(256 * 1024)..[9] = 7;
    final expected = service.imageHash(Uint8List.fromList(raw));

    await expectQueuedBehindSharedComputeGate(
      () => service.primeImageHashes([rawVibe(raw)]),
    );

    expect(service.imageHash(raw), expected);
  });

  test('small raw images and encoded Vibes skip the background hash', () async {
    final release = holdSharedComputeGate();
    addTearDown(release);

    await service.primeImageHashes([
      rawVibe(Uint8List(16)),
      const VibeReference(displayName: 'encoded', vibeEncoding: 'encoding'),
    ]);
  });
}
